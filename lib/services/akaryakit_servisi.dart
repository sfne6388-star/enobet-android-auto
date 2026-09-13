import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AkaryakitFiyatlari {
  final double? benzin;
  final double? motorin;
  final double? lpg;
  final String? tarih;
  final String kaynak;
  final String? bolge;

  const AkaryakitFiyatlari({
    required this.benzin,
    required this.motorin,
    required this.lpg,
    required this.tarih,
    required this.kaynak,
    required this.bolge,
  });

  bool get veriVar => benzin != null || motorin != null || lpg != null;
}

class AkaryakitServisi {
  static const String _petrolOfisiAnaSayfa =
      'https://www.petrolofisi.com.tr/akaryakit-fiyatlari';

  Future<AkaryakitFiyatlari> getir({
    required String il,
    String ilce = '',
  }) async {
    final String temizIl = il.trim();
    final String temizIlce = ilce.trim();

    if (temizIl.isEmpty) {
      throw Exception('İl bilgisi yok');
    }

    final String ilSlug = _slug(temizIl);
    final List<_KaynakAdayi> adaylar = <_KaynakAdayi>[
      _KaynakAdayi(
        '$_petrolOfisiAnaSayfa/$ilSlug-akaryakit-fiyatlari',
        ilceSayfasi: true,
      ),
      const _KaynakAdayi(
        _petrolOfisiAnaSayfa,
        ilceSayfasi: false,
      ),
    ];

    Object? sonHata;

    for (final _KaynakAdayi aday in adaylar) {
      try {
        final String metin = await _sayfayiGetir(aday.url);
        final List<_FiyatSatiri> satirlar = _satirlariCoz(metin);
        if (satirlar.isEmpty) {
          throw Exception('Fiyat tablosu okunamadı');
        }

        final List<_FiyatSatiri> secilenler = aday.ilceSayfasi
            ? _ilceSatirlariniSec(satirlar, temizIlce)
            : _ilSatirlariniSec(satirlar, temizIl);

        if (secilenler.isEmpty) {
          throw Exception('Seçilen bölge bulunamadı');
        }

        final AkaryakitFiyatlari sonuc = AkaryakitFiyatlari(
          benzin: _ortalama(secilenler.map((e) => e.benzin)),
          motorin: _ortalama(secilenler.map((e) => e.motorin)),
          lpg: _ortalama(secilenler.map((e) => e.lpg)),
          tarih: _tarihBul(metin),
          kaynak: 'Petrol Ofisi',
          bolge: secilenler.length == 1
              ? secilenler.first.bolge
              : (temizIlce.isNotEmpty && aday.ilceSayfasi
                  ? temizIlce
                  : temizIl),
        );

        if (sonuc.veriVar) return sonuc;
        throw Exception('Yakıt fiyatı bulunamadı');
      } catch (e) {
        sonHata = e;
      }
    }

    throw Exception('Akaryakıt verisi alınamadı: $sonHata');
  }

  Future<String> _sayfayiGetir(String url) async {
    final List<Uri> adresler = <Uri>[];

    if (kIsWeb) {
      adresler.add(Uri.parse('https://r.jina.ai/$url'));
      adresler.add(Uri.parse(url));
    } else {
      adresler.add(Uri.parse(url));
      adresler.add(Uri.parse('https://r.jina.ai/$url'));
    }

    Object? sonHata;

    for (final Uri uri in adresler) {
      try {
        final http.Response response = await http.get(
          uri,
          headers: const <String, String>{
            'Accept': 'text/html,text/plain,application/xhtml+xml,*/*',
          },
        ).timeout(const Duration(seconds: 18));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final String body = utf8.decode(response.bodyBytes, allowMalformed: true);
        if (body.trim().length < 200) {
          throw Exception('Boş yanıt');
        }
        return body;
      } catch (e) {
        sonHata = e;
      }
    }

    throw Exception('Kaynak okunamadı: $sonHata');
  }

