import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/hizmet.dart';
import 'harita_http_basliklari.dart';

class CilingirServisi {
  static const String _nominatimUrl =
      'https://nominatim.openstreetmap.org/search';

  Future<List<Hizmet>> cilingirleriGetir({
    required String il,
    required String ilce,
  }) async {
    try {
      final List<double>? bbox = await _ilceBboxGetir(
        il: il,
        ilce: ilce,
      );

      if (bbox != null) {
        final List<Hizmet> sonuc = await _bboxSorgula(
          il: il,
          ilce: ilce,
          guney: bbox[0],
          bati: bbox[1],
          kuzey: bbox[2],
          dogu: bbox[3],
        );

        if (sonuc.isNotEmpty) {
          return sonuc;
        }
      }

      return await _ilceAlanSorgula(
        il: il,
        ilce: ilce,
      );
    } catch (e) {
      throw Exception(
        'Çilingir verisi alınırken hata oluştu: $e',
      );
    }
  }

  Future<List<Hizmet>> getir({
    required String il,
    required String ilce,
  }) async {
    return cilingirleriGetir(
      il: il,
      ilce: ilce,
    );
  }

  Future<List<double>?> _ilceBboxGetir({
    required String il,
    required String ilce,
  }) async {
    try {
      final Uri url = Uri.parse(_nominatimUrl).replace(
        queryParameters: {
          'q': '$ilce, $il, Türkiye',
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
          'polygon_geojson': '0',
          'countrycodes': 'tr',
          'accept-language': 'tr',
        },
      );

      final http.Response response = await http.get(
        url,
      headers: nominatimBasliklari(),
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic data = jsonDecode(response.body);

      if (data is! List) {
        return null;
      }

      Map<String, dynamic>? aday;

      for (final dynamic item in data) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> map =
            Map<String, dynamic>.from(item);

        final dynamic addressDynamic = map['address'];

        final Map<String, dynamic> address =
            addressDynamic is Map
                ? Map<String, dynamic>.from(addressDynamic)
                : <String, dynamic>{};

        final String ilceAdi = (
          address['county'] ??
          address['district'] ??
          address['city_district'] ??
          address['town'] ??
          ''
        ).toString();

        if (_ayniMetinMi(ilceAdi, ilce)) {
          aday = map;

          final String sinif =
              map['class']?.toString().toLowerCase() ?? '';

          final String tip =
              map['type']?.toString().toLowerCase() ?? '';

          if (sinif == 'boundary' &&
              tip == 'administrative') {
            break;
          }
        }
      }

      aday ??= data.isNotEmpty && data.first is Map
          ? Map<String, dynamic>.from(
              data.first as Map,
            )
          : null;

      if (aday == null) {
        return null;
      }

      final dynamic box = aday['boundingbox'];

      if (box is! List || box.length < 4) {
        return null;
      }

      final double? guney =
          double.tryParse(box[0].toString());

      final double? kuzey =
          double.tryParse(box[1].toString());

      final double? bati =
          double.tryParse(box[2].toString());

      final double? dogu =
          double.tryParse(box[3].toString());

      if (guney == null ||
          kuzey == null ||
          bati == null ||
          dogu == null) {
        return null;
      }

      if (guney >= kuzey || bati >= dogu) {
        return null;
      }

      return [
        guney,
        bati,
        kuzey,
        dogu,
      ];
    } catch (_) {
      return null;
    }
  }

  Future<List<Hizmet>> _bboxSorgula({
    required String il,
    required String ilce,
    required double guney,
    required double bati,
    required double kuzey,
    required double dogu,
  }) async {
    final String alan =
        '($guney,$bati,$kuzey,$dogu)';

    final String sorgu = '''
[out:json][timeout:45];
(
  nwr["craft"="locksmith"]$alan;
  nwr["shop"="locksmith"]$alan;
  nwr["craft"="key_cutter"]$alan;
  nwr["shop"="key_cutter"]$alan;
  nwr["name"~"çilingir|cilingir|anahtarcı|anahtarci|anahtar|locksmith|key cutter",i]$alan;
);
out body center;
''';

    return _sorguyuCalistir(
      sorgu: sorgu,
      il: il,
      ilce: ilce,
    );
  }

  Future<List<Hizmet>> _ilceAlanSorgula({
    required String il,
    required String ilce,
  }) async {
    final String ilRegex =
        _overpassRegex(il);

    final String ilceRegex =
        _overpassRegex(ilce);

    final String sorgu = '''
[out:json][timeout:45];

area
  ["name"~"^$ilRegex\$",i]
  ["boundary"="administrative"]
  ["admin_level"="4"]
  ->.ilArea;

area
  ["name"~"^$ilceRegex\$",i]
  ["boundary"="administrative"]
  ["admin_level"~"6|7|8"]
  (area.ilArea)
  ->.ilceArea;

(
  nwr["craft"="locksmith"](area.ilceArea);
  nwr["shop"="locksmith"](area.ilceArea);
  nwr["craft"="key_cutter"](area.ilceArea);
  nwr["shop"="key_cutter"](area.ilceArea);
  nwr["name"~"çilingir|cilingir|anahtarcı|anahtarci|anahtar|locksmith|key cutter",i](area.ilceArea);
);

out body center;
''';

    return _sorguyuCalistir(
      sorgu: sorgu,
      il: il,
      ilce: ilce,
    );
  }

