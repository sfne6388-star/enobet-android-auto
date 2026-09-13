import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/hizmet.dart';
import 'telefon_bilgisi.dart';

/// Taksi kayıtlarında yerel pakette telefon yoksa OpenStreetMap/Overpass
/// üzerinden aynı OSM kaydının güncel telefon etiketlerini kontrol eder.
///
/// Telefon uydurmaz. Yalnızca açık kaynaktaki gerçek telefon alanlarını kullanır.
class TaksiTelefonServisi {
  TaksiTelefonServisi._();

  static final TaksiTelefonServisi ortak = TaksiTelefonServisi._();

  static const List<String> _sunucular = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  final Map<String, String?> _onbellek = <String, String?>{};

  Future<String?> telefonBul(Hizmet hizmet) async {
    final mevcut = aranacakTelefon(hizmet.telefon);
    if (mevcut != null) return hizmet.telefon;
    if (hizmet.kategori != 'Taksi') return null;

    if (_onbellek.containsKey(hizmet.id)) {
      return _onbellek[hizmet.id];
    }

    String? bulunan;

    // Önce doğrudan uygulamadaki OSM nesnesini sorgula. En güvenilir eşleşme bu.
    final kimlik = _osmKimliginiAyir(hizmet.id);
    if (kimlik != null) {
      bulunan = await _dogrudanKayittanBul(kimlik.$1, kimlik.$2);
    }

    // Eski pakette aynı taksi durağının telefon bilgisi başka/çok yakın bir
    // OSM nesnesinde tutulmuş olabilir. Sadece güçlü isim/mesafe eşleşmesinde al.
    bulunan ??= await _yakindakiEslesenKayittanBul(hizmet);

    _onbellek[hizmet.id] = bulunan;
    return bulunan;
  }

  (String, int)? _osmKimliginiAyir(String id) {
    final eslesme = RegExp(r'^osm_(node|way|relation)_(\d+)$').firstMatch(id);
    if (eslesme == null) return null;
    final sayi = int.tryParse(eslesme.group(2)!);
    if (sayi == null) return null;
    return (eslesme.group(1)!, sayi);
  }

  Future<String?> _dogrudanKayittanBul(String tip, int id) async {
    final sorgu = '''
[out:json][timeout:12];
$tip($id);
out tags center;
''';
    final json = await _sorgula(sorgu);
    if (json == null) return null;

    for (final raw in json['elements'] as List? ?? const []) {
      if (raw is! Map) continue;
      final tags = Map<String, dynamic>.from(raw['tags'] as Map? ?? const {});
      final telefon = kayittanTelefon(tags);
      if (aranacakTelefon(telefon) != null) return telefon;
    }
    return null;
  }

  Future<String?> _yakindakiEslesenKayittanBul(Hizmet hizmet) async {
    if (hizmet.enlem == 0 || hizmet.boylam == 0) return null;

    // Bazı duraklarda telefon etiketi, durağın kendisinde değil hemen yanındaki
    // başka bir OSM nesnesinde tutulabiliyor. Önce dar, sonra daha geniş alanda
    // güçlü isim eşleşmesiyle arıyoruz.
    for (final yaricap in const <int>[180, 400, 800]) {
      final bulunan = await _yaricaptaTelefonBul(hizmet, yaricap);
      if (bulunan != null) return bulunan;
    }

    return null;
  }

  Future<String?> _yaricaptaTelefonBul(Hizmet hizmet, int yaricap) async {
    final lat = hizmet.enlem.toStringAsFixed(7);
    final lon = hizmet.boylam.toStringAsFixed(7);
    final sorgu = '''
[out:json][timeout:14];
(
  nwr(around:$yaricap,$lat,$lon)["amenity"="taxi"];
  nwr(around:$yaricap,$lat,$lon)["name"~"taksi|taxi|durak|durağı|duragi",i];
  nwr(around:$yaricap,$lat,$lon)["operator"~"taksi|taxi|durak|durağı|duragi",i];
);
out tags center;
''';

    final json = await _sorgula(sorgu);
    if (json == null) return null;

    final hedefAd = _duzenle(hizmet.isim);
    String? enIyiTelefon;
    double enIyiPuan = -1;

    for (final raw in json['elements'] as List? ?? const []) {
      if (raw is! Map) continue;

      final e = Map<String, dynamic>.from(raw);
      final tags = Map<String, dynamic>.from(e['tags'] as Map? ?? const {});
      final telefon = kayittanTelefon(tags);
      if (aranacakTelefon(telefon) == null) continue;

      final merkez = Map<String, dynamic>.from(e['center'] as Map? ?? const {});
      final eLat = ((e['lat'] ?? merkez['lat']) as num?)?.toDouble();
      final eLon = ((e['lon'] ?? merkez['lon']) as num?)?.toDouble();
      if (eLat == null || eLon == null) continue;

      final uzaklik = _metre(hizmet.enlem, hizmet.boylam, eLat, eLon);
      if (uzaklik > yaricap) continue;

      final adayAd = _duzenle(
        '${tags['name'] ?? ''} ${tags['operator'] ?? ''} ${tags['brand'] ?? ''}',
      );
      final isimPuani = _isimBenzerligi(hedefAd, adayAd);
      final taksiMi = tags['amenity'] == 'taxi';

      // Alan büyüdükçe yanlış durağın telefonunu alma riski artar.
      // Bu yüzden geniş aramalarda isim benzerliği şartını yükseltiyoruz.
      final bool kabul;
      if (yaricap <= 180) {
        kabul = isimPuani >= 0.60 || (taksiMi && uzaklik <= 30);
      } else if (yaricap <= 400) {
        kabul = isimPuani >= 0.72 || (taksiMi && uzaklik <= 20);
      } else {
        kabul = isimPuani >= 0.82;
      }

      if (!kabul) continue;

      final puan = isimPuani * 1200 - uzaklik;
      if (puan > enIyiPuan) {
        enIyiPuan = puan;
        enIyiTelefon = telefon;
      }
    }

    return enIyiTelefon;
  }

  Future<Map<String, dynamic>?> _sorgula(String query) async {
    for (final sunucu in _sunucular) {
      try {
        final uri = Uri.parse(sunucu).replace(queryParameters: {'data': query});
        final cevap = await http
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'ENobet/1.0 (OpenStreetMap phone lookup)',
              },
            )
            .timeout(const Duration(seconds: 14));
        if (cevap.statusCode != 200) continue;
        final decoded = jsonDecode(cevap.body);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Diğer ücretsiz Overpass sunucusunu dene.
      }
    }
    return null;
  }

  String _duzenle(String value) {
    var s = value.toLowerCase();
    const donusum = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
    };
    donusum.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  double _isimBenzerligi(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) return 0.9;
    final aa = a.split(' ').where((x) => x.length > 2).toSet();
    final bb = b.split(' ').where((x) => x.length > 2).toSet();
    if (aa.isEmpty || bb.isEmpty) return 0;
    final ortak = aa.intersection(bb).length;
    return (2 * ortak) / (aa.length + bb.length);
  }

  double _metre(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
