import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/hizmet.dart';

class AvmMagaza {
  final String id;
  final String isim;
  final String tur;
  final String kategori;
  final String kat;
  final String telefon;
  final String website;

  const AvmMagaza({
    required this.id,
    required this.isim,
    required this.tur,
    required this.kategori,
    required this.kat,
    required this.telefon,
    required this.website,
  });
}

class AvmMagazaSonucu {
  final List<AvmMagaza> magazalar;
  final bool avmSiniriKullanildi;

  const AvmMagazaSonucu({
    required this.magazalar,
    required this.avmSiniriKullanildi,
  });
}

/// AVM içi mağaza rehberi.
///
/// Mağaza verisi artık telefonda canlı Overpass isteğiyle alınmıyor.
/// APK hazırlanırken güncel Türkiye OpenStreetMap/Geofabrik verisinden
/// `assets/data/avm_magazalari.json` oluşturuluyor ve uygulama bu yerel
/// dosyayı kullanıyor. Böylece mağaza ekranı Overpass sunucularının
/// erişilebilirliğine bağlı kalmıyor.
class AvmMagazaServisi {
  AvmMagazaServisi._();

  static final AvmMagazaServisi ortak = AvmMagazaServisi._();

  static const String _assetYolu =
      'assets/data/avm_magazalari.json';

  Map<String, dynamic>? _avmler;

  Future<AvmMagazaSonucu> getir(Hizmet avm) async {
    final Map<String, dynamic> avmler = await _veriyiYukle();

    Map<String, dynamic>? kayit;

    final dynamic tamEslesme = avmler[avm.id];

    if (tamEslesme is Map) {
      kayit = Map<String, dynamic>.from(tamEslesme);
    }

    // OSM kimliği ileride değişirse aynı isimli AVM kaydını yedek olarak ara.
    if (kayit == null) {
      final String hedef = _normalize(avm.isim);

      for (final dynamic raw in avmler.values) {
        if (raw is! Map) continue;

        final Map<String, dynamic> item =
            Map<String, dynamic>.from(raw);

        if (_normalize(item['avmAdi']?.toString() ?? '') == hedef) {
          kayit = item;
          break;
        }
      }
    }

    if (kayit == null) {
      return const AvmMagazaSonucu(
        magazalar: <AvmMagaza>[],
        avmSiniriKullanildi: false,
      );
    }

    final dynamic rawRecords = kayit['records'];
    final List<AvmMagaza> magazalar = <AvmMagaza>[];

    if (rawRecords is List) {
      for (final dynamic raw in rawRecords) {
        if (raw is! Map) continue;

        final Map<String, dynamic> item =
            Map<String, dynamic>.from(raw);

        final String isim =
            item['isim']?.toString().trim() ?? '';

        if (isim.isEmpty) continue;

        magazalar.add(
          AvmMagaza(
            id: item['id']?.toString().trim() ?? '',
            isim: isim,
            tur: item['tur']?.toString().trim().isNotEmpty == true
                ? item['tur'].toString().trim()
                : 'Mağaza',
            kategori:
                item['kategori']?.toString().trim().isNotEmpty == true
                    ? item['kategori'].toString().trim()
                    : 'Diğer',
            kat: item['kat']?.toString().trim() ?? '',
            telefon: item['telefon']?.toString().trim() ?? '',
            website: item['website']?.toString().trim() ?? '',
          ),
        );
      }
    }

    magazalar.sort((AvmMagaza a, AvmMagaza b) {
      final int isim =
          a.isim.toLowerCase().compareTo(b.isim.toLowerCase());

      if (isim != 0) return isim;

      return a.kat.compareTo(b.kat);
    });

    return AvmMagazaSonucu(
      magazalar: magazalar,
      avmSiniriKullanildi: kayit['sinirIci'] == true,
    );
  }

  Future<Map<String, dynamic>> _veriyiYukle() async {
    final Map<String, dynamic>? cached = _avmler;
    if (cached != null) return cached;

    final String raw = await rootBundle.loadString(_assetYolu);
    final dynamic decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'AVM mağaza veri dosyası geçersiz.',
      );
    }

    final dynamic rawMalls = decoded['malls'];

    if (rawMalls is! Map) {
      throw const FormatException(
        'AVM mağaza rehberi bulunamadı.',
      );
    }

    final Map<String, dynamic> sonuc =
        Map<String, dynamic>.from(rawMalls);

    _avmler = sonuc;
    return sonuc;
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
