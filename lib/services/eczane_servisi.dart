import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/hizmet.dart';
import 'hizmet_siralama.dart';

class EczaneServisi {
  final http.Client? client;

  EczaneServisi({this.client});

  static const String _kaynak = 'https://api.teknikzeka.net/v1/index.php';

  // API anahtarı kaynak koda yazılmaz.
  // Çalıştırırken:
  // flutter run --dart-define=TEKNIKZEKA_API_KEY=ANAHTARIN
  // veya APK oluştururken:
  // flutter build apk --release --dart-define=TEKNIKZEKA_API_KEY=ANAHTARIN
  static const String _apiKey = String.fromEnvironment(
    'TEKNIKZEKA_API_KEY',
    defaultValue: '',
  );

  final Map<String, List<Hizmet>> _listeOnbellegi = {};

  Future<http.Response> _get(Uri url) {
    if (_apiKey.trim().isEmpty) {
      throw Exception(
        'TeknikZeka API anahtarı tanımlı değil. '
        'TEKNIKZEKA_API_KEY dart-define değeri gerekli.',
      );
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'X-API-Key': _apiKey,
    };

    return (client == null
            ? http.get(url, headers: headers)
            : client!.get(url, headers: headers))
        .timeout(const Duration(seconds: 20));
  }

  Future<List<Hizmet>> nobetciEczaneleriGetir({
    required String il,
    required String ilce,
  }) async {
    final ilTemiz = il.trim();
    final ilceTemiz = ilce.trim();

    if (ilTemiz.isEmpty) {
      throw Exception('İl bilgisi boş.');
    }

    final cacheKey =
        '${_apiMetni(ilTemiz)}|${_apiMetni(ilceTemiz)}';

    final onbellek = _listeOnbellegi[cacheKey];
    if (onbellek != null) {
      return List<Hizmet>.from(onbellek);
    }

    try {
      final liste = await _apiEczaneleriniGetir(
        il: ilTemiz,
        ilce: ilceTemiz,
      );

      _listeOnbellegi[cacheKey] = List<Hizmet>.from(liste);
      return liste;
    } catch (e) {
      throw Exception('Nöbetçi eczane verisi alınırken hata oluştu: $e');
    }
  }

  Future<List<Hizmet>> nobetciEczaneleriGpsGetir({
    required Position konum,
    required List<String> iller,
    double yaricapKm = 30,
  }) async {
    if (!yaricapKm.isFinite || yaricapKm <= 0) {
      throw ArgumentError.value(yaricapKm, 'yaricapKm');
    }

    final benzersizIller = <String, String>{};

    for (final il in iller) {
      final temiz = il.trim();
      if (temiz.isEmpty) continue;
      benzersizIller[_aramaIcinDuzenle(temiz)] = temiz;
    }

    if (benzersizIller.isEmpty) {
      return <Hizmet>[];
    }

    final tumu = <Hizmet>[];
    final ilListesi = benzersizIller.values.toList();

    // Sınır bölgelerinde birden fazla ili sorgulayabilmek için
    // mevcut ENöbet davranışı korunuyor.
    for (var i = 0; i < ilListesi.length; i += 3) {
      final parca = await Future.wait(
        ilListesi.skip(i).take(3).map((il) async {
          try {
            return await nobetciEczaneleriGetir(
              il: il,
              ilce: '',
            );
          } catch (_) {
            return <Hizmet>[];
          }
        }),
      );

      for (final liste in parca) {
        tumu.addAll(liste);
      }
    }

    final yakin = <Hizmet>[];
    final gorulen = <String>{};

    for (final h in tumu) {
      if (!_gecerliKoordinat(h.enlem, h.boylam)) continue;

      final metre = Geolocator.distanceBetween(
        konum.latitude,
        konum.longitude,
        h.enlem,
        h.boylam,
      );

      if (!metre.isFinite || metre > yaricapKm * 1000) continue;

      final anahtar =
          '${aramaMetni(h.isim)}|${h.enlem.toStringAsFixed(5)}|'
          '${h.boylam.toStringAsFixed(5)}';

      if (!gorulen.add(anahtar)) continue;

      yakin.add(
        h.copyWith(
          mesafe: metre < 1000
              ? '${metre.round()} m'
              : '${(metre / 1000).toStringAsFixed(1)} km',
        ),
      );
    }

    return mesafeyeGoreSirala(yakin, konum);
  }

