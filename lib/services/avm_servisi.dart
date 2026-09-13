import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hizmet.dart';

/// AVM & Outlet listesi artık telefonda canlı Overpass isteğine bağlı değildir.
///
/// APK hazırlanırken Geofabrik'in güncel Türkiye OpenStreetMap paketinden
/// `assets/data/avmler.json` üretilir. Uygulama bu yerel dosyayı kullanır.
/// Böylece Overpass sunucusu yoğun/kapalı olsa bile AVM listesi açılır.
class AvmServisi {
  static const Color _renk = Color(0xFFB565F2);
  static const String _assetYolu = 'assets/data/avmler.json';

  List<Hizmet>? _onbellek;

  Future<List<Hizmet>> getir({
    required String il,
    required String ilce,
    required bool gpsModu,
    double? enlem,
    double? boylam,
    double yaricapKm = 30,
  }) async {
    final List<Hizmet> tumu = await _tumKayitlariYukle();

    if (tumu.isEmpty) {
      throw Exception(
        'AVM veri paketi boş. APK oluşturma sırasında AVM verisi üretilememiş.',
      );
    }

    if (gpsModu && _gecerliKoordinat(enlem, boylam)) {
      return _gpsSonuclari(
        tumu,
        enlem: enlem!,
        boylam: boylam!,
        yaricapKm: yaricapKm,
      );
    }

    if (il.trim().isEmpty) {
      return const <Hizmet>[];
    }

    final String normalIl = _normalize(il);
    final String normalIlce = _normalize(ilce);

    final List<Hizmet> ilKayitlari = tumu
        .where((Hizmet h) => _normalize(h.il) == normalIl)
        .toList();

    if (normalIlce.isNotEmpty) {
      final List<Hizmet> ilceKayitlari = ilKayitlari
          .where((Hizmet h) => _normalize(h.ilce) == normalIlce)
          .toList();

      if (ilceKayitlari.isNotEmpty) {
        return ilceKayitlari;
      }
    }

    // İlçede kayıt yoksa il genelini göster.
    return ilKayitlari;
  }

  Future<List<Hizmet>> _tumKayitlariYukle() async {
    final List<Hizmet>? cached = _onbellek;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetYolu);
    final dynamic decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException('AVM veri dosyası geçersiz.');
    }

    final dynamic rawRecords = decoded['records'];

    if (rawRecords is! List) {
      throw const FormatException('AVM kayıt listesi bulunamadı.');
    }

    final List<Hizmet> sonuc = <Hizmet>[];

    for (final dynamic item in rawRecords) {
      if (item is! Map) continue;

      final Map<String, dynamic> map =
          Map<String, dynamic>.from(item as Map);

      final String isim = map['isim']?.toString().trim() ?? '';
      final double? enlem = _double(map['enlem']);
      final double? boylam = _double(map['boylam']);

      if (isim.isEmpty || !_gecerliKoordinat(enlem, boylam)) {
        continue;
      }

      final String durum =
          map['durum']?.toString().trim().isNotEmpty == true
              ? map['durum'].toString().trim()
              : (_normalize(isim).contains('outlet') ? 'Outlet' : 'AVM');

      sonuc.add(
        Hizmet(
          id: map['id']?.toString().trim().isNotEmpty == true
              ? map['id'].toString().trim()
              : 'avm_${sonuc.length}',
          isim: isim,
          kategori: 'AVM & Outlet',
          adres: map['adres']?.toString().trim().isNotEmpty == true
              ? map['adres'].toString().trim()
              : 'Adres bilgisi yok',
          telefon: map['telefon']?.toString().trim().isNotEmpty == true
              ? map['telefon'].toString().trim()
              : 'Telefon bilgisi yok',
          durum: durum,
          mesafe: '-',
          calismaSaatleri:
              map['calismaSaatleri']?.toString().trim().isNotEmpty == true
                  ? map['calismaSaatleri'].toString().trim()
                  : 'Çalışma saati belirtilmemiş',
          ikon: Icons.local_mall_rounded,
          renk: _renk,
          enlem: enlem!,
          boylam: boylam!,
          il: map['il']?.toString().trim() ?? '',
          ilce: map['ilce']?.toString().trim() ?? '',
        ),
      );
    }

    // Aynı isimli ve neredeyse aynı koordinattaki olası OSM kopyalarını temizle.
    final List<Hizmet> benzersiz = <Hizmet>[];

    for (final Hizmet aday in sonuc) {
      final bool varMi = benzersiz.any((Hizmet mevcut) {
        if (_normalize(mevcut.isim) != _normalize(aday.isim)) return false;

        return _mesafeKm(
              mevcut.enlem,
              mevcut.boylam,
              aday.enlem,
              aday.boylam,
            ) <
            0.8;
      });

      if (!varMi) benzersiz.add(aday);
    }

    _onbellek = benzersiz;
    return benzersiz;
  }

  List<Hizmet> _gpsSonuclari(
    List<Hizmet> tumu, {
    required double enlem,
    required double boylam,
    required double yaricapKm,
  }) {
    final double yaricap = yaricapKm.clamp(5, 80).toDouble();

    final List<_MesafeliHizmet> sirali = tumu
        .map(
          (Hizmet h) => _MesafeliHizmet(
            hizmet: h,
            km: _mesafeKm(enlem, boylam, h.enlem, h.boylam),
          ),
        )
        .toList()
      ..sort(
        (_MesafeliHizmet a, _MesafeliHizmet b) => a.km.compareTo(b.km),
      );

    final List<Hizmet> yakin = sirali
        .where((_MesafeliHizmet item) => item.km <= yaricap)
        .map((_MesafeliHizmet item) => item.hizmet)
        .toList();

    if (yakin.isNotEmpty) {
      return yakin;
    }

    // 30 km çevresinde AVM yoksa kullanıcıyı tamamen boş bırakma:
    // en yakın birkaç seçeneği göster.
    return sirali
        .take(8)
        .map((_MesafeliHizmet item) => item.hizmet)
        .toList();
  }

  double _mesafeKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double dunyaYaricapiKm = 6371.0088;

    double rad(double derece) => derece * math.pi / 180;

    final double dLat = rad(lat2 - lat1);
    final double dLon = rad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return dunyaYaricapiKm *
        2 *
        math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  bool _gecerliKoordinat(double? lat, double? lon) {
    if (lat == null || lon == null) return false;

    return lat >= 35 &&
        lat <= 43 &&
        lon >= 25 &&
        lon <= 46;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

class _MesafeliHizmet {
  final Hizmet hizmet;
  final double km;

  const _MesafeliHizmet({
    required this.hizmet,
    required this.km,
  });
}
