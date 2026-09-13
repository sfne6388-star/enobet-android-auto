import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hizmet.dart';

class FavoriServisi {
  static const String _favorilerAnahtari = 'favoriler';

  Future<List<Hizmet>> favorileriGetir() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> kayitlar =
        prefs.getStringList(_favorilerAnahtari) ?? [];

    final List<Hizmet> favoriler = [];

    for (final kayit in kayitlar) {
      try {
        final Map<String, dynamic> veri =
            jsonDecode(kayit) as Map<String, dynamic>;

        if (veri['kategori'] == 'Benzin') continue;

        favoriler.add(
          _hizmetOlustur(veri),
        );
      } catch (_) {
        // Bozuk favori kaydı varsa diğer favorilere devam edilir.
      }
    }

    return favoriler;
  }

  Future<bool> favoriMi(String hizmetId) async {
    final List<Hizmet> favoriler =
        await favorileriGetir();

    return favoriler.any(
      (hizmet) => hizmet.id == hizmetId,
    );
  }

  Future<void> favoriyeEkle(Hizmet hizmet) async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> kayitlar =
        prefs.getStringList(_favorilerAnahtari) ?? [];

    final bool zatenVar = kayitlar.any((kayit) {
      try {
        final Map<String, dynamic> veri =
            jsonDecode(kayit) as Map<String, dynamic>;

        return veri['id']?.toString() == hizmet.id;
      } catch (_) {
        return false;
      }
    });

    if (zatenVar) {
      return;
    }

    final Map<String, dynamic> veri = {
      'id': hizmet.id,
      'isim': hizmet.isim,
      'kategori': hizmet.kategori,
      'adres': hizmet.adres,
      'telefon': hizmet.telefon,
      'durum': hizmet.durum,
      'mesafe': hizmet.mesafe,
      'calismaSaatleri': hizmet.calismaSaatleri,
      'enlem': hizmet.enlem,
      'boylam': hizmet.boylam,
      'il': hizmet.il,
      'ilce': hizmet.ilce,
    };

    kayitlar.add(
      jsonEncode(veri),
    );

    await prefs.setStringList(
      _favorilerAnahtari,
      kayitlar,
    );
  }

  Future<void> favoridenCikar(String hizmetId) async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> kayitlar =
        prefs.getStringList(_favorilerAnahtari) ?? [];

    kayitlar.removeWhere((kayit) {
      try {
        final Map<String, dynamic> veri =
            jsonDecode(kayit) as Map<String, dynamic>;

        return veri['id']?.toString() == hizmetId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(
      _favorilerAnahtari,
      kayitlar,
    );
  }

  Future<void> favoriDegistir(Hizmet hizmet) async {
    final bool favori = await favoriMi(hizmet.id);

    if (favori) {
      await favoridenCikar(hizmet.id);
    } else {
      await favoriyeEkle(hizmet);
    }
  }

  Hizmet _hizmetOlustur(
    Map<String, dynamic> veri,
  ) {
    final String kategori =
        veri['kategori']?.toString() ?? 'Hizmet';

    final _KategoriGorunum gorunum =
        _kategoriGorunumuGetir(kategori);

    return Hizmet(
      id: veri['id']?.toString() ?? '',
      isim: veri['isim']?.toString() ?? 'İsimsiz Hizmet',
      kategori: kategori,
      adres: veri['adres']?.toString() ?? 'Adres bilgisi yok',
      telefon: veri['telefon']?.toString() ?? 'Bilgi yok',
      durum: veri['durum']?.toString() ?? 'Bilgi yok',
      mesafe: veri['mesafe']?.toString() ?? '0',
      calismaSaatleri:
          veri['calismaSaatleri']?.toString() ?? 'Bilgi yok',
      ikon: gorunum.ikon,
      renk: gorunum.renk,
      enlem: _doubleGetir(veri['enlem']),
      boylam: _doubleGetir(veri['boylam']),
      il: veri['il']?.toString() ?? '',
      ilce: veri['ilce']?.toString() ?? '',
    );
  }

  double _doubleGetir(dynamic deger) {
    if (deger is num) {
      return deger.toDouble();
    }

    return double.tryParse(
          deger?.toString() ?? '',
        ) ??
        0;
  }

  _KategoriGorunum _kategoriGorunumuGetir(
    String kategori,
  ) {
    switch (kategori) {
      case 'Eczane':
      case 'Nöbetçi Eczane':
        return const _KategoriGorunum(
          ikon: Icons.local_pharmacy_rounded,
          renk: Color(0xFFE3262E),
        );


      case 'Hastane':
        return const _KategoriGorunum(
          ikon: Icons.local_hospital_rounded,
          renk: Color(0xFF3185E8),
        );

      case 'ATM':
        return const _KategoriGorunum(
          ikon: Icons.local_atm_rounded,
          renk: Color(0xFF7A5AF8),
        );

      case 'Taksi':
        return const _KategoriGorunum(
          ikon: Icons.local_taxi_rounded,
          renk: Color(0xFFFFB020),
        );

      case 'Benzin':
        return const _KategoriGorunum(
          ikon: Icons.local_gas_station_rounded,
          renk: Color(0xFFFF8A00),
        );

      case 'Kargo':
        return const _KategoriGorunum(
          ikon: Icons.local_shipping_rounded,
          renk: Color(0xFF8E6CEF),
        );

      case 'Otogar':
        return const _KategoriGorunum(
          ikon: Icons.directions_bus_rounded,
          renk: Color(0xFF3A86FF),
        );

      case 'Veteriner':
        return const _KategoriGorunum(
          ikon: Icons.pets_rounded,
          renk: Color(0xFF20C978),
        );

      case 'Çekici':
        return const _KategoriGorunum(
          ikon: Icons.car_repair_rounded,
          renk: Color(0xFFFFB020),
        );

      case 'Elektrikli Şarj İstasyonu':
        return const _KategoriGorunum(
          ikon: Icons.ev_station_rounded,
          renk: Color(0xFF20D9C2),
        );

      case 'Oto Lastik':
        return const _KategoriGorunum(
          ikon: Icons.tire_repair_rounded,
          renk: Color(0xFFFFB020),
        );

      case 'Çilingir':
        return const _KategoriGorunum(
          ikon: Icons.key_rounded,
          renk: Color(0xFFA970FF),
        );

      default:
        return const _KategoriGorunum(
          ikon: Icons.store_rounded,
          renk: Color(0xFFE3262E),
        );
    }
  }
}

class _KategoriGorunum {
  final IconData ikon;
  final Color renk;

  const _KategoriGorunum({
    required this.ikon,
    required this.renk,
  });
}
