import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/hizmet.dart';
import 'harita_http_basliklari.dart';

class YerelHizmetServisi {
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  // İlçe sınırı ve kategori sonuçlarını aynı oturumda tekrar indirmeyelim.
  // Her kategori yine kendi küçük Overpass sorgusunu kullanır; böylece tek ve
  // çok büyük bir sorgunun bütün kategorileri boş bırakması önlenir.
  static final Map<String, List<double>> _bboxOnbellek = <String, List<double>>{};
  static final Map<String, List<Hizmet>> _kategoriOnbellek = <String, List<Hizmet>>{};

  Future<List<Hizmet>> getir({
    required String kategori,
    required String il,
    required String ilce,
  }) async {
    final String cacheKey = '${_normalize(il)}|${_normalize(ilce)}|$kategori';
    final List<Hizmet>? cached = _kategoriOnbellek[cacheKey];
    if (cached != null) return List<Hizmet>.from(cached);

    final List<double>? bbox = await _ilceBboxGetir(il: il, ilce: ilce);
    if (bbox == null) return <Hizmet>[];

    final String alan = '(${bbox[0]},${bbox[1]},${bbox[2]},${bbox[3]})';
    final String filtre = _filtre(kategori, alan);
    final String sorgu = '''
[out:json][timeout:45];
(
$filtre
);
out body center;
''';

    final http.Response response = await overpassSorgusuCalistir(sorgu);
    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['elements'] is! List) return <Hizmet>[];

    final List<Hizmet> sonuc = <Hizmet>[];
    final Set<String> gorulen = <String>{};

    for (final dynamic raw in data['elements'] as List) {
      if (raw is! Map) continue;
      final Map<String, dynamic> e = Map<String, dynamic>.from(raw);
      final Map<String, dynamic> tags =
          Map<String, dynamic>.from(e['tags'] as Map? ?? const {});
      final Map<String, dynamic> center =
          Map<String, dynamic>.from(e['center'] as Map? ?? const {});
      final double? enlem = ((e['lat'] ?? center['lat']) as num?)?.toDouble();
      final double? boylam = ((e['lon'] ?? center['lon']) as num?)?.toDouble();
      if (enlem == null || boylam == null || enlem == 0 || boylam == 0) {
        continue;
      }

      final String id = 'osm_${e['type']}_${e['id']}';
      if (!gorulen.add(id)) continue;

      final String isim = (tags['name'] ??
              tags['brand'] ??
              tags['operator'] ??
              _varsayilanIsim(kategori))
          .toString();
      final String adres = <dynamic>[
        tags['addr:street'],
        tags['addr:housenumber'],
        tags['addr:neighbourhood'],
        tags['addr:suburb'],
        ilce,
        il,
      ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' ');

      sonuc.add(
        Hizmet(
          id: id,
          isim: isim,
          kategori: kategori,
          adres: adres.isEmpty ? '$ilce / $il' : adres,
          telefon: (tags['phone'] ?? tags['contact:phone'] ?? '').toString(),
          durum: 'Çalışma durumu bilinmiyor',
          mesafe: 'Mesafe bilinmiyor',
          calismaSaatleri:
              (tags['opening_hours'] ?? 'Çalışma saati bilinmiyor').toString(),
          ikon: _ikon(kategori),
          renk: _renk(kategori),
          enlem: enlem,
          boylam: boylam,
          il: il,
          ilce: ilce,
        ),
      );
    }