  Future<List<Hizmet>> _apiEczaneleriniGetir({
    required String il,
    required String ilce,
  }) async {
    final parametreler = <String, String>{
      'service': 'eczane',
      'endpoint': 'nobetci',
      'il': _apiIlMetni(il),
      'tumu': '4',
    };

    if (ilce.trim().isNotEmpty) {
      parametreler['ilce'] = _apiMetni(ilce);
    }

    final url = Uri.parse(_kaynak).replace(
      queryParameters: parametreler,
    );

    final response = await _get(url);

    if (response.statusCode != 200) {
      throw Exception(
        'TeknikZeka API bağlantı hatası. Kod: ${response.statusCode}',
      );
    }

    dynamic json;

    try {
      json = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (_) {
      throw Exception('TeknikZeka API geçerli JSON döndürmedi.');
    }

    if (json is! Map<String, dynamic>) {
      throw Exception('TeknikZeka API yanıt biçimi geçersiz.');
    }

    final success = json['success'];

    if (success != true) {
      final mesaj =
          json['message']?.toString().trim() ??
          json['error']?.toString().trim() ??
          'Bilinmeyen API hatası.';
      throw Exception(mesaj);
    }

    final data = json['data'];

    if (data is! List) {
      return <Hizmet>[];
    }

    final sonuc = <Hizmet>[];
    final gorulen = <String>{};

    for (final item in data) {
      if (item is! Map) continue;

      final kayit = Map<String, dynamic>.from(item);

      final id = kayit['id']?.toString().trim() ?? '';
      final isim = kayit['name']?.toString().trim() ?? '';
      final kayitIl = kayit['city']?.toString().trim() ?? il;
      final kayitIlce = kayit['district']?.toString().trim() ?? ilce;
      final adres = kayit['address']?.toString().trim() ?? '';
      final telefon = _telefonDuzenle(
        kayit['phone']?.toString().trim() ?? '',
      );

      final enlem = _doubleDeger(kayit['lat']);
      final boylam = _doubleDeger(kayit['lon']);

      final workdate = kayit['workdate']?.toString().trim() ?? '';
      final shiftend = kayit['shiftend']?.toString().trim() ?? '';

      if (isim.isEmpty) continue;

      final anahtar = id.isNotEmpty
          ? 'teknikzeka-$id'
          : '${aramaMetni(isim)}|${aramaMetni(adres)}|'
              '${aramaMetni(kayitIlce)}';

      if (!gorulen.add(anahtar)) continue;

      sonuc.add(
        Hizmet(
          id: id.isNotEmpty
              ? 'teknikzeka-eczane-$id'
              : 'teknikzeka-eczane-${_aramaIcinDuzenle(kayitIl)}-'
                  '${_aramaIcinDuzenle(kayitIlce)}-'
                  '${_aramaIcinDuzenle(isim)}',
          isim: isim,
          kategori: 'Nöbetçi Eczane',
          adres: adres.isEmpty ? 'Adres bilgisi yok' : adres,
          telefon:
              telefon.isEmpty ? 'Telefon bilgisi yok' : telefon,
          durum: 'Açık',
          mesafe: '-',
          calismaSaatleri: _calismaSaatleri(
            baslangic: workdate,
            bitis: shiftend,
          ),
          ikon: Icons.local_pharmacy_rounded,
          renk: const Color(0xFFE3262E),
          enlem: enlem,
          boylam: boylam,
          il: kayitIl.isEmpty ? il : kayitIl,
          ilce: kayitIlce.isEmpty ? ilce : kayitIlce,
        ),
      );
    }

    if (sonuc.isEmpty && ilce.trim().isNotEmpty) {
      final ilGeneli = await _apiEczaneleriniGetir(
        il: il,
        ilce: '',
      );

      final hedefIlce = _aramaIcinDuzenle(ilce);

      return ilGeneli.where((eczane) {
        return _aramaIcinDuzenle(eczane.ilce) == hedefIlce;
      }).toList();
    }

    return sonuc;
  }

  double _doubleDeger(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _telefonDuzenle(String telefon) {
    final rakamlar = telefon.replaceAll(RegExp(r'\D'), '');

    if (rakamlar.length == 10) {
      return '0${rakamlar.substring(0, 3)} '
          '${rakamlar.substring(3, 6)} '
          '${rakamlar.substring(6, 8)} '
          '${rakamlar.substring(8, 10)}';
    }

    if (rakamlar.length == 11 && rakamlar.startsWith('0')) {
      return '${rakamlar.substring(0, 4)} '
          '${rakamlar.substring(4, 7)} '
          '${rakamlar.substring(7, 9)} '
          '${rakamlar.substring(9, 11)}';
    }

    return telefon.trim();
  }

  String _calismaSaatleri({
    required String baslangic,
    required String bitis,
  }) {
    final baslangicSaat = _saatAyikla(baslangic);
    final bitisSaat = _saatAyikla(bitis);

    if (baslangicSaat.isNotEmpty && bitisSaat.isNotEmpty) {
      return '$baslangicSaat - $bitisSaat';
    }

    if (bitisSaat.isNotEmpty) {
      return 'Nöbet bitişi: $bitisSaat';
    }

    return 'Nöbetçi';
  }

  String _saatAyikla(String tarihSaat) {
    final match = RegExp(r'\b(\d{2}:\d{2})(?::\d{2})?\b')
        .firstMatch(tarihSaat);
    return match?.group(1) ?? '';
  }

  bool _gecerliKoordinat(double enlem, double boylam) {
    return enlem.isFinite &&
        boylam.isFinite &&
        enlem != 0 &&
        boylam != 0 &&
        enlem.abs() <= 90 &&
        boylam.abs() <= 180;
  }

  String _apiIlMetni(String deger) {
    return _aramaIcinDuzenle(deger).replaceAll('-', ' ');
  }

  String _apiMetni(String deger) {
    return deger.trim().toUpperCase();
  }

  String _aramaIcinDuzenle(String deger) {
    return deger
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }
}
