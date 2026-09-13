import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class YolAsistaniEkrani extends StatefulWidget {
  final double? baslangicEnlem;
  final double? baslangicBoylam;

  const YolAsistaniEkrani({
    super.key,
    this.baslangicEnlem,
    this.baslangicBoylam,
  });

  @override
  State<YolAsistaniEkrani> createState() => _YolAsistaniEkraniState();
}

class _YolAsistaniEkraniState extends State<YolAsistaniEkrani> with SingleTickerProviderStateMixin {
  static const Color _kirmizi = Color(0xFFE3262E);
  static const Color _mavi = Color(0xFF0A84FF);

  final MapController _mapController = MapController();
  final TextEditingController _hedefController = TextEditingController();
  final FocusNode _hedefFocusNode = FocusNode();
  late final AnimationController _konumPulseController;
  Timer? _aramaDebounce;

  LatLng? _baslangic;
  String? _baslangicAdi;
  _HedefSonucu? _hedef;
  List<_RotaSecenegi> _rotalar = <_RotaSecenegi>[];
  List<_GuzergahNoktasi> _guzergahNoktalari = <_GuzergahNoktasi>[];
  List<_YolHizmetiKaydi>? _yolHizmetiKayitlari;
  List<_HedefSonucu> _hedefOnerileri = <_HedefSonucu>[];

  final FlutterLocalNotificationsPlugin _yerelBildirimler =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<Position>? _yolculukKonumAboneligi;
  final Set<String> _bildirimVerilenNoktalar = <String>{};

  int _seciliRota = 0;
  bool _konumYukleniyor = true;
  bool _konumEngelli = false;
  bool _rotaYukleniyor = false;
  bool _tesisYukleniyor = false;
  bool _yolculukAktif = false;
  bool _yerelBildirimHazir = false;
  bool _haritaTakibi = true;
  bool _aramaOneriYukleniyor = false;
  bool _aramaPaneliAcik = true;
  bool _isletmelerHazirlaniyor = false;
  bool _yenidenRotaYukleniyor = false;
  int _rotaDisiSayac = 0;
  int _isletmeYuklemeToken = 0;
  double _sonRotaIlerlemesiMetre = 0;
  double _kalanMesafeMetre = 0;
  double _kalanSureSaniye = 0;
  double _sonHeading = 0;
  LatLng? _canliKonum;
  String? _hata;

  bool get _koyu => Theme.of(context).brightness == Brightness.dark;

  Color get _arkaPlan =>
      _koyu ? const Color(0xFF070707) : const Color(0xFFF4F5F7);

  Color get _kart =>
      _koyu ? const Color(0xFF11151B) : Colors.white;

  Color get _yazi =>
      _koyu ? Colors.white : const Color(0xFF16181C);

  Color get _ikincil =>
      _koyu
          ? Colors.white.withValues(alpha: 0.62)
          : Colors.black.withValues(alpha: 0.58);