    _kategoriOnbellek[cacheKey] = List<Hizmet>.from(sonuc);
    return sonuc;
  }

  String _filtre(String kategori, String alan) {
    switch (kategori) {
      case 'Hastane':
        return '  nwr["amenity"="hospital"]$alan;\n'
            '  nwr["healthcare"="hospital"]$alan;';
      case 'ATM':
        return '  nwr["amenity"="atm"]$alan;\n'
            '  nwr["amenity"="bank"]["atm"="yes"]$alan;';
      case 'Taksi':
        return '  nwr["amenity"="taxi"]$alan;';
      case 'Benzin':
        return '  nwr["amenity"="fuel"]$alan;';
      case 'Kargo':
        return '  nwr["amenity"="post_office"]$alan;\n'
            '  nwr["office"="courier"]$alan;\n'
            '  nwr["shop"="courier"]$alan;';
      case 'Otogar':
        return '  nwr["amenity"="bus_station"]$alan;\n'
            '  nwr["public_transport"="station"]["bus"="yes"]$alan;';
      default:
        return '  nwr["name"="__enobet_bos_sorgu__"]$alan;';
    }
  }

  Future<List<double>?> _ilceBboxGetir({
    required String il,
    required String ilce,
  }) async {
    final String cacheKey = '${_normalize(il)}|${_normalize(ilce)}';
    final List<double>? cached = _bboxOnbellek[cacheKey];
    if (cached != null) return List<double>.from(cached);

    try {
      final Uri url = Uri.parse(_nominatimUrl).replace(
        queryParameters: <String, String>{
          'q': '$ilce, $il, Türkiye',
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'tr',
          'accept-language': 'tr',
        },
      );
      final http.Response response = await http
          .get(url, headers: nominatimBasliklari())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List || data.isEmpty) return null;

      Map<String, dynamic>? secilen;
      for (final dynamic raw in data) {
        if (raw is! Map) continue;
        final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
        final Map<String, dynamic> adres =
            Map<String, dynamic>.from(item['address'] as Map? ?? const {});
        final String bulunanIlce = (adres['county'] ??
                adres['district'] ??
                adres['city_district'] ??
                adres['town'] ??
                adres['municipality'] ??
                adres['city'] ??
                '')
            .toString();
        if (_normalize(bulunanIlce).contains(_normalize(ilce)) ||
            _normalize(ilce).contains(_normalize(bulunanIlce))) {
          secilen = item;
          break;
        }
      }
      secilen ??= Map<String, dynamic>.from(data.first as Map);

      final dynamic box = secilen['boundingbox'];
      if (box is! List || box.length < 4) return null;
      final double? guney = double.tryParse(box[0].toString());
      final double? kuzey = double.tryParse(box[1].toString());
      final double? bati = double.tryParse(box[2].toString());
      final double? dogu = double.tryParse(box[3].toString());
      if (guney == null || kuzey == null || bati == null || dogu == null) {
        return null;
      }
      final List<double> sonuc = <double>[guney, bati, kuzey, dogu];
      _bboxOnbellek[cacheKey] = List<double>.from(sonuc);
      return sonuc;
    } catch (_) {
      return null;
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();

  String _varsayilanIsim(String kategori) {
    switch (kategori) {
      case 'Hastane':
        return 'Hastane';
      case 'ATM':
        return 'ATM';
      case 'Taksi':
        return 'Taksi Durağı';
      case 'Benzin':
        return 'Benzin İstasyonu';
      case 'Kargo':
        return 'Kargo';
      case 'Otogar':
        return 'Otogar';
      default:
        return kategori;
    }
  }

  IconData _ikon(String kategori) {
    switch (kategori) {
      case 'Hastane':
        return Icons.local_hospital_rounded;
      case 'ATM':
        return Icons.local_atm_rounded;
      case 'Taksi':
        return Icons.local_taxi_rounded;
      case 'Benzin':
        return Icons.local_gas_station_rounded;
      case 'Kargo':
        return Icons.local_shipping_rounded;
      case 'Otogar':
        return Icons.directions_bus_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Color _renk(String kategori) {
    switch (kategori) {
      case 'Hastane':
        return const Color(0xFF2F80ED);
      case 'ATM':
        return const Color(0xFF7A5AF8);
      case 'Taksi':
        return const Color(0xFFFFB020);
      case 'Benzin':
        return const Color(0xFFFF8A00);
      case 'Kargo':
        return const Color(0xFF8E6CEF);
      case 'Otogar':
        return const Color(0xFF3A86FF);
      default:
        return const Color(0xFF3185E8);
    }
  }
}