  List<_FiyatSatiri> _satirlariCoz(String metin) {
    final List<_FiyatSatiri> sonuc = <_FiyatSatiri>[];
    final Set<String> tekrar = <String>{};

    void ekle(String bolge, String benzinHucre, String motorinHucre, String lpgHucre) {
      final String temizBolge = _metinTemizle(bolge);
      final double? benzin = _ilkFiyat(benzinHucre);
      final double? motorin = _ilkFiyat(motorinHucre);
      final double? lpg = _ilkFiyat(lpgHucre);

      if (temizBolge.isEmpty || benzin == null || motorin == null) return;
      if (benzin < 20 || motorin < 20) return;

      final String anahtar =
          '${_normalize(temizBolge)}|${benzin.toStringAsFixed(2)}|${motorin.toStringAsFixed(2)}|${lpg?.toStringAsFixed(2) ?? ''}';
      if (!tekrar.add(anahtar)) return;

      sonuc.add(
        _FiyatSatiri(
          bolge: temizBolge,
          benzin: benzin,
          motorin: motorin,
          lpg: lpg,
        ),
      );
    }

    // Petrol Ofisi'nin normal HTML tablosu.
    final RegExp trRegex = RegExp(
      r'<tr[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    );
    final RegExp cellRegex = RegExp(
      r'<t[dh][^>]*>([\s\S]*?)</t[dh]>',
      caseSensitive: false,
    );

    for (final RegExpMatch tr in trRegex.allMatches(metin)) {
      final String blok = tr.group(1) ?? '';
      final List<String> hucreler = cellRegex
          .allMatches(blok)
          .map((m) => _htmlTemizle(m.group(1) ?? ''))
          .toList();
      if (hucreler.length < 4) continue;

      // Şehir/ilçe + benzin + motorin + ... + LPG
      ekle(hucreler.first, hucreler[1], hucreler[2], hucreler.last);
    }

    // Web sürümünde kullandığımız Jina Reader çıktısı Markdown tablo olarak gelir.
    for (final String satir in const LineSplitter().convert(metin)) {
      if (!satir.contains('|')) continue;
      final List<String> hucreler = satir
          .split('|')
          .map((e) => _metinTemizle(e))
          .where((e) => e.isNotEmpty)
          .toList();
      if (hucreler.length < 4) continue;
      ekle(hucreler.first, hucreler[1], hucreler[2], hucreler.last);
    }

    return sonuc;
  }

  List<_FiyatSatiri> _ilceSatirlariniSec(
    List<_FiyatSatiri> satirlar,
    String ilce,
  ) {
    if (ilce.trim().isEmpty) return satirlar;

    final String hedef = _normalize(ilce);

    final List<_FiyatSatiri> tam = satirlar
        .where((s) => _normalize(s.bolge) == hedef)
        .toList();
    if (tam.isNotEmpty) return tam;

    final List<_FiyatSatiri> yakin = satirlar.where((s) {
      final String bolge = _normalize(s.bolge);
      return bolge.contains(hedef) || hedef.contains(bolge);
    }).toList();
    if (yakin.isNotEmpty) return yakin;

    // Bazı illerde "Merkez" yerine birden fazla merkez ilçe listelenir.
    // Eşleşme yoksa il sayfasındaki fiyatların ortalaması kullanılır.
    return satirlar;
  }

  List<_FiyatSatiri> _ilSatirlariniSec(
    List<_FiyatSatiri> satirlar,
    String il,
  ) {
    final String hedef = _normalize(il);
    final List<_FiyatSatiri> secilen = satirlar.where((s) {
      final String bolge = _normalize(s.bolge);
      return bolge == hedef ||
          bolge.startsWith('$hedef ') ||
          bolge.startsWith('$hedef(') ||
          bolge.contains('$hedef anadolu') ||
          bolge.contains('$hedef avrupa');
    }).toList();

    return secilen;
  }

  double? _ortalama(Iterable<double?> degerler) {
    final List<double> dolu = degerler
        .whereType<double>()
        .where((v) => v.isFinite && v > 0)
        .toList();
    if (dolu.isEmpty) return null;
    return dolu.reduce((a, b) => a + b) / dolu.length;
  }

  double? _ilkFiyat(String metin) {
    final String temiz = _htmlTemizle(metin);
    final RegExpMatch? eslesme = RegExp(
      r'([0-9]{1,3}(?:[.,][0-9]{1,3}))',
    ).firstMatch(temiz);
    if (eslesme == null) return null;
    final double? deger = double.tryParse(
      (eslesme.group(1) ?? '').replaceAll(',', '.'),
    );
    if (deger == null || deger < 1 || deger > 200) return null;
    return deger;
  }

  String? _tarihBul(String metin) {
    final RegExpMatch? tarih = RegExp(
      r'\b([0-3]?[0-9][./-][01]?[0-9][./-]20[0-9]{2})\b',
    ).firstMatch(_htmlTemizle(metin));
    return tarih?.group(1);
  }

  String _htmlTemizle(String text) {
    return _metinTemizle(
      text
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&ccedil;', 'ç')
          .replaceAll('&Ccedil;', 'Ç')
          .replaceAll('&ouml;', 'ö')
          .replaceAll('&Ouml;', 'Ö')
          .replaceAll('&uuml;', 'ü')
          .replaceAll('&Uuml;', 'Ü')
          .replaceAll('&scedil;', 'ş')
          .replaceAll('&Scedil;', 'Ş')
          .replaceAll('&#305;', 'ı')
          .replaceAll('&#304;', 'İ')
          .replaceAll('&gbreve;', 'ğ')
          .replaceAll('&Gbreve;', 'Ğ'),
    );
  }

  String _metinTemizle(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

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
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _slug(String text) => _normalize(text).replaceAll(' ', '-');
}

class _KaynakAdayi {
  final String url;
  final bool ilceSayfasi;

  const _KaynakAdayi(this.url, {required this.ilceSayfasi});
}

class _FiyatSatiri {
  final String bolge;
  final double benzin;
  final double motorin;
  final double? lpg;

  const _FiyatSatiri({
    required this.bolge,
    required this.benzin,
    required this.motorin,
    required this.lpg,
  });
}