  @override
  void initState() {
    super.initState();
    _konumPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    if (_gecerliKoordinat(widget.baslangicEnlem, widget.baslangicBoylam)) {
      _baslangic = LatLng(
        widget.baslangicEnlem!,
        widget.baslangicBoylam!,
      );
      _baslangicAdi = 'Mevcut konumunuz';
      _canliKonum = _baslangic;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _konumuHazirla();
      }
    });
  }

  @override
  void dispose() {
    _aramaDebounce?.cancel();
    _konumPulseController.dispose();
    _yolculukKonumAboneligi?.cancel();
    _hedefFocusNode.dispose();
    _hedefController.dispose();
    super.dispose();
  }

  bool _gecerliKoordinat(double? lat, double? lon) {
    if (lat == null || lon == null) return false;

    return lat.isFinite &&
        lon.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lon >= -180 &&
        lon <= 180 &&
        !(lat == 0 && lon == 0);
  }

  Future<void> _konumuHazirla() async {
    if (mounted) {
      setState(() {
        _konumYukleniyor = true;
        _konumEngelli = false;
        _hata = null;
      });
    }

    try {
      final bool servisAcik = await Geolocator.isLocationServiceEnabled();
      if (!servisAcik) {
        throw Exception('Konum servisi kapalı. Yol Asistanı için GPS açık olmalıdır.');
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }

      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        throw Exception(
          'Konum izni verilmedi. Yol Asistanı yalnızca mevcut konum ile kullanılabilir.',
        );
      }

      final Position konum = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (!mounted) return;

      final LatLng gps = LatLng(konum.latitude, konum.longitude);
      setState(() {
        _baslangic = gps;
        _canliKonum = gps;
        _baslangicAdi = 'Mevcut konumunuz';
        _konumEngelli = false;
        _hata = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _baslangic == null || _yolculukAktif) return;
        _mapController.move(_baslangic!, 14.2);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _baslangic = null;
        _canliKonum = null;
        _konumEngelli = true;
        _hata = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _konumYukleniyor = false;
        });
      }
    }
  }

  String _aramaNormalize(String deger) {
    String metin = deger.trim();
    metin = metin
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u');
    return metin.replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _basitYerlesimSorgusu(String sorgu) {
    final String metin = sorgu.trim();
    if (metin.length < 2) return false;
    if (RegExp(r'\d').hasMatch(metin)) return false;
    if (metin.contains(',') || metin.contains('/') || metin.contains(';')) {
      return false;
    }

    final List<String> kelimeler =
        metin.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (kelimeler.length > 4) return false;

    final String normal = _aramaNormalize(metin);
    const List<String> adresIpuclari = <String>[
      'sokak',
      'sok ',
      'cadde',
      'cad ',
      'mahalle',
      'mah ',
      'bulvar',
      'blv ',
      'apartman',
      'sitesi',
      'no ',
      'eczane',
      'hastane',
      'otel',
      'restoran',
      'cafe',
      'avm',
      'terminal',
      'havaalani',
      'universite',
    ];
    return !adresIpuclari.any(normal.contains);
  }

  int _nominatimSkoru(Map<String, dynamic> kayit, String sorgu) {
    final String q = _aramaNormalize(sorgu);
    final String display = (kayit['display_name'] ?? '').toString().trim();
    final String ilkParca = display.split(',').first.trim();
    final Map<String, dynamic> adres = kayit['address'] is Map
        ? Map<String, dynamic>.from(kayit['address'] as Map)
        : <String, dynamic>{};

    int skor = 0;

    void eslesmePuani(dynamic deger, int tam, int baslangic) {
      final String metin = _aramaNormalize('${deger ?? ''}');
      if (metin.isEmpty) return;
      if (metin == q) {
        skor += tam;
      } else if (metin.startsWith(q) || q.startsWith(metin)) {
        skor += baslangic;
      }
    }

    eslesmePuani(kayit['name'], 180, 70);
    eslesmePuani(ilkParca, 170, 65);
    eslesmePuani(adres['city'], 175, 65);
    eslesmePuani(adres['town'], 165, 60);
    eslesmePuani(adres['municipality'], 155, 55);
    eslesmePuani(adres['county'], 140, 50);
    eslesmePuani(adres['state_district'], 125, 45);
    eslesmePuani(adres['state'], 115, 40);
    eslesmePuani(adres['village'], 65, 25);
    eslesmePuani(adres['hamlet'], 35, 15);

    final String adresTipi = _aramaNormalize(
      '${kayit['addresstype'] ?? kayit['type'] ?? ''}',
    );
    switch (adresTipi) {
      case 'city':
        skor += 100;
        break;
      case 'town':
        skor += 88;
        break;
      case 'municipality':
        skor += 78;
        break;
      case 'county':
        skor += 62;
        break;
      case 'state_district':
        skor += 48;
        break;
      case 'state':
      case 'province':
        skor += 40;
        break;
      case 'village':
        skor += 12;
        break;
      case 'hamlet':
        skor += 4;
        break;
      case 'suburb':
      case 'neighbourhood':
        skor -= 20;
        break;
      case 'road':
      case 'house':
        skor -= 45;
        break;
    }

    final String ulkeKodu = '${adres['country_code'] ?? ''}'.toLowerCase();
    if (ulkeKodu == 'tr') skor += 20;

    final double importance =
        (kayit['importance'] as num?)?.toDouble() ?? 0.0;
    skor += (importance * 40).round();

    return skor;
  }

  List<_HedefSonucu> _nominatimSonuclariniHazirla(
    dynamic veri,
    String sorgu,
  ) {
    if (veri is! List) return const <_HedefSonucu>[];

    final List<MapEntry<int, _HedefSonucu>> skorlu =
        <MapEntry<int, _HedefSonucu>>[];
    final Set<String> gorulen = <String>{};

    for (final dynamic raw in veri) {
      if (raw is! Map) continue;
      final Map<String, dynamic> kayit = Map<String, dynamic>.from(raw);
      final double? lat = double.tryParse('${kayit['lat']}');
      final double? lon = double.tryParse('${kayit['lon']}');
      if (!_gecerliKoordinat(lat, lon)) continue;

      final String koordinatAnahtari =
          '${lat!.toStringAsFixed(5)},${lon!.toStringAsFixed(5)}';
      if (!gorulen.add(koordinatAnahtari)) continue;

      final String ad = (kayit['display_name'] ?? sorgu).toString().trim();
      skorlu.add(
        MapEntry<int, _HedefSonucu>(
          _nominatimSkoru(kayit, sorgu),
          _HedefSonucu(
            ad: ad.isEmpty ? sorgu : ad,
            konum: LatLng(lat, lon),
          ),
        ),
      );
    }

    skorlu.sort((a, b) => b.key.compareTo(a.key));
    return skorlu.map((e) => e.value).toList(growable: false);
  }

  Future<List<_HedefSonucu>> _nominatimAra(
    String sorgu, {
    int limit = 5,
    bool sehirMerkeziOncelikli = false,
  }) async {
    final Map<String, String> parametreler = <String, String>{
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      'dedupe': '1',
      'accept-language': 'tr',
      'countrycodes': 'tr',
    };

    // Tek başına il/ilçe/şehir adı girildiyse serbest metin yerine Nominatim'in
    // yapılandırılmış şehir sorgusunu kullanıyoruz. Bu, örneğin "Tekirdağ"
    // yazıldığında çevredeki aynı/benzer isimli köy yerine şehir merkezini seçer.
    if (sehirMerkeziOncelikli) {
      parametreler['city'] = sorgu;
      parametreler['featureType'] = 'city';
    } else {
      parametreler['q'] = sorgu;
    }

    final Uri uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      parametreler,
    );

    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Accept-Language': 'tr-TR,tr;q=0.9',
        'User-Agent': 'ENobet/1.0 (Android; Yol Asistani)',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Nominatim HTTP ${response.statusCode}');
    }

    final dynamic veri = jsonDecode(response.body);
    return _nominatimSonuclariniHazirla(veri, sorgu);
  }

  int _photonSkoru(Map<String, dynamic> props, String sorgu) {
    final String q = _aramaNormalize(sorgu);
    int skor = 0;

    void puan(dynamic deger, int tam, int baslangic) {
      final String metin = _aramaNormalize('${deger ?? ''}');
      if (metin.isEmpty) return;
      if (metin == q) {
        skor += tam;
      } else if (metin.startsWith(q) || q.startsWith(metin)) {
        skor += baslangic;
      }
    }

    puan(props['name'], 170, 65);
    puan(props['city'], 160, 60);
    puan(props['county'], 130, 50);
    puan(props['state'], 105, 40);
    puan(props['district'], 90, 35);

    final String tur = _aramaNormalize(
      '${props['osm_value'] ?? props['type'] ?? ''}',
    );
    switch (tur) {
      case 'city':
        skor += 90;
        break;
      case 'town':
        skor += 78;
        break;
      case 'municipality':
        skor += 68;
        break;
      case 'village':
        skor += 10;
        break;
      case 'hamlet':
        skor += 2;
        break;
      case 'suburb':
      case 'neighbourhood':
      case 'locality':
        skor -= 18;
        break;
    }

    final String countryCode =
        '${props['countrycode'] ?? props['country_code'] ?? ''}'.toLowerCase();
    if (countryCode == 'tr' || countryCode == 'tur') skor += 15;
    return skor;
  }

  Future<List<_HedefSonucu>> _photonAra(
    String sorgu, {
    int limit = 5,
  }) async {
    final Map<String, String> parametreler = <String, String>{
      'q': sorgu,
      'limit': '${math.max(limit, 8)}',
      'lang': 'tr',
    };

    final LatLng? bias = _baslangic;
    // Şehir/ilçe adı yazılırken mevcut konuma yakın sonuçları zorlamıyoruz.
    // Aksi halde "Tekirdağ" gibi bir hedef, kullanıcının yakınındaki köy veya
    // küçük yerleşimle yanlış eşleşebiliyor.
    if (bias != null && !_basitYerlesimSorgusu(sorgu)) {
      parametreler['lat'] = bias.latitude.toStringAsFixed(6);
      parametreler['lon'] = bias.longitude.toStringAsFixed(6);
      parametreler['location_bias_scale'] = '0.20';
    }

    final Uri uri = Uri.https(
      'photon.komoot.io',
      '/api',
      parametreler,
    );

    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Accept-Language': 'tr-TR,tr;q=0.9',
        'User-Agent': 'ENobet/1.0 (Android; Yol Asistani)',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Photon HTTP ${response.statusCode}');
    }

    final dynamic veri = jsonDecode(response.body);
    if (veri is! Map) return const <_HedefSonucu>[];
    final dynamic rawFeatures = veri['features'];
    if (rawFeatures is! List) return const <_HedefSonucu>[];

    final List<MapEntry<int, _HedefSonucu>> skorlu =
        <MapEntry<int, _HedefSonucu>>[];
    final Set<String> gorulen = <String>{};

    for (final dynamic raw in rawFeatures) {
      if (raw is! Map) continue;
      final Map<String, dynamic> feature = Map<String, dynamic>.from(raw);
      final dynamic rawGeometry = feature['geometry'];
      if (rawGeometry is! Map) continue;
      final Map<String, dynamic> geometry =
          Map<String, dynamic>.from(rawGeometry);
      final dynamic rawCoordinates = geometry['coordinates'];
      if (rawCoordinates is! List || rawCoordinates.length < 2) continue;

      final double? lon = (rawCoordinates[0] as num?)?.toDouble();
      final double? lat = (rawCoordinates[1] as num?)?.toDouble();
      if (!_gecerliKoordinat(lat, lon)) continue;

      final Map<String, dynamic> props = feature['properties'] is Map
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};
      final String ad = _photonHedefAdi(props, sorgu);
      final String anahtar =
          '${lat!.toStringAsFixed(5)},${lon!.toStringAsFixed(5)}';
      if (!gorulen.add(anahtar)) continue;

      skorlu.add(
        MapEntry<int, _HedefSonucu>(
          _photonSkoru(props, sorgu),
          _HedefSonucu(
            ad: ad,
            konum: LatLng(lat, lon),
          ),
        ),
      );
    }

    skorlu.sort((a, b) => b.key.compareTo(a.key));
    return skorlu.take(limit).map((e) => e.value).toList(growable: false);
  }

  String _photonHedefAdi(Map<String, dynamic> props, String yedek) {
    final List<String> parcalar = <String>[];
    void ekle(dynamic deger) {
      final String metin = '${deger ?? ''}'.trim();
      if (metin.isEmpty) return;
      if (parcalar.any((e) => e.toLowerCase() == metin.toLowerCase())) return;
      parcalar.add(metin);
    }

    ekle(props['name']);
    ekle(props['street']);
    ekle(props['district']);
    ekle(props['city']);
    ekle(props['county']);
    ekle(props['state']);
    ekle(props['country']);

    if (parcalar.isEmpty) return yedek;
    return parcalar.take(4).join(', ');
  }

  Future<_HedefSonucu> _yerAra(String sorgu) async {
    Object? sonHata;

    // İl/ilçe/şehir adı tek başına girildiyse önce doğrudan şehir merkezini
    // arıyoruz. Bu adım mevcut GPS konumundan etkilenmez.
    if (_basitYerlesimSorgusu(sorgu)) {
      try {
        final List<_HedefSonucu> merkez = await _nominatimAra(
          sorgu,
          limit: 5,
          sehirMerkeziOncelikli: true,
        );
        if (merkez.isNotEmpty) return merkez.first;
      } catch (e) {
        sonHata = e;
      }
    }

    try {
      final List<_HedefSonucu> nominatim = await _nominatimAra(sorgu, limit: 8);
      if (nominatim.isNotEmpty) return nominatim.first;
    } catch (e) {
      sonHata = e;
    }

    try {
      final List<_HedefSonucu> photon = await _photonAra(sorgu, limit: 6);
      if (photon.isNotEmpty) return photon.first;
    } catch (e) {
      sonHata = e;
    }

    try {
      final List<geo.Location> cihazSonuclari =
          await geo.locationFromAddress('$sorgu, Türkiye');
      if (cihazSonuclari.isNotEmpty) {
        final geo.Location ilk = cihazSonuclari.first;
        if (_gecerliKoordinat(ilk.latitude, ilk.longitude)) {
          return _HedefSonucu(
            ad: sorgu,
            konum: LatLng(ilk.latitude, ilk.longitude),
          );
        }
      }
    } catch (e) {
      sonHata = e;
    }

    throw Exception(
      sonHata == null
          ? 'Hedef bulunamadı. İl, ilçe, mahalle veya yer adını biraz daha açık yazın.'
          : 'Hedef bulunamadı. İnternet bağlantısını kontrol edip tekrar deneyin.',
    );
  }

  void _hedefYazisiDegisti(String deger) {
    _aramaDebounce?.cancel();
    final String sorgu = deger.trim();

    if (sorgu.length < 2) {
      if (_hedefOnerileri.isNotEmpty || _aramaOneriYukleniyor) {
        setState(() {
          _hedefOnerileri = <_HedefSonucu>[];
          _aramaOneriYukleniyor = false;
        });
      }
      return;
    }

    _aramaDebounce = Timer(const Duration(milliseconds: 550), () async {
      if (!mounted || _hedefController.text.trim() != sorgu) return;
      setState(() => _aramaOneriYukleniyor = true);
      try {
        final List<_HedefSonucu> oneriler = await _photonAra(sorgu, limit: 5);
        if (!mounted || _hedefController.text.trim() != sorgu) return;
        setState(() {
          _hedefOnerileri = oneriler;
          _aramaOneriYukleniyor = false;
        });
      } catch (_) {
        if (!mounted || _hedefController.text.trim() != sorgu) return;
        setState(() {
          _hedefOnerileri = <_HedefSonucu>[];
          _aramaOneriYukleniyor = false;
        });
      }
    });
  }

  Future<void> _hedefOnerisiniSec(_HedefSonucu hedef) async {
    _aramaDebounce?.cancel();
    _hedefController.text = hedef.ad;
    setState(() {
      _hedefOnerileri = <_HedefSonucu>[];
      _aramaOneriYukleniyor = false;
    });
    await _rotaAra(seciliHedef: hedef);
  }

  Future<List<_RotaSecenegi>> _rotalariGetir(
    LatLng baslangic,
    LatLng hedef,
  ) async {
    final String koordinatlar =
        '${baslangic.longitude},${baslangic.latitude};'
        '${hedef.longitude},${hedef.latitude}';

    final Uri uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$koordinatlar'
      '?alternatives=true&overview=full&geometries=geojson&steps=true',
    );

    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'User-Agent': 'ENobet/1.0 (Android; Yol Asistani)',
      },
    ).timeout(const Duration(seconds: 22));

    if (response.statusCode != 200) {
      throw Exception('Rota servisine ulaşılamadı.');
    }

    final Map<String, dynamic> veri =
        Map<String, dynamic>.from(jsonDecode(response.body) as Map);

    if (veri['code'] != 'Ok') {
      throw Exception('Uygun araç rotası bulunamadı.');
    }

    final List<dynamic> routes =
        (veri['routes'] as List<dynamic>? ?? const <dynamic>[]);
    if (routes.isEmpty) {
      throw Exception('Uygun araç rotası bulunamadı.');
    }

    final List<_RotaSecenegi> sonuc = <_RotaSecenegi>[];

    for (int i = 0; i < routes.length && i < 3; i++) {
      final Map<String, dynamic> route =
          Map<String, dynamic>.from(routes[i] as Map);
      final Map<String, dynamic> geometry =
          Map<String, dynamic>.from(route['geometry'] as Map);
      final List<dynamic> coordinates =
          geometry['coordinates'] as List<dynamic>? ?? const <dynamic>[];

      final List<LatLng> noktalar = coordinates
          .whereType<List<dynamic>>()
          .where((item) => item.length >= 2)
          .map(
            (item) => LatLng(
              (item[1] as num).toDouble(),
              (item[0] as num).toDouble(),
            ),
          )
          .toList();
      if (noktalar.length < 2) continue;

      final List<double> birikimli = _rotaBirikimliMesafeleri(noktalar);
      final Set<String> yolReferanslari = <String>{};
      final List<_RotaAdimi> adimlar = <_RotaAdimi>[];
      final List<dynamic> legs =
          route['legs'] as List<dynamic>? ?? const <dynamic>[];

      for (final dynamic rawLeg in legs) {
        if (rawLeg is! Map) continue;
        final Map<String, dynamic> leg = Map<String, dynamic>.from(rawLeg);
        final List<dynamic> steps =
            leg['steps'] as List<dynamic>? ?? const <dynamic>[];

        for (final dynamic rawStep in steps) {
          if (rawStep is! Map) continue;
          final Map<String, dynamic> step = Map<String, dynamic>.from(rawStep);
          final String ref = '${step['ref'] ?? ''}'.trim();
          if (ref.isNotEmpty) {
            yolReferanslari.addAll(_yolRefParcalari(ref));
          }

          final dynamic rawManeuver = step['maneuver'];
          if (rawManeuver is! Map) continue;
          final Map<String, dynamic> maneuver =
              Map<String, dynamic>.from(rawManeuver);
          final dynamic rawLocation = maneuver['location'];
          if (rawLocation is! List || rawLocation.length < 2) continue;
          final double? lon = rawLocation[0] is num
              ? (rawLocation[0] as num).toDouble()
              : double.tryParse('${rawLocation[0]}');
          final double? lat = rawLocation[1] is num
              ? (rawLocation[1] as num).toDouble()
              : double.tryParse('${rawLocation[1]}');
          if (!_gecerliKoordinat(lat, lon)) continue;

          final _RotaYakinlik yakinlik = _rotayaYakinlik(
            LatLng(lat!, lon!),
            noktalar,
            birikimli,
          );
          final String tip = '${maneuver['type'] ?? ''}'.trim();
          final String yon = '${maneuver['modifier'] ?? ''}'.trim();
          final String yolAdi = '${step['name'] ?? ref}'.trim();

          if (tip == 'depart' && yakinlik.rotaBaslangicindanMetre < 25) {
            continue;
          }
          adimlar.add(
            _RotaAdimi(
              rotaMetre: yakinlik.rotaBaslangicindanMetre,
              tip: tip,
              yon: yon,
              yolAdi: yolAdi,
            ),
          );
        }
      }

      adimlar.sort((a, b) => a.rotaMetre.compareTo(b.rotaMetre));
      sonuc.add(
        _RotaSecenegi(
          mesafeMetre: (route['distance'] as num?)?.toDouble() ?? 0,
          sureSaniye: (route['duration'] as num?)?.toDouble() ?? 0,
          noktalar: noktalar,
          yolReferanslari: yolReferanslari,
          adimlar: adimlar,
        ),
      );
    }

    if (sonuc.isEmpty) {
      throw Exception('Rota geometrisi alınamadı.');
    }
    return sonuc;
  }

  Future<void> _rotaAra({_HedefSonucu? seciliHedef}) async {
    FocusScope.of(context).unfocus();

    final String hedefSorgu = _hedefController.text.trim();
    if (seciliHedef == null && hedefSorgu.length < 2) {
      _mesaj('Lütfen gideceğiniz yeri yazın.');
      return;
    }

    if (_konumYukleniyor) {
      _mesaj('Mevcut konumunuz alınıyor.');
      return;
    }

    if (_konumEngelli || _baslangic == null) {
      await _konumuHazirla();
      if (!mounted || _konumEngelli || _baslangic == null) {
        _mesaj('Yol Asistanı için konum izni ve açık GPS zorunludur.');
        return;
      }
    }

    await _yolculuguDurdur(sessiz: true);

    setState(() {
      _rotaYukleniyor = true;
      _hata = null;
      _rotalar = <_RotaSecenegi>[];
      _guzergahNoktalari = <_GuzergahNoktasi>[];
      _hedef = null;
      _seciliRota = 0;
      _hedefOnerileri = <_HedefSonucu>[];
      _aramaOneriYukleniyor = false;
      _aramaPaneliAcik = false;
    });

    try {
      final _HedefSonucu hedef = seciliHedef ?? await _yerAra(hedefSorgu);
      final List<_RotaSecenegi> rotalar =
          await _rotalariGetir(_baslangic!, hedef.konum);

      if (!mounted) return;

      setState(() {
        _baslangicAdi = 'Mevcut konumunuz';
        _hedef = hedef;
        _rotalar = rotalar;
        _seciliRota = 0;
        _aramaPaneliAcik = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _rotalar.isEmpty) return;
        _haritayiRotayaOdakla(_rotalar.first);
      });

      // Rota seçilir seçilmez yolun TAM üzerindeki işletmeleri hazırla.
      // Böylece kullanıcı GİT demeden önce de seçtiği güzergâhı ve yol üstü
      // işletmeleri haritada birlikte görür.
      unawaited(_seciliRotaIsletmeleriniHazirla());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString().replaceFirst('Exception: ', '');
        _aramaPaneliAcik = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _rotaYukleniyor = false;
        });
      }
    }
  }

  void _haritayiRotayaOdakla(_RotaSecenegi rota) {
    if (rota.noktalar.isEmpty) return;

    double minLat = rota.noktalar.first.latitude;
    double maxLat = minLat;
    double minLon = rota.noktalar.first.longitude;
    double maxLon = minLon;

    for (final LatLng nokta in rota.noktalar) {
      if (nokta.latitude < minLat) minLat = nokta.latitude;
      if (nokta.latitude > maxLat) maxLat = nokta.latitude;
      if (nokta.longitude < minLon) minLon = nokta.longitude;
      if (nokta.longitude > maxLon) maxLon = nokta.longitude;
    }

    final LatLng merkez = LatLng(
      (minLat + maxLat) / 2,
      (minLon + maxLon) / 2,
    );

    final double yayilim =
        (maxLat - minLat).abs() > (maxLon - minLon).abs()
            ? (maxLat - minLat).abs()
            : (maxLon - minLon).abs();

    double zoom;
    if (yayilim < 0.02) {
      zoom = 13.5;
    } else if (yayilim < 0.05) {
      zoom = 12.2;
    } else if (yayilim < 0.12) {
      zoom = 10.8;
    } else if (yayilim < 0.25) {
      zoom = 9.5;
    } else if (yayilim < 0.55) {
      zoom = 8.2;
    } else if (yayilim < 1.2) {
      zoom = 7.2;
    } else if (yayilim < 2.5) {
      zoom = 6.2;
    } else {
      zoom = 5.3;
    }

    _mapController.move(merkez, zoom);
  }

  Future<void> _rotaSec(int index) async {
    if (index < 0 || index >= _rotalar.length) return;

    await _yolculuguDurdur(sessiz: true);
    if (!mounted) return;

    setState(() {
      _seciliRota = index;
      _guzergahNoktalari = <_GuzergahNoktasi>[];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _haritayiRotayaOdakla(_rotalar[index]);
    });

    await _seciliRotaIsletmeleriniHazirla();
  }

  Future<void> _seciliRotaIsletmeleriniHazirla() async {
    if (_rotalar.isEmpty || _seciliRota >= _rotalar.length) return;

    final int token = ++_isletmeYuklemeToken;
    final int rotaIndex = _seciliRota;
    final _RotaSecenegi rota = _rotalar[rotaIndex];

    if (mounted) {
      setState(() {
        _isletmelerHazirlaniyor = true;
      });
    }

    try {
      final List<_GuzergahNoktasi> noktalar =
          await _guzergahNoktalariniGetir(rota);

      if (!mounted || token != _isletmeYuklemeToken || _seciliRota != rotaIndex) {
        return;
      }

      setState(() {
        _guzergahNoktalari = noktalar;
      });
    } catch (e) {
      if (!mounted || token != _isletmeYuklemeToken || _seciliRota != rotaIndex) {
        return;
      }
      setState(() {
        _hata = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && token == _isletmeYuklemeToken) {
        setState(() {
          _isletmelerHazirlaniyor = false;
        });
      }
    }
  }

  Future<void> _yolaCik() async {
    if (_rotalar.isEmpty || _seciliRota >= _rotalar.length) return;
    if (_tesisYukleniyor) return;

    if (_konumEngelli || _baslangic == null) {
      _mesaj('Yol Asistanı için konum izni zorunludur.');
      return;
    }

    final _RotaSecenegi rota = _rotalar[_seciliRota];

    setState(() {
      _tesisYukleniyor = true;
      _hata = null;
    });

    try {
      if (_guzergahNoktalari.isEmpty) {
        final List<_GuzergahNoktasi> noktalar =
            await _guzergahNoktalariniGetir(rota);
        if (!mounted) return;
        setState(() {
          _guzergahNoktalari = noktalar;
        });
      }

      await _yolculuguBaslat(rota);

      if (mounted && _guzergahNoktalari.isEmpty) {
        _mesaj(
          'Bu seçili yolun tam üzerinde uygun işletme bulunamadı. Navigasyon devam ediyor.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString().replaceFirst('Exception: ', '');
      });
      _mesaj(_hata ?? 'Güzergâh hazırlanamadı.');
    } finally {
      if (mounted) {
        setState(() {
          _tesisYukleniyor = false;
        });
      }
    }
  }

  Future<List<_GuzergahNoktasi>> _guzergahNoktalariniGetir(
    _RotaSecenegi rota,
  ) async {
    if (rota.noktalar.length < 2) {
      return const <_GuzergahNoktasi>[];
    }

    final List<_YolHizmetiKaydi> tumKayitlar =
        await _yolHizmetiVerisiniYukle();
    if (tumKayitlar.isEmpty) {
      throw Exception(
        'Yol hizmetleri verisi bulunamadı. Yol Hizmetleri Verisini Güncelle '
        'işlemini bir kez çalıştırın.',
      );
    }

    final List<double> birikimli = _rotaBirikimliMesafeleri(rota.noktalar);
    if (birikimli.isEmpty || birikimli.last <= 0) {
      return const <_GuzergahNoktasi>[];
    }

    double minLat = rota.noktalar.first.latitude;
    double maxLat = minLat;
    double minLon = rota.noktalar.first.longitude;
    double maxLon = minLon;
    for (final LatLng b in rota.noktalar.skip(1)) {
      if (b.latitude < minLat) minLat = b.latitude;
      if (b.latitude > maxLat) maxLat = b.latitude;
      if (b.longitude < minLon) minLon = b.longitude;
      if (b.longitude > maxLon) maxLon = b.longitude;
    }

    const double bboxPay = 0.0065;
    final double toplamRotaMetre = birikimli.last;
    const double baslangicTamponMetre = 2200;
    const double hedefTamponMetre = 900;
    final Set<String> rotaRefleri = rota.yolReferanslari
        .map(_yolRefNormalize)
        .where((e) => e.isNotEmpty)
        .toSet();

    final Map<String, _GuzergahNoktasi> benzersiz =
        <String, _GuzergahNoktasi>{};

    for (final _YolHizmetiKaydi kayit in tumKayitlar) {
      final LatLng konum = kayit.konum;
      if (konum.latitude < minLat - bboxPay ||
          konum.latitude > maxLat + bboxPay ||
          konum.longitude < minLon - bboxPay ||
          konum.longitude > maxLon + bboxPay) {
        continue;
      }

      final _RotaYakinlik yakinlik = _rotayaYakinlik(
        konum,
        rota.noktalar,
        birikimli,
      );
      final String yolSinifi = kayit.yolSinifi.toLowerCase();
      final bool bolunmusAnaYol =
          yolSinifi.startsWith('motorway') || yolSinifi.startsWith('trunk');
      final bool zenginKayit = kayit.yolSegmenti != null &&
          kayit.yolaKayitliUzaklikMetre != null;

      final double maksimumUzaklik = zenginKayit
          ? switch (kayit.tur) {
              _GuzergahTuru.dinlenme => bolunmusAnaYol ? 260 : 125,
              _GuzergahTuru.akaryakit => bolunmusAnaYol ? 125 : 85,
              _GuzergahTuru.sarj => bolunmusAnaYol ? 125 : 85,
            }
          : switch (kayit.tur) {
              _GuzergahTuru.dinlenme => 55,
              _GuzergahTuru.akaryakit => 38,
              _GuzergahTuru.sarj => 38,
            };
      if (yakinlik.rotayaUzaklikMetre > maksimumUzaklik) continue;

      final Set<String> kayitRefleri = _yolRefParcalari(kayit.yolRef);
      final bool refEslesiyor = kayitRefleri.isNotEmpty &&
          rotaRefleri.isNotEmpty &&
          kayitRefleri.any(rotaRefleri.contains);
      final bool segmentEslesiyor = _yolSegmentiRotayaUyuyor(
        kayit: kayit,
        rota: rota,
        birikimli: birikimli,
      );

      // Zenginleştirilmiş sabit veride aynı ana yola bağlı olduğunu mutlaka
      // kanıtla. Yol numarası OSRM'de eksikse geometri + yön eşleşmesi devreye girer.
      if (zenginKayit && !refEslesiyor && !segmentEslesiyor) continue;

      if (zenginKayit) {
        final double veriSiniri = switch (kayit.tur) {
          _GuzergahTuru.dinlenme => bolunmusAnaYol ? 320 : 150,
          _GuzergahTuru.akaryakit => bolunmusAnaYol ? 150 : 95,
          _GuzergahTuru.sarj => bolunmusAnaYol ? 150 : 95,
        };
        if (kayit.yolaKayitliUzaklikMetre! > veriSiniri) continue;
      }

      // Otoyol ve bölünmüş yollarda yalnız sürüş yönünden erişilebilir sağ tarafı
      // göster. Çok yakın noktaları geometri toleransı nedeniyle muaf tut.
      if ((bolunmusAnaYol || kayit.yolTekYon) &&
          yakinlik.yanalUzaklikMetre > 24 &&
          !yakinlik.sagTarafta) {
        continue;
      }

      final double baslangictan = yakinlik.rotaBaslangicindanMetre;
      final double sondan = toplamRotaMetre - baslangictan;
      if (baslangictan < baslangicTamponMetre ||
          sondan < hedefTamponMetre) {
        continue;
      }

      final String key =
          '${kayit.tur.name}|${kayit.id}|'
          '${konum.latitude.toStringAsFixed(5)}|'
          '${konum.longitude.toStringAsFixed(5)}';
      benzersiz[key] = _GuzergahNoktasi(
        id: kayit.id,
        isim: kayit.isim,
        tur: kayit.tur,
        konum: kayit.konum,
        rotaBaslangicindanMetre: baslangictan,
        rotayaUzaklikMetre: yakinlik.rotayaUzaklikMetre,
        marka: kayit.marka,
      );
    }

    final List<_GuzergahNoktasi> sonuc = benzersiz.values.toList()
      ..sort(
        (a, b) => a.rotaBaslangicindanMetre.compareTo(
          b.rotaBaslangicindanMetre,
        ),
      );
    return sonuc;
  }

  bool _yolSegmentiRotayaUyuyor({
    required _YolHizmetiKaydi kayit,
    required _RotaSecenegi rota,
    required List<double> birikimli,
  }) {
    final List<LatLng>? segment = kayit.yolSegmenti;
    if (segment == null || segment.length != 2) return false;

    final LatLng a = segment[0];
    final LatLng b = segment[1];
    final LatLng orta = LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
    final _RotaYakinlik yakinlik = _rotayaYakinlik(
      orta,
      rota.noktalar,
      birikimli,
    );
    if (yakinlik.rotayaUzaklikMetre > 42) return false;

    final int i = math.max(
      0,
      math.min(yakinlik.segmentIndex, rota.noktalar.length - 2),
    );
    final double rotaYon = _bearingDerece(rota.noktalar[i], rota.noktalar[i + 1]);
    final double veriYon = _bearingDerece(a, b);
    final double fark = _aciFarki(rotaYon, veriYon);

    if (kayit.yolTekYon) {
      return fark <= 48;
    }
    return math.min(fark, (180 - fark).abs()) <= 38;
  }

  double _aciFarki(double a, double b) {
    return (((a - b + 540) % 360) - 180).abs();
  }

  LatLng _rotaUzerindeKonum(
    List<LatLng> rota,
    List<double> birikimli,
    double hedefMetre,
  ) {
    if (hedefMetre <= 0) return rota.first;
    if (hedefMetre >= birikimli.last) return rota.last;

    for (int i = 0; i < birikimli.length - 1; i++) {
      final double bas = birikimli[i];
      final double son = birikimli[i + 1];
      if (hedefMetre > son) continue;

      final double segment = son - bas;
      final double t = segment <= 0
          ? 0
          : ((hedefMetre - bas) / segment).clamp(0.0, 1.0);
      final LatLng a = rota[i];
      final LatLng b = rota[i + 1];

      return LatLng(
        a.latitude + ((b.latitude - a.latitude) * t),
        a.longitude + ((b.longitude - a.longitude) * t),
      );
    }

    return rota.last;
  }

  Future<List<_YolHizmetiKaydi>> _yolHizmetiVerisiniYukle() async {
    if (_yolHizmetiKayitlari != null) return _yolHizmetiKayitlari!;

    List<dynamic> hamKayitlar = const <dynamic>[];
    try {
      final String ham = await rootBundle.loadString(
        'assets/data/yol_hizmetleri.json',
      );
      final dynamic decoded = jsonDecode(ham);
      if (decoded is Map) {
        hamKayitlar = decoded['records'] as List<dynamic>? ?? const <dynamic>[];
      }
    } catch (_) {
      hamKayitlar = const <dynamic>[];
    }

    // Eski APK/veri kopyaları için son çare: ana katalogdaki Yol Hizmeti
    // kayıtlarını kullan. Yeni mimaride esas kaynak ayrı yol_hizmetleri.json'dur.
    if (hamKayitlar.isEmpty) {
      try {
        final String ham = await rootBundle.loadString(
          'assets/data/turkiye_hizmetleri.json',
        );
        final dynamic decoded = jsonDecode(ham);
        if (decoded is Map) {
          hamKayitlar = decoded['records'] as List<dynamic>? ?? const <dynamic>[];
        }
      } catch (_) {
        hamKayitlar = const <dynamic>[];
      }
    }

    final List<_YolHizmetiKaydi> sonuc = <_YolHizmetiKaydi>[];
    for (final dynamic raw in hamKayitlar) {
      if (raw is! Map) continue;
      final Map<String, dynamic> kayit = Map<String, dynamic>.from(raw);
      final Map<String, dynamic> tags = kayit['tags'] is Map
          ? Map<String, dynamic>.from(kayit['tags'] as Map)
          : <String, dynamic>{};
      final Map<String, dynamic> eskiYol = kayit['yolAsistani'] is Map
          ? Map<String, dynamic>.from(kayit['yolAsistani'] as Map)
          : <String, dynamic>{};

      String turMetni = '${kayit['tur'] ?? eskiYol['tur'] ?? ''}'
          .trim()
          .toLowerCase();
      if (turMetni.isEmpty) {
        final String amenity = '${tags['amenity'] ?? ''}';
        final String highway = '${tags['highway'] ?? ''}';
        if (highway == 'services' || highway == 'rest_area') {
          turMetni = 'dinlenme';
        } else if (amenity == 'fuel') {
          turMetni = 'akaryakit';
        } else if (amenity == 'charging_station') {
          turMetni = 'sarj';
        } else {
          continue;
        }
      }

      final _GuzergahTuru? tur = switch (turMetni) {
        'akaryakit' => _GuzergahTuru.akaryakit,
        'sarj' => _GuzergahTuru.sarj,
        'dinlenme' => _GuzergahTuru.dinlenme,
        _ => null,
      };
      if (tur == null) continue;

      final double? lat = kayit['lat'] is num
          ? (kayit['lat'] as num).toDouble()
          : double.tryParse('${kayit['lat'] ?? ''}');
      final double? lon = kayit['lon'] is num
          ? (kayit['lon'] as num).toDouble()
          : double.tryParse('${kayit['lon'] ?? ''}');
      if (!_gecerliKoordinat(lat, lon)) continue;

      final dynamic roadDistanceRaw =
          kayit['roadDistanceM'] ?? eskiYol['roadDistanceM'];
      final double? roadDistance = roadDistanceRaw is num
          ? roadDistanceRaw.toDouble()
          : double.tryParse('${roadDistanceRaw ?? ''}');
      final dynamic rawSegment = kayit['roadSegment'] ?? eskiYol['roadSegment'];
      List<LatLng>? yolSegmenti;
      if (rawSegment is List && rawSegment.length == 4) {
        final List<double?> degerler = rawSegment
            .map((e) => e is num ? e.toDouble() : double.tryParse('$e'))
            .toList();
        if (degerler.every((e) => e != null)) {
          yolSegmenti = <LatLng>[
            LatLng(degerler[0]!, degerler[1]!),
            LatLng(degerler[2]!, degerler[3]!),
          ];
        }
      }

      String isim = '${kayit['name'] ?? tags['name'] ?? ''}'.trim();
      final String marka =
          '${kayit['brand'] ?? tags['brand'] ?? tags['operator'] ?? ''}'.trim();
      if (isim.isEmpty) {
        isim = switch (tur) {
          _GuzergahTuru.akaryakit => 'Akaryakıt İstasyonu',
          _GuzergahTuru.sarj => 'Elektrikli Şarj İstasyonu',
          _GuzergahTuru.dinlenme => 'Dinlenme Tesisi',
        };
      }

      final String kimlik = '${kayit['id'] ?? ''}'.trim().isNotEmpty
          ? '${kayit['id']}'
          : '${kayit['type'] ?? 'n'}-${kayit['osmId'] ?? sonuc.length}';

      sonuc.add(
        _YolHizmetiKaydi(
          id: kimlik,
          isim: isim,
          tur: tur,
          konum: LatLng(lat!, lon!),
          marka: marka,
          yolRef: '${kayit['roadRef'] ?? eskiYol['roadRef'] ?? ''}'.trim(),
          yolAdi: '${kayit['roadName'] ?? eskiYol['roadName'] ?? ''}'.trim(),
          yolSinifi:
              '${kayit['roadClass'] ?? eskiYol['roadClass'] ?? ''}'.trim(),
          yolaKayitliUzaklikMetre: roadDistance,
          yolTekYon:
              (kayit['roadOneway'] ?? eskiYol['roadOneway'] ?? false) == true,
          yolSegmenti: yolSegmenti,
        ),
      );
    }

    _yolHizmetiKayitlari = sonuc;
    return sonuc;
  }

  String _yolRefNormalize(String deger) {
    return deger
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Set<String> _yolRefParcalari(String deger) {
    return deger
        .split(RegExp(r'[;,/|]+'))
        .map(_yolRefNormalize)
        .where((String e) => e.isNotEmpty)
        .toSet();
  }

  _RotaYakinlik _rotayaYakinlik(
    LatLng nokta,
    List<LatLng> rota,
    List<double> birikimli,
  ) {
    double enKisa = double.infinity;
    double rotaMesafesi = 0;
    bool sagTarafta = false;
    double yanalUzaklikMetre = 0;
    int segmentIndex = 0;
    double segmentOrani = 0;

    for (int i = 0; i < rota.length - 1; i++) {
      final LatLng a = rota[i];
      final LatLng b = rota[i + 1];

      final double ortalamaLat =
          ((a.latitude + b.latitude + nokta.latitude) / 3) *
          math.pi /
          180;

      final double metreLat = 111320;
      final double metreLon = 111320 * math.cos(ortalamaLat);

      final double ax = a.longitude * metreLon;
      final double ay = a.latitude * metreLat;
      final double bx = b.longitude * metreLon;
      final double by = b.latitude * metreLat;
      final double px = nokta.longitude * metreLon;
      final double py = nokta.latitude * metreLat;

      final double dx = bx - ax;
      final double dy = by - ay;
      final double uzunlukKare = dx * dx + dy * dy;

      double t = 0;
      if (uzunlukKare > 0) {
        t = ((px - ax) * dx + (py - ay) * dy) / uzunlukKare;
        t = t.clamp(0.0, 1.0);
      }

      final double qx = ax + t * dx;
      final double qy = ay + t * dy;
      final double vx = px - qx;
      final double vy = py - qy;
      final double uzaklik = math.sqrt((vx * vx) + (vy * vy));

      if (uzaklik < enKisa) {
        enKisa = uzaklik;
        final double segmentUzunlugu = birikimli[i + 1] - birikimli[i];
        rotaMesafesi = birikimli[i] + (segmentUzunlugu * t);
        final double cross = (dx * (py - ay)) - (dy * (px - ax));
        sagTarafta = cross < 0;
        yanalUzaklikMetre = uzaklik;
        segmentIndex = i;
        segmentOrani = t;
      }
    }

    return _RotaYakinlik(
      rotayaUzaklikMetre: enKisa,
      rotaBaslangicindanMetre: rotaMesafesi,
      sagTarafta: sagTarafta,
      yanalUzaklikMetre: yanalUzaklikMetre,
      segmentIndex: segmentIndex,
      segmentOrani: segmentOrani,
    );
  }

  Future<void> _yerelBildirimleriHazirla() async {
    if (_yerelBildirimHazir) return;

    const AndroidInitializationSettings androidAyar =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosAyar =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings ayarlar = InitializationSettings(
      android: androidAyar,
      iOS: iosAyar,
    );

    await _yerelBildirimler.initialize(settings: ayarlar);

    await _yerelBildirimler
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _yerelBildirimHazir = true;
  }

  Future<void> _yolculuguBaslat(_RotaSecenegi rota) async {
    await _yolculukKonumAboneligi?.cancel();
    _yolculukKonumAboneligi = null;
    _bildirimVerilenNoktalar.clear();
    _sonRotaIlerlemesiMetre = 0;
    _kalanMesafeMetre = rota.mesafeMetre;
    _kalanSureSaniye = rota.sureSaniye;
    _haritaTakibi = true;
    _rotaDisiSayac = 0;

    await _yerelBildirimleriHazirla();

    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _konumEngelli = true;
          _yolculukAktif = false;
        });
        _mesaj('Yol Asistanı konum izni olmadan kullanılamaz.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _yolculukAktif = true;
        _konumEngelli = false;
      });
    }

    try {
      final Position ilkKonum = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      await _yolculukKonumunuIsle(ilkKonum);
    } catch (_) {
      // İlk GPS paketi gelince takip devam eder.
    }

    final LocationSettings ayarlar = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
            intervalDuration: const Duration(seconds: 1),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'ENöbet Yol Asistanı',
              notificationText: 'Canlı yolculuk takibi aktif',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
          );

    _yolculukKonumAboneligi = Geolocator.getPositionStream(
      locationSettings: ayarlar,
    ).listen(
      (Position position) => _yolculukKonumunuIsle(position),
      onError: (_) {
        if (!mounted) return;
        _mesaj('Canlı konum takip edilemiyor. GPS bağlantısını kontrol edin.');
      },
    );
  }

  Future<void> _yolculuguDurdur({bool sessiz = false}) async {
    await _yolculukKonumAboneligi?.cancel();
    _yolculukKonumAboneligi = null;
    _bildirimVerilenNoktalar.clear();
    _sonRotaIlerlemesiMetre = 0;
    _kalanMesafeMetre = 0;
    _kalanSureSaniye = 0;
    _sonHeading = 0;
    _haritaTakibi = true;
    _rotaDisiSayac = 0;
    _yenidenRotaYukleniyor = false;

    if (mounted && _yolculukAktif) {
      setState(() {
        _yolculukAktif = false;
        _canliKonum = _baslangic;
      });
      if (!sessiz) {
        _mesaj('Yolculuk takibi durduruldu.');
      }
    } else {
      _yolculukAktif = false;
    }
  }

  Future<void> _yolculukKonumunuIsle(Position position) async {
    if (!_yolculukAktif || _rotalar.isEmpty || _seciliRota >= _rotalar.length) {
      return;
    }
    final _RotaSecenegi rota = _rotalar[_seciliRota];
    if (rota.noktalar.length < 2) return;

    final List<double> birikimli = _rotaBirikimliMesafeleri(rota.noktalar);
    if (birikimli.length != rota.noktalar.length || birikimli.last <= 0) {
      return;
    }

    final LatLng gps = LatLng(position.latitude, position.longitude);
    final _RotaYakinlik mevcut = _rotayaYakinlik(
      gps,
      rota.noktalar,
      birikimli,
    );

    if (mevcut.rotayaUzaklikMetre <= 100) {
      _rotaDisiSayac = 0;
      if (mevcut.rotaBaslangicindanMetre > _sonRotaIlerlemesiMetre) {
        _sonRotaIlerlemesiMetre = mevcut.rotaBaslangicindanMetre;
      }
    } else if (mevcut.rotayaUzaklikMetre > 135 && position.speed > 1.5) {
      _rotaDisiSayac += 1;
      if (_rotaDisiSayac >= 4 && !_yenidenRotaYukleniyor && _hedef != null) {
        _rotaDisiSayac = 0;
        unawaited(_yenidenRotaOlustur(gps));
      }
    }

    final double geometriKalan =
        math.max(0, birikimli.last - _sonRotaIlerlemesiMetre);
    final double oran = (geometriKalan / birikimli.last).clamp(0.0, 1.0);
    final double kalanMesafe = rota.mesafeMetre * oran;
    final double kalanSure = rota.sureSaniye * oran;

    double heading = position.heading;
    if (!heading.isFinite || heading < 0 || position.speed < 1.5) {
      final int i = math.max(
        0,
        math.min(mevcut.segmentIndex, rota.noktalar.length - 2),
      );
      heading = _bearingDerece(rota.noktalar[i], rota.noktalar[i + 1]);
    }
    if (heading.isFinite) {
      _sonHeading = _yumusatilmisHeading(_sonHeading, heading);
    }

    if (mounted) {
      setState(() {
        _canliKonum = gps;
        _kalanMesafeMetre = kalanMesafe;
        _kalanSureSaniye = kalanSure;
      });
    }

    if (_haritaTakibi && mounted) {
      final LatLng kameraMerkezi = _navigasyonKameraMerkezi(
        rota: rota,
        gps: gps,
        hizMps: math.max(0, position.speed),
      );
      final double zoom = _navigasyonZoom(math.max(0, position.speed));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_yolculukAktif || !_haritaTakibi) return;
        _mapController.moveAndRotate(kameraMerkezi, zoom, -_sonHeading);
      });
    }

    final List<_GuzergahNoktasi> siradaki = _siradakiIsletmeler(limit: 1);
    if (siradaki.isNotEmpty) {
      final _GuzergahNoktasi nokta = siradaki.first;
      final double kalanYolMetre =
          nokta.rotaBaslangicindanMetre - _sonRotaIlerlemesiMetre;
      if (kalanYolMetre > 0 &&
          kalanYolMetre <= 5000 &&
          !_bildirimVerilenNoktalar.contains(nokta.id)) {
        _bildirimVerilenNoktalar.add(nokta.id);
        await _besKmBildirimiGoster(nokta, kalanYolMetre);
      }
    }
  }

  Future<void> _yenidenRotaOlustur(LatLng gps) async {
    if (_yenidenRotaYukleniyor || _hedef == null) return;
    _yenidenRotaYukleniyor = true;
    try {
      final List<_RotaSecenegi> yeniRotalar = await _rotalariGetir(
        gps,
        _hedef!.konum,
      );
      if (!mounted || !_yolculukAktif || yeniRotalar.isEmpty) return;
      setState(() {
        _baslangic = gps;
        _rotalar = yeniRotalar;
        _seciliRota = 0;
        _sonRotaIlerlemesiMetre = 0;
        _kalanMesafeMetre = yeniRotalar.first.mesafeMetre;
        _kalanSureSaniye = yeniRotalar.first.sureSaniye;
        _guzergahNoktalari = <_GuzergahNoktasi>[];
      });
      await _seciliRotaIsletmeleriniHazirla();
      if (mounted) {
        _mesaj('Rota güncellendi.');
      }
    } catch (_) {
      // İnternet kısa süre kesildiyse mevcut rota ile devam et.
    } finally {
      _yenidenRotaYukleniyor = false;
    }
  }

  double _yumusatilmisHeading(double onceki, double yeni) {
    if (!yeni.isFinite) return onceki;
    if (!onceki.isFinite || onceki == 0) return yeni;
    final double fark = ((yeni - onceki + 540) % 360) - 180;
    return (onceki + (fark * 0.28) + 360) % 360;
  }

  double _navigasyonZoom(double hizMps) {
    final double kmh = hizMps * 3.6;
    if (kmh < 15) return 17.4;
    if (kmh < 50) return 17.0;
    if (kmh < 90) return 16.6;
    return 16.25;
  }

  LatLng _navigasyonKameraMerkezi({
    required _RotaSecenegi rota,
    required LatLng gps,
    required double hizMps,
  }) {
    if (rota.noktalar.length < 2) return gps;
    final List<double> birikimli = _rotaBirikimliMesafeleri(rota.noktalar);
    if (birikimli.isEmpty || birikimli.last <= 0) return gps;

    final double ileriBakis = (120 + (hizMps * 9)).clamp(120.0, 340.0);
    final double hedefMetre = math.min(
      birikimli.last,
      _sonRotaIlerlemesiMetre + ileriBakis,
    );
    final LatLng ileri = _rotaUzerindeKonum(
      rota.noktalar,
      birikimli,
      hedefMetre,
    );

    // Merkezi GPS'in biraz önüne taşı. Böylece kullanıcı ekranın alt yarısında
    // kalır ve sürüş yönündeki yol daha fazla görünür.
    return LatLng(
      gps.latitude + ((ileri.latitude - gps.latitude) * 0.46),
      gps.longitude + ((ileri.longitude - gps.longitude) * 0.46),
    );
  }

  List<_GuzergahNoktasi> _siradakiIsletmeler({int limit = 5}) {
    final double esik = _sonRotaIlerlemesiMetre + 60;
    final List<_GuzergahNoktasi> kalan = _guzergahNoktalari
        .where((n) => n.rotaBaslangicindanMetre > esik)
        .toList()
      ..sort(
        (a, b) => a.rotaBaslangicindanMetre.compareTo(
          b.rotaBaslangicindanMetre,
        ),
      );

    if (kalan.length <= limit) return kalan;
    return kalan.sublist(0, limit);
  }

  double _isletmeyeKalanMetre(_GuzergahNoktasi nokta) {
    return math.max(0, nokta.rotaBaslangicindanMetre - _sonRotaIlerlemesiMetre);
  }

  double _bearingDerece(LatLng a, LatLng b) {
    final double lat1 = a.latitude * math.pi / 180;
    final double lat2 = b.latitude * math.pi / 180;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double derece = math.atan2(y, x) * 180 / math.pi;
    return (derece + 360) % 360;
  }

  List<double> _rotaBirikimliMesafeleri(List<LatLng> rota) {
    if (rota.isEmpty) return const <double>[];

    final List<double> sonuc = <double>[0];
    for (int i = 0; i < rota.length - 1; i++) {
      final LatLng a = rota[i];
      final LatLng b = rota[i + 1];
      sonuc.add(
        sonuc.last +
            Geolocator.distanceBetween(
              a.latitude,
              a.longitude,
              b.latitude,
              b.longitude,
            ),
      );
    }
    return sonuc;
  }

  Future<void> _besKmBildirimiGoster(
    _GuzergahNoktasi nokta,
    double kalanYolMetre,
  ) async {
    const AndroidNotificationDetails androidDetay =
        AndroidNotificationDetails(
      'yol_asistani_5km',
      'Yol Asistanı 5 km Uyarıları',
      channelDescription:
          'Seçilen güzergâhta ilerideki yol hizmetleri için 5 km uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetay = DarwinNotificationDetails();
    const NotificationDetails detay = NotificationDetails(
      android: androidDetay,
      iOS: iosDetay,
    );

    final int bildirimId = nokta.id.hashCode.abs() % 2147483647;
    final String kalan = _mesafeYaz(kalanYolMetre);

    await _yerelBildirimler.show(
      id: bildirimId,
      title: '${_guzergahTurAdi(nokta.tur)} yaklaşıyor',
      body: '${nokta.isim} yaklaşık $kalan sonra, seçili güzergâhınızın üzerinde.',
      notificationDetails: detay,
      payload: 'yol_asistani:${nokta.id}',
    );
  }

  void _guzergahNoktalariniGoster() {
    if (!mounted || _guzergahNoktalari.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.52,
          minChildSize: 0.30,
          maxChildSize: 0.88,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _kart,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _yazi.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.route_rounded,
                          color: _kirmizi,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Güzergâh Üzerindekiler',
                            style: TextStyle(
                              color: _yazi,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kirmizi.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_guzergahNoktalari.length} nokta',
                            style: const TextStyle(
                              color: _kirmizi,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Text(
                      'Yalnızca seçtiğiniz yolun kenarında ve sürüş yönünde erişilebilir kabul edilen kayıtlar, yolculuk sırasına göre listelenir.',
                      style: TextStyle(
                        color: _ikincil,
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      itemCount: _guzergahNoktalari.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final _GuzergahNoktasi nokta =
                            _guzergahNoktalari[index];

                        return _guzergahListeKarti(nokta);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _guzergahListeKarti(_GuzergahNoktasi nokta) {
    final Color renk = _guzergahRengi(nokta.tur);
    final IconData icon = _guzergahIkonu(nokta.tur);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _mapController.move(nokta.konum, 15.5);
      },
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _koyu
              ? Colors.white.withValues(alpha: 0.045)
              : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: renk.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: renk, size: 22),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nokta.isim,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _yazi,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _guzergahTurAdi(nokta.tur),
                    style: TextStyle(
                      color: renk,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (nokta.marka.isNotEmpty &&
                      nokta.marka.toLowerCase() !=
                          nokta.isim.toLowerCase()) ...[
                    const SizedBox(height: 3),
                    Text(
                      nokta.marka,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ikincil,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_mesafeYaz(nokta.rotaBaslangicindanMetre)} sonra',
                  style: TextStyle(
                    color: _yazi,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'yola ${_mesafeYaz(nokta.rotayaUzaklikMetre)}',
                  style: TextStyle(
                    color: _ikincil,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _guzergahRengi(_GuzergahTuru tur) {
    return switch (tur) {
      _GuzergahTuru.akaryakit => const Color(0xFFF59E0B),
      _GuzergahTuru.sarj => const Color(0xFF10B981),
      _GuzergahTuru.dinlenme => const Color(0xFF06B6D4),
    };
  }

  IconData _guzergahIkonu(_GuzergahTuru tur) {
    return switch (tur) {
      _GuzergahTuru.akaryakit => Icons.local_gas_station_rounded,
      _GuzergahTuru.sarj => Icons.ev_station_rounded,
      _GuzergahTuru.dinlenme => Icons.hotel_rounded,
    };
  }

  String _guzergahTurAdi(_GuzergahTuru tur) {
    return switch (tur) {
      _GuzergahTuru.akaryakit => 'Akaryakıt',
      _GuzergahTuru.sarj => 'Elektrikli Şarj',
      _GuzergahTuru.dinlenme => 'Dinlenme Tesisi',
    };
  }

  void _mesaj(String mesaj) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(mesaj),
        ),
      );
  }

  String _mesafeYaz(double metre) {
    if (metre < 1000) {
      return '${metre.round()} m';
    }

    return '${(metre / 1000).toStringAsFixed(metre >= 100000 ? 0 : 1)} km';
  }

  String _sureYaz(double saniye) {
    final int dakika = (saniye / 60).round();

    if (dakika < 60) {
      return '$dakika dk';
    }

    final int saat = dakika ~/ 60;
    final int kalanDakika = dakika % 60;

    if (kalanDakika == 0) {
      return '$saat sa';
    }

    return '$saat sa $kalanDakika dk';
  }

  List<Polyline> _cizgiler() {
    if (_rotalar.isEmpty) return const <Polyline>[];

    if (_yolculukAktif && _seciliRota < _rotalar.length) {
      final _RotaSecenegi rota = _rotalar[_seciliRota];
      final List<LatLng> kalan = _kalanRotaNoktalari(rota);
      return <Polyline>[
        Polyline(
          points: rota.noktalar,
          strokeWidth: 10,
          color: (_koyu ? Colors.black : Colors.white).withValues(alpha: 0.72),
        ),
        Polyline(
          points: rota.noktalar,
          strokeWidth: 6.5,
          color: const Color(0xFF8B929A).withValues(alpha: 0.78),
        ),
        Polyline(
          points: kalan.length >= 2 ? kalan : rota.noktalar,
          strokeWidth: 6.5,
          color: _mavi,
        ),
      ];
    }

    return <Polyline>[
      for (int i = 0; i < _rotalar.length; i++) ...[
        if (i == _seciliRota)
          Polyline(
            points: _rotalar[i].noktalar,
            strokeWidth: 9,
            color: (_koyu ? Colors.black : Colors.white).withValues(alpha: 0.74),
          ),
        Polyline(
          points: _rotalar[i].noktalar,
          strokeWidth: i == _seciliRota ? 5.5 : 3.4,
          color: i == _seciliRota
              ? _mavi
              : const Color(0xFF727982).withValues(alpha: 0.58),
        ),
      ],
    ];
  }

  List<LatLng> _kalanRotaNoktalari(_RotaSecenegi rota) {
    if (rota.noktalar.length < 2 || _sonRotaIlerlemesiMetre <= 0) {
      return rota.noktalar;
    }
    final List<double> birikimli = _rotaBirikimliMesafeleri(rota.noktalar);
    if (birikimli.length != rota.noktalar.length || birikimli.last <= 0) {
      return rota.noktalar;
    }
    final double ilerleme = _sonRotaIlerlemesiMetre.clamp(0.0, birikimli.last);
    int index = 0;
    while (index < birikimli.length - 1 && birikimli[index + 1] < ilerleme) {
      index++;
    }
    final LatLng bas = _rotaUzerindeKonum(rota.noktalar, birikimli, ilerleme);
    return <LatLng>[bas, ...rota.noktalar.skip(index + 1)];
  }

  List<Marker> _markerlar() {
    final List<Marker> sonuc = <Marker>[];
    final LatLng? aktifKonum = _yolculukAktif ? _canliKonum : _baslangic;

    if (aktifKonum != null) {
      sonuc.add(
        Marker(
          point: aktifKonum,
          width: 54,
          height: 54,
          child: _konumNoktasi(navigasyon: _yolculukAktif),
        ),
      );
    }

    if (_hedef != null) {
      sonuc.add(
        Marker(
          point: _hedef!.konum,
          width: 58,
          height: 58,
          child: _haritaNoktasi(
            icon: Icons.flag_rounded,
            renk: _kirmizi,
          ),
        ),
      );
    }

    final List<_GuzergahNoktasi> gosterilecek = _yolculukAktif
        ? _siradakiIsletmeler(limit: 5)
        : _guzergahNoktalari;

    for (final _GuzergahNoktasi nokta in gosterilecek) {
      final Color renk = _guzergahRengi(nokta.tur);
      final IconData icon = _guzergahIkonu(nokta.tur);
      sonuc.add(
        Marker(
          point: nokta.konum,
          width: _yolculukAktif ? 38 : 42,
          height: _yolculukAktif ? 38 : 42,
          child: GestureDetector(
            onTap: () {
              _mesaj(
                '${nokta.isim} • ${_mesafeYaz(_isletmeyeKalanMetre(nokta))} sonra',
              );
            },
            child: Center(
              child: Container(
                width: _yolculukAktif ? 28 : 32,
                height: _yolculukAktif ? 28 : 32,
                decoration: BoxDecoration(
                  color: renk,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: _yolculukAktif ? 14 : 16),
              ),
            ),
          ),
        ),
      );
    }

    return sonuc;
  }

  Widget _konumNoktasi({required bool navigasyon}) {
    return AnimatedBuilder(
      animation: _konumPulseController,
      builder: (context, _) {
        final double t = _konumPulseController.value;
        final double pulse = 0.75 + (0.55 * t);
        final double opacity = (1 - t) * 0.30;

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: navigasyon ? 37 : 32,
                  height: navigasyon ? 37 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _mavi.withValues(alpha: opacity),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: opacity * 1.8),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Container(
                width: navigasyon ? 24 : 18,
                height: navigasyon ? 24 : 18,
                decoration: BoxDecoration(
                  color: _mavi,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: navigasyon ? 2.5 : 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.62),
                      blurRadius: 7,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: _mavi.withValues(alpha: 0.32),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: navigasyon
                    ? const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _haritaNoktasi({
    required IconData icon,
    required Color renk,
  }) {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: renk,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }

  Widget _ustAlan() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            _yuvarlakButon(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _kart.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _kirmizi.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      color: _kirmizi,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Yol Asistanı',
                        style: TextStyle(
                          color: _yazi,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text(
                      'BETA',
                      style: TextStyle(
                        color: _kirmizi,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yuvarlakButon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _kart.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: _yazi, size: 19),
        ),
      ),
    );
  }

  Widget _camPanel({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _koyu
                ? const Color(0xFF11151B).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: _koyu ? 0.12 : 0.48),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _koyu ? 0.20 : 0.10),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _aramaKarti() {
    return _camPanel(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: TextField(
              controller: _hedefController,
              focusNode: _hedefFocusNode,
              enabled: !_konumEngelli && !_konumYukleniyor,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _rotaAra(),
              onChanged: (deger) {
                setState(() {});
                _hedefYazisiDegisti(deger);
              },
              style: TextStyle(
                color: _yazi,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Nereye gidiyorsunuz?',
                hintStyle: TextStyle(
                  color: _ikincil,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _kirmizi,
                  size: 21,
                ),
                suffixIcon: _aramaOneriYukleniyor
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kirmizi,
                          ),
                        ),
                      )
                    : _hedefController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Temizle',
                            onPressed: () {
                              _aramaDebounce?.cancel();
                              _hedefController.clear();
                              setState(() {
                                _hedefOnerileri = <_HedefSonucu>[];
                                _hata = null;
                              });
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              color: _ikincil,
                              size: 19,
                            ),
                          ),
                filled: true,
                fillColor: _koyu
                    ? Colors.black.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.48),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: _yazi.withValues(alpha: 0.07),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: _kirmizi.withValues(alpha: 0.88),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (_hedefOnerileri.isNotEmpty) ...[
            const SizedBox(height: 7),
            Container(
              constraints: const BoxConstraints(maxHeight: 230),
              decoration: BoxDecoration(
                color: _koyu
                    ? Colors.black.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _hedefOnerileri.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 44,
                  color: _yazi.withValues(alpha: 0.07),
                ),
                itemBuilder: (context, index) {
                  final _HedefSonucu hedef = _hedefOnerileri[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _hedefOnerisiniSec(hedef),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: _kirmizi.withValues(alpha: 0.11),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: _kirmizi,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              hedef.ad,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _yazi,
                                fontSize: 11.5,
                                height: 1.24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.north_west_rounded,
                            color: _ikincil,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: (_rotaYukleniyor || _konumYukleniyor || _konumEngelli)
                  ? null
                  : () => _rotaAra(),
              style: FilledButton.styleFrom(
                backgroundColor: _kirmizi,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kirmizi.withValues(alpha: 0.30),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _rotaYukleniyor
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.alt_route_rounded, size: 18),
              label: Text(
                _rotaYukleniyor
                    ? 'Rotalar hazırlanıyor...'
                    : 'Alternatif rotaları bul',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (_hata != null) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: _kirmizi.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: _kirmizi,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _hata!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _yazi.withValues(alpha: 0.82),
                        fontSize: 10.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _aramaPaneliniAcVeOdakla() {
    setState(() {
      _aramaPaneliAcik = true;
      _hata = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hedefFocusNode.requestFocus();
    });
  }

  Widget _hedefOzetKarti() {
    final String hedefAdi = _hedef?.ad ?? _hedefController.text.trim();
    return _camPanel(
      child: InkWell(
        onTap: _aramaPaneliniAcVeOdakla,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: _kirmizi,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'HEDEF',
                      style: TextStyle(
                        color: _ikincil,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hedefAdi.isEmpty ? 'Nereye gidiyorsunuz?' : hedefAdi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _yazi,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (_rotaYukleniyor)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kirmizi,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Hedefi değiştir',
                  onPressed: _aramaPaneliniAcVeOdakla,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: _yazi,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rotaKartlari() {
    if (_rotalar.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _rotalar.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final _RotaSecenegi rota = _rotalar[index];
                final bool secili = index == _seciliRota;
                return InkWell(
                  onTap: () => _rotaSec(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 112,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: secili
                          ? _kirmizi.withValues(alpha: _koyu ? 0.18 : 0.09)
                          : _kart,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: secili
                            ? _kirmizi
                            : _yazi.withValues(alpha: 0.08),
                        width: secili ? 1.4 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Rota ${index + 1}',
                              style: TextStyle(
                                color: secili ? _kirmizi : _yazi,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            if (secili)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 13,
                                color: _kirmizi,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_mesafeYaz(rota.mesafeMetre)} • ${_sureYaz(rota.sureSaniye)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _ikincil,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          height: 64,
          child: FilledButton(
            onPressed: _tesisYukleniyor ? null : _yolaCik,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF18A558),
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFF18A558).withValues(alpha: 0.45),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _tesisYukleniyor
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation_rounded, size: 24),
                      SizedBox(height: 2),
                      Text(
                        'GİT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _harita({required LatLng merkez}) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: merkez,
        initialZoom: _yolculukAktif ? 16.5 : 13.5,
        minZoom: 4,
        maxZoom: 19,
        backgroundColor: const Color(0xFFE8EAED),
        onPositionChanged: (_, hasGesture) {
          if (_yolculukAktif && hasGesture && _haritaTakibi) {
            setState(() {
              _haritaTakibi = false;
            });
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.enobet',
        ),
        PolylineLayer(polylines: _cizgiler()),
        MarkerLayer(markers: _markerlar()),
      ],
    );
  }

  Widget _navigasyonEkrani() {
    final LatLng merkez = _canliKonum ?? _baslangic ?? const LatLng(39.0, 35.0);
    final double ust = MediaQuery.paddingOf(context).top;
    final double alt = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _arkaPlan,
      body: Stack(
        children: [
          Positioned.fill(child: _harita(merkez: merkez)),

          Positioned(
            left: 10,
            right: 146,
            top: ust + 8,
            child: _navigasyonYonlendirmeKarti(),
          ),

          Positioned(
            top: ust + 8,
            right: 8,
            child: _siradakiPanel(),
          ),

          if (_yenidenRotaYukleniyor)
            Positioned(
              left: 10,
              bottom: alt + 96,
              child: _camPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _mavi),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Rota yeniden hesaplanıyor',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),

          if (!_haritaTakibi)
            Positioned(
              left: 12,
              bottom: alt + 96,
              child: _navigasyonDaireButon(
                icon: Icons.my_location_rounded,
                vurgu: true,
                onTap: () {
                  setState(() {
                    _haritaTakibi = true;
                  });
                  if (_rotalar.isEmpty || _seciliRota >= _rotalar.length) return;
                  final LatLng? gps = _canliKonum;
                  if (gps == null) return;
                  final LatLng kamera = _navigasyonKameraMerkezi(
                    rota: _rotalar[_seciliRota],
                    gps: gps,
                    hizMps: 0,
                  );
                  _mapController.moveAndRotate(kamera, 17.1, -_sonHeading);
                },
              ),
            ),

          Positioned(
            left: 10,
            right: 10,
            bottom: alt + 10,
            child: _navigasyonAltBilgi(),
          ),
        ],
      ),
    );
  }

  _RotaAdimi? _siradakiRotaAdimi() {
    if (_rotalar.isEmpty || _seciliRota >= _rotalar.length) return null;
    final List<_RotaAdimi> adimlar = _rotalar[_seciliRota].adimlar;
    for (final _RotaAdimi adim in adimlar) {
      if (adim.rotaMetre > _sonRotaIlerlemesiMetre + 18) return adim;
    }
    return null;
  }

  IconData _manevraIkonu(_RotaAdimi? adim) {
    if (adim == null) return Icons.straight_rounded;
    final String yon = adim.yon.toLowerCase();
    final String tip = adim.tip.toLowerCase();
    if (tip.contains('roundabout') || tip.contains('rotary')) {
      return Icons.refresh_rounded;
    }
    if (yon.contains('right')) return Icons.turn_right_rounded;
    if (yon.contains('left') || yon.contains('uturn')) {
      return Icons.turn_left_rounded;
    }
    return Icons.straight_rounded;
  }

  String _manevraBaslik(_RotaAdimi? adim) {
    if (adim == null) return 'Hedefe doğru devam edin';
    final String yol = adim.yolAdi.trim();
    final String yon = adim.yon.toLowerCase();
    final String tip = adim.tip.toLowerCase();
    String hareket;
    if (tip.contains('roundabout') || tip.contains('rotary')) {
      hareket = 'Dönel kavşağa girin';
    } else if (yon.contains('right')) {
      hareket = 'Sağa dönün';
    } else if (yon.contains('left')) {
      hareket = 'Sola dönün';
    } else if (yon.contains('uturn')) {
      hareket = 'U dönüşü yapın';
    } else {
      hareket = 'Düz devam edin';
    }
    return yol.isEmpty ? hareket : '$hareket • $yol';
  }

  Widget _navigasyonYonlendirmeKarti() {
    final _RotaAdimi? adim = _siradakiRotaAdimi();
    final double kalan = adim == null
        ? _kalanMesafeMetre
        : math.max(0, adim.rotaMetre - _sonRotaIlerlemesiMetre);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: _koyu
                ? const Color(0xFF101419).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: _koyu ? 0.10 : 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _mavi,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _manevraIkonu(adim),
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mesafeYaz(kalan),
                      style: TextStyle(
                        color: _mavi,
                        fontSize: 18,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _manevraBaslik(adim),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _yazi,
                        fontSize: 11.5,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigasyonAltBilgi() {
    final DateTime varis = DateTime.now().add(
      Duration(seconds: math.max(0, _kalanSureSaniye.round())),
    );
    final String hedefAdi = _hedef?.ad ?? 'Hedef';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 76,
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          decoration: BoxDecoration(
            color: _koyu
                ? const Color(0xFF101419).withValues(alpha: 0.90)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: _koyu ? 0.10 : 0.68),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _mesafeYaz(_kalanMesafeMetre),
                          style: TextStyle(
                            color: _yazi,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _sureYaz(_kalanSureSaniye),
                          style: TextStyle(
                            color: _mavi,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Varış ${_saatYaz(varis)}',
                          style: TextStyle(
                            color: _ikincil,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hedefAdi,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ikincil,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _kirmizi.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await _yolculuguDurdur();
                    if (mounted && _rotalar.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _haritayiRotayaOdakla(_rotalar[_seciliRota]);
                        }
                      });
                    }
                  },
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.close_rounded, color: _kirmizi, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navigasyonDaireButon({
    required IconData icon,
    required VoidCallback onTap,
    bool vurgu = false,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: vurgu
              ? _mavi.withValues(alpha: 0.94)
              : (_koyu
                  ? const Color(0xFF111317).withValues(alpha: 0.86)
                  : Colors.white.withValues(alpha: 0.92)),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                icon,
                size: 21,
                color: vurgu ? Colors.white : _yazi,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _siradakiPanel() {
    final List<_GuzergahNoktasi> noktalar = _siradakiIsletmeler(limit: 5);
    final double ekranGenisligi = MediaQuery.sizeOf(context).width;
    final double genislik = math.min(132.0, math.max(112.0, ekranGenisligi * 0.31));

    return SizedBox(
      width: genislik,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 3),
            decoration: BoxDecoration(
              color: _koyu
                  ? const Color(0xFF111317).withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: Colors.white.withValues(alpha: _koyu ? 0.10 : 0.54),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.09),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 1, 4, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.route_rounded, size: 12, color: _mavi),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'YOL ÜSTÜ',
                          style: TextStyle(
                            color: _ikincil,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        '${noktalar.length}/5',
                        style: TextStyle(
                          color: _ikincil,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (noktalar.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 8, 5, 11),
                    child: Text(
                      'İleride doğrulanmış yol üstü işletme yok',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ikincil,
                        fontSize: 9,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    noktalar.length,
                    (index) => _siradakiKarti(index + 1, noktalar[index]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _siradakiKarti(int sira, _GuzergahNoktasi nokta) {
    final Color renk = _guzergahRengi(nokta.tur);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          setState(() {
            _haritaTakibi = false;
          });
          _mapController.move(nokta.konum, 16.4);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _yazi.withValues(alpha: _koyu ? 0.055 : 0.035),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _guzergahIkonu(nokta.tur),
                  color: renk,
                  size: 13,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$sira. ${nokta.isim}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _yazi,
                        fontSize: 8.8,
                        height: 1.08,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _mesafeYaz(_isletmeyeKalanMetre(nokta)),
                      maxLines: 1,
                      style: TextStyle(
                        color: renk,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _saatYaz(DateTime zaman) {
    String iki(int v) => v.toString().padLeft(2, '0');
    return '${iki(zaman.hour)}:${iki(zaman.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_yolculukAktif) {
      return _navigasyonEkrani();
    }

    final LatLng merkez = _baslangic ?? const LatLng(39.0, 35.0);
    final double ustBosluk = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _arkaPlan,
      body: Stack(
        children: [
          Positioned.fill(child: _harita(merkez: merkez)),
          Positioned(
            left: 10,
            top: ustBosluk + 8,
            child: _yuvarlakButon(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: 66,
            right: 10,
            top: ustBosluk + 8,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: !_aramaPaneliAcik
                  ? KeyedSubtree(
                      key: const ValueKey<String>('hedef_ozet'),
                      child: _hedefOzetKarti(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey<String>('arama'),
                      child: _aramaKarti(),
                    ),
            ),
          ),
          if (_baslangic != null && !_konumEngelli && !_konumYukleniyor)
            Positioned(
              left: 12,
              bottom: _rotalar.isEmpty ? 18 : 96,
              child: FloatingActionButton.small(
                heroTag: 'yol_asistani_merkezle',
                onPressed: () {
                  _mapController.move(_baslangic!, 15.2);
                },
                backgroundColor: _kart.withValues(alpha: 0.88),
                foregroundColor: _mavi,
                elevation: 3,
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          if (_rotalar.isNotEmpty && _isletmelerHazirlaniyor)
            Positioned(
              left: 0,
              right: 0,
              bottom: 88 + MediaQuery.paddingOf(context).bottom,
              child: Center(
                child: _camPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: _mavi,
                        ),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Yol üstü işletmeler hazırlanıyor',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_rotalar.isNotEmpty)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10 + MediaQuery.paddingOf(context).bottom,
              child: _camPanel(
                padding: const EdgeInsets.all(7),
                child: _rotaKartlari(),
              ),
            ),
          if (_konumYukleniyor)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: _koyu ? 0.20 : 0.08),
                  child: Center(
                    child: _camPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: _kirmizi,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Konumunuz alınıyor...',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_konumEngelli)
            Positioned.fill(
              child: Container(
                color: _arkaPlan.withValues(alpha: 0.84),
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: _camPanel(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _kirmizi.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_off_rounded,
                            color: _kirmizi,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Konum izni gerekli',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _yazi,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Yol Asistanı canlı konumla çalışır. GPS ve konum iznini açıp tekrar deneyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _ikincil,
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _konumuHazirla,
                            style: FilledButton.styleFrom(
                              backgroundColor: _kirmizi,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.my_location_rounded),
                            label: const Text(
                              'TEKRAR DENE',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

enum _GuzergahTuru {
  akaryakit,
  sarj,
  dinlenme,
}

class _GuzergahNoktasi {
  final String id;
  final String isim;
  final _GuzergahTuru tur;
  final LatLng konum;
  final double rotaBaslangicindanMetre;
  final double rotayaUzaklikMetre;
  final String marka;

  const _GuzergahNoktasi({
    required this.id,
    required this.isim,
    required this.tur,
    required this.konum,
    required this.rotaBaslangicindanMetre,
    required this.rotayaUzaklikMetre,
    required this.marka,
  });
}

class _RotaYakinlik {
  final double rotayaUzaklikMetre;
  final double rotaBaslangicindanMetre;
  final bool sagTarafta;
  final double yanalUzaklikMetre;
  final int segmentIndex;
  final double segmentOrani;

  const _RotaYakinlik({
    required this.rotayaUzaklikMetre,
    required this.rotaBaslangicindanMetre,
    required this.sagTarafta,
    required this.yanalUzaklikMetre,
    required this.segmentIndex,
    required this.segmentOrani,
  });
}

class _HedefSonucu {
  final String ad;
  final LatLng konum;

  const _HedefSonucu({
    required this.ad,
    required this.konum,
  });
}

class _YolHizmetiKaydi {
  final String id;
  final String isim;
  final _GuzergahTuru tur;
  final LatLng konum;
  final String marka;
  final String yolRef;
  final String yolAdi;
  final String yolSinifi;
  final double? yolaKayitliUzaklikMetre;
  final bool yolTekYon;
  final List<LatLng>? yolSegmenti;

  const _YolHizmetiKaydi({
    required this.id,
    required this.isim,
    required this.tur,
    required this.konum,
    required this.marka,
    required this.yolRef,
    required this.yolAdi,
    required this.yolSinifi,
    required this.yolaKayitliUzaklikMetre,
    required this.yolTekYon,
    required this.yolSegmenti,
  });
}

class _RotaAdimi {
  final double rotaMetre;
  final String tip;
  final String yon;
  final String yolAdi;

  const _RotaAdimi({
    required this.rotaMetre,
    required this.tip,
    required this.yon,
    required this.yolAdi,
  });
}

class _RotaSecenegi {
  final double mesafeMetre;
  final double sureSaniye;
  final List<LatLng> noktalar;
  final Set<String> yolReferanslari;
  final List<_RotaAdimi> adimlar;

  const _RotaSecenegi({
    required this.mesafeMetre,
    required this.sureSaniye,
    required this.noktalar,
    required this.yolReferanslari,
    required this.adimlar,
  });
}