  Future<List<Hizmet>> _sorguyuCalistir({
    required String sorgu,
    required String il,
    required String ilce,
  }) async {
    final http.Response response =
        await overpassSorgusuCalistir(sorgu);

    if (response.statusCode != 200) {
      throw Exception(
        'Sunucu kodu: ${response.statusCode}',
      );
    }

    final dynamic data =
        jsonDecode(response.body);

    if (data is! Map) {
      return [];
    }

    final dynamic elements =
        data['elements'];

    if (elements is! List) {
      return [];
    }

    final List<Hizmet> sonuc = [];

    final Set<String> bulunanIdler = {};

    for (final dynamic element in elements) {
      if (element is! Map) {
        continue;
      }

      final dynamic tagsDynamic =
          element['tags'];

      if (tagsDynamic is! Map) {
        continue;
      }

      final Map<String, dynamic> tags =
          Map<String, dynamic>.from(tagsDynamic);

      final double? enlem =
          _koordinatGetir(element, 'lat');

      final double? boylam =
          _koordinatGetir(element, 'lon');

      if (enlem == null ||
          boylam == null) {
        continue;
      }

      final String id =
          'cilingir_${element['type']}_${element['id']}';

      if (!bulunanIdler.add(id)) {
        continue;
      }

      final String isim =
          _isimGetir(tags);

      final String adres =
          _adresOlustur(
        tags,
        il,
        ilce,
      );

      final String telefon =
          _telefonGetir(tags);

      final String saat =
          _calismaSaatleriGetir(tags);

      final String durum =
          _durumGetir(
        tags['opening_hours'],
      );

      sonuc.add(
        Hizmet(
          id: id,
          isim: isim,
          kategori: 'Çilingir',
          adres: adres,
          telefon: telefon,
          durum: durum,
          mesafe: '-',
          calismaSaatleri: saat,
          ikon: Icons.key_rounded,
          renk: const Color(0xFF9C6BFF),
          enlem: enlem,
          boylam: boylam,
          il: il,
          ilce: ilce,
        ),
      );
    }

    return sonuc;
  }

  String _isimGetir(
    Map<String, dynamic> tags,
  ) {
    for (final String alan in const [
      'name',
      'official_name',
      'brand',
      'operator',
    ]) {
      final String value =
          tags[alan]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Çilingir';
  }

  String _telefonGetir(
    Map<String, dynamic> tags,
  ) {
    for (final String alan in const [
      'phone',
      'contact:phone',
      'mobile',
      'contact:mobile',
      'telephone',
    ]) {
      final String value =
          tags[alan]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'Telefon bilgisi yok';
  }

  String _calismaSaatleriGetir(
    Map<String, dynamic> tags,
  ) {
    final String value =
        tags['opening_hours']?.toString().trim() ?? '';

    if (value.isNotEmpty) {
      return value;
    }

    return 'Çalışma saati belirtilmemiş';
  }

  String _durumGetir(
    dynamic openingHours,
  ) {
    if (openingHours == null) {
      return 'Bilgi yok';
    }

    final String value =
        openingHours.toString().toLowerCase();

    if (value.contains('24/7')) {
      return 'Açık';
    }

    return 'Bilgi yok';
  }

  double? _koordinatGetir(
    Map element,
    String alan,
  ) {
    dynamic value = element[alan];

    if (value == null &&
        element['center'] is Map) {
      value =
          (element['center'] as Map)[alan];
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  String _adresOlustur(
    Map<String, dynamic> tags,
    String il,
    String ilce,
  ) {
    final List<String> parcalar = [];

    for (final String alan in const [
      'addr:street',
      'addr:housenumber',
      'addr:suburb',
      'addr:neighbourhood',
    ]) {
      final String value =
          tags[alan]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        parcalar.add(value);
      }
    }

    if (parcalar.isEmpty) {
      return '$ilce, $il';
    }

    return '${parcalar.join(' ')}, $ilce, $il';
  }

  String _overpassRegex(
    String value,
  ) {
    return value.trim().replaceAllMapped(
      RegExp(r'[\\.^$|()\[\]{}*+?]'),
      (match) =>
          '\\${match.group(0)}',
    );
  }

  bool _ayniMetinMi(
    String a,
    String b,
  ) {
    String temizle(
      String value,
    ) {
      return value
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .trim();
    }

    return temizle(a) == temizle(b);
  }
}
