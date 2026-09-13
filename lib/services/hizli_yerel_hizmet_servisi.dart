import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hizmet.dart';
import 'hizmet_siralama.dart';
import 'telefon_bilgisi.dart';

/// Uygulama ile gelen gerçek kayıtlar.
/// Manuel il/ilçe seçiminde bölge kayıtlarını kullanır.
/// GPS modunda ise idari sınır gözetmeden kullanıcının çevresindeki
/// kayıtları gerçek koordinat mesafesine göre getirir.
class YerelHizmetServisi {
  static final YerelHizmetServisi ortak = YerelHizmetServisi();

  final AssetBundle? bundle;

  Future<void>? _pending;

  final Map<String, Map<String, List<Hizmet>>> _bolgeler = {};

  List<Hizmet>? _tumKayitlar;

  final Map<String, (double, double)> _merkezler = {};

  YerelHizmetServisi({this.bundle});

  void dispose() {}

  /// Yakın iller, katalog kayıtlarından yaklaşık olarak belirlenir.
  /// Ek pay yalnızca API adayları içindir; eczanelerde kesin yarıçap uygulanır.
  Future<List<String>> yakinIlleriGetir({
    required Position konum,
    double yaricapKm = 30,
  }) async {
    final all = await tumu();
    final iller = <String>{};
    double nearest = double.infinity;
    String nearestIl = '';
    for (final h in all) {
      final distance = Geolocator.distanceBetween(
        konum.latitude,
        konum.longitude,
        h.enlem,
        h.boylam,
      );
      if (distance < nearest) {
        nearest = distance;
        nearestIl = h.il;
      }
      if (distance <= (yaricapKm + 30) * 1000 && h.il.isNotEmpty) {
        iller.add(h.il);
      }
    }
    if (iller.isEmpty && nearestIl.isNotEmpty && nearest <= 150000) {
      iller.add(nearestIl);
    }
    return iller.toList()..sort();
  }

  Future<void> _hazirla() async {
    if (_tumKayitlar != null) return;

    final pending = _pending ??= _oku();

    try {
      await pending;
    } finally {
      if (identical(_pending, pending)) {
        _pending = null;
      }
    }
  }

  Future<void> _oku() async {
    final text = await (bundle ?? rootBundle).loadString(
      'assets/data/turkiye_hizmetleri.json',
    );

    final data = jsonDecode(text) as Map<String, dynamic>;

    if (data['version'] != 1 || data['records'] is! List) {
      throw const FormatException('İşletme veri paketi okunamadı.');
    }

    for (final center in data['centers'] as List? ?? []) {
      _merkezler['${aramaMetni(center['il'] as String)}|'
          '${aramaMetni(center['ilce'] as String)}'] = (
        (center['lat'] as num).toDouble(),
        (center['lon'] as num).toDouble(),
      );
    }

    final all = <Hizmet>[];

    final regions = <String, Map<String, List<Hizmet>>>{};

    for (final raw in data['records'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);

      final il = row['il'] as String;
      final ilce = row['ilce'] as String;

      final key = '${aramaMetni(il)}|${aramaMetni(ilce)}';

      for (final c in row['categories'] as List) {
        final kategori = c as String;

        final records = kayitlariOku(
          [row],
          kategori: kategori,
          il: il,
          ilce: ilce,
        );

        all.addAll(records);

        regions
            .putIfAbsent(key, () => {})
            .putIfAbsent(kategori, () => [])
            .addAll(records);
      }
    }

    _bolgeler
      ..clear()
      ..addAll(regions);

    _tumKayitlar = List.unmodifiable(all);
  }

  /// MANUEL İL / İLÇE MODU
  ///
  /// Kullanıcı kendisi il ve ilçe seçtiğinde mevcut davranış korunur.
  /// Yalnızca seçilen il ve ilçedeki kayıtlar döndürülür.
  Future<List<Hizmet>> getir({
    required String kategori,
    required String il,
    required String ilce,
  }) async {
    if (bundle == null && !identical(this, ortak)) {
      return ortak.getir(kategori: kategori, il: il, ilce: ilce);
    }

    await _hazirla();

    final key = '${aramaMetni(il)}|${aramaMetni(ilce)}';

    return List.of(_bolgeler[key]?[kategori] ?? const <Hizmet>[]);
  }

  /// GPS MODU
  ///
  /// Kullanıcının gerçek konumunu merkez kabul eder.
  ///
  /// İl ve ilçe sınırı uygulanmaz.
  ///
  /// Örneğin kullanıcı bir ilçe sınırında bulunuyorsa diğer ilçedeki,
  /// hatta başka bir ildeki işletme 30 km içerisindeyse sonuçlara dahil
  /// edilir.
  ///
  /// Sonuçlar gerçek mesafeye göre en yakından en uzağa sıralanır.
  Future<List<Hizmet>> yakindakileriGetir({
    required String kategori,
    required Position konum,
    double yaricapKm = 30,
  }) async {
    if (bundle == null && !identical(this, ortak)) {
      return ortak.yakindakileriGetir(
        kategori: kategori,
        konum: konum,
        yaricapKm: yaricapKm,
      );
    }

    await _hazirla();

    final double maksimumMesafeMetre = yaricapKm * 1000;

    /*
     * Önce yaklaşık koordinat kutusu kullanıyoruz.
     *
     * Böylece Türkiye'deki bütün kayıtlar için pahalı mesafe hesabı
     * yapmak yerine yalnızca kullanıcının yakınındaki aday kayıtları
     * ayrıntılı olarak kontrol ediyoruz.
     *
     * 1 enlem derecesi yaklaşık 111 km'dir.
     */
    final double enlemFarki = yaricapKm / 110.0;

    /*
     * Türkiye enlemlerinde 1 boylam derecesi yaklaşık 85 km civarındadır.
     * Güvenli tarafta kalmak için daha geniş bir kutu kullanıyoruz.
     *
     * Bu kutu sadece ön elemedir. Son karar aşağıdaki
     * Geolocator.distanceBetween hesabıyla verilir.
     */
    final double boylamFarki = yaricapKm / 75.0;

    final double minEnlem = konum.latitude - enlemFarki;
    final double maxEnlem = konum.latitude + enlemFarki;

    final double minBoylam = konum.longitude - boylamFarki;
    final double maxBoylam = konum.longitude + boylamFarki;

    final List<(Hizmet, double)> bulunanlar = [];

    for (final hizmet in _tumKayitlar!) {
      if (hizmet.kategori != kategori) {
        continue;
      }

      if (!hizmet.enlem.isFinite ||
          !hizmet.boylam.isFinite ||
          hizmet.enlem == 0 ||
          hizmet.boylam == 0 ||
          hizmet.enlem.abs() > 90 ||
          hizmet.boylam.abs() > 180) {
        continue;
      }

      /*
       * Önce hızlı koordinat kutusu kontrolü.
       */
      if (hizmet.enlem < minEnlem ||
          hizmet.enlem > maxEnlem ||
          hizmet.boylam < minBoylam ||
          hizmet.boylam > maxBoylam) {
        continue;
      }

      /*
       * Ardından gerçek kuş uçuşu mesafe hesabı.
       */
      final double mesafeMetre = Geolocator.distanceBetween(
        konum.latitude,
        konum.longitude,
        hizmet.enlem,
        hizmet.boylam,
      );

      /*
       * Yalnızca 30 km yarıçap içerisindeki kayıtlar.
       */
      if (mesafeMetre <= maksimumMesafeMetre) {
        bulunanlar.add((hizmet, mesafeMetre));
      }
    }

    /*
     * Gerçek mesafeye göre en yakın -> en uzak.
     */
    bulunanlar.sort((a, b) {
      final int mesafeKarsilastirma = a.$2.compareTo(b.$2);

      if (mesafeKarsilastirma != 0) {
        return mesafeKarsilastirma;
      }

      return a.$1.id.compareTo(b.$1.id);
    });

    /*
     * Kartlarda gösterilecek mesafe bilgisini de burada hazırlıyoruz.
     */
    return bulunanlar.map((kayit) {
      final Hizmet hizmet = kayit.$1;
      final double mesafeMetre = kayit.$2;

      final String mesafeYazisi = mesafeMetre < 1000
          ? '${mesafeMetre.round()} m'
          : '${(mesafeMetre / 1000).toStringAsFixed(1)} km';

      return hizmet.copyWith(mesafe: mesafeYazisi);
    }).toList();
  }

  /// GPS konumuna göre kategori ayrımı yapmadan 30 km içerisindeki
  /// bütün yerel hizmetleri getirir.
  ///
  /// Harita ve "Yakınınızdaki Hizmetler" gibi alanlarda kullanılabilir.
  Future<List<Hizmet>> yakindakiTumHizmetleriGetir({
    required Position konum,
    double yaricapKm = 30,
  }) async {
    if (bundle == null && !identical(this, ortak)) {
      return ortak.yakindakiTumHizmetleriGetir(
        konum: konum,
        yaricapKm: yaricapKm,
      );
    }

    await _hazirla();

    final double maksimumMesafeMetre = yaricapKm * 1000;

    final double enlemFarki = yaricapKm / 110.0;
    final double boylamFarki = yaricapKm / 75.0;

    final double minEnlem = konum.latitude - enlemFarki;
    final double maxEnlem = konum.latitude + enlemFarki;

    final double minBoylam = konum.longitude - boylamFarki;
    final double maxBoylam = konum.longitude + boylamFarki;

    final List<(Hizmet, double)> bulunanlar = [];

    for (final hizmet in _tumKayitlar!) {
      if (!hizmet.enlem.isFinite ||
          !hizmet.boylam.isFinite ||
          hizmet.enlem == 0 ||
          hizmet.boylam == 0 ||
          hizmet.enlem.abs() > 90 ||
          hizmet.boylam.abs() > 180) {
        continue;
      }

      if (hizmet.enlem < minEnlem ||
          hizmet.enlem > maxEnlem ||
          hizmet.boylam < minBoylam ||
          hizmet.boylam > maxBoylam) {
        continue;
      }

      final double mesafeMetre = Geolocator.distanceBetween(
        konum.latitude,
        konum.longitude,
        hizmet.enlem,
        hizmet.boylam,
      );

      if (mesafeMetre <= maksimumMesafeMetre) {
        bulunanlar.add((hizmet, mesafeMetre));
      }
    }

    bulunanlar.sort((a, b) {
      final int mesafeKarsilastirma = a.$2.compareTo(b.$2);

      if (mesafeKarsilastirma != 0) {
        return mesafeKarsilastirma;
      }

      return a.$1.id.compareTo(b.$1.id);
    });

    return bulunanlar.map((kayit) {
      final Hizmet hizmet = kayit.$1;
      final double mesafeMetre = kayit.$2;

      return hizmet.copyWith(
        mesafe: mesafeMetre < 1000
            ? '${mesafeMetre.round()} m'
            : '${(mesafeMetre / 1000).toStringAsFixed(1)} km',
      );
    }).toList();
  }

  Future<(double, double)?> bolgeMerkezi(String il, String ilce) async {
    if (bundle == null && !identical(this, ortak)) {
      return ortak.bolgeMerkezi(il, ilce);
    }

    await _hazirla();

    return _merkezler['${aramaMetni(il)}|${aramaMetni(ilce)}'];
  }

  Future<List<Hizmet>> tumu() async {
    if (bundle == null && !identical(this, ortak)) {
      return ortak.tumu();
    }

    await _hazirla();

    return _tumKayitlar!;
  }

  static bool _eslesir(Map<String, dynamic> t, String category) {
    final name = aramaMetni('${t['name'] ?? ''}');

    bool tagged(String key) {
      return t[key] != null && t[key] != 'no';
    }

    return switch (category) {
      'Hastane' => t['amenity'] == 'hospital' || t['healthcare'] == 'hospital',

      'ATM' =>
        t['amenity'] == 'atm' || (t['amenity'] == 'bank' && t['atm'] == 'yes'),

      'Taksi' => t['amenity'] == 'taxi' || RegExp('taksi|taxi').hasMatch(name),

      'Veteriner' =>
        t['amenity'] == 'veterinary' ||
            t['healthcare'] == 'veterinary' ||
            RegExp('veteriner|veterinary').hasMatch(name),

      'Benzin' => t['amenity'] == 'fuel',

      'Elektrikli Şarj İstasyonu' => t['amenity'] == 'charging_station',

      'Kargo' =>
        t['amenity'] == 'post_office' ||
            t['office'] == 'courier' ||
            t['shop'] == 'courier' ||
            name.contains('kargo'),

      'Otogar' =>
        t['amenity'] == 'bus_station' ||
            (t['public_transport'] == 'station' && t['bus'] == 'yes') ||
            RegExp('otogar|otobus terminali').hasMatch(name),

      'Havaalanı' =>
        t['aeroway'] == 'aerodrome' ||
            RegExp('havalimani|havaalani|airport').hasMatch(name),

      'Çekici' =>
        t['emergency'] == 'vehicle_recovery' ||
            tagged('service:vehicle:towing') ||
            tagged('service:towing') ||
            tagged('towing') ||
            RegExp('cekici|oto kurtarma|yol yardim|towing').hasMatch(name),

      'Oto Lastik' =>
        t['shop'] == 'tyres' ||
            tagged('service:vehicle:tyres') ||
            name.contains('lastik'),

      'Çilingir' =>
        ['locksmith', 'key_cutter'].contains(t['shop']) ||
            ['locksmith', 'key_cutter'].contains(t['craft']) ||
            RegExp('cilingir|anahtar|locksmith').hasMatch(name),

      _ => false,
    };
  }

  static List<Hizmet> kayitlariOku(
    List<Map<String, dynamic>> elements, {
    required String kategori,
    required String il,
    required String ilce,
  }) {
    final result = <String, Hizmet>{};

    for (final e in elements) {
      final tags = Map<String, dynamic>.from(e['tags'] as Map? ?? {});

      if (e['categories'] is List
          ? !(e['categories'] as List).contains(kategori)
          : !_eslesir(tags, kategori)) {
        continue;
      }

      final center = Map<String, dynamic>.from(e['center'] as Map? ?? {});

      final lat = ((e['lat'] ?? center['lat']) as num?)?.toDouble();
      final lon = ((e['lon'] ?? center['lon']) as num?)?.toDouble();

      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat.abs() > 90 ||
          lon.abs() > 180 ||
          (lat == 0 && lon == 0)) {
        continue;
      }

      final id = 'osm_${e['type']}_${e['id']}';

      final name =
          '${tags['name'] ?? tags['brand'] ?? tags['operator'] ?? kategori}';

      final address = [
        tags['addr:street'],
        tags['addr:housenumber'],
        tags['addr:neighbourhood'],
        ilce,
        il,
      ].where((x) => x != null && '$x'.trim().isNotEmpty).join(' ');

      result[id] = Hizmet(
        id: id,
        isim: name,
        kategori: kategori,
        adres: address,
        telefon: kayittanTelefon(tags),
        durum: kategori == 'Eczane'
            ? 'Nöbet bilgisi doğrulanmadı'
            : kategori == 'Havaalanı'
                ? 'Sivil havalimanı kaydı'
                : 'Çalışma durumu bilinmiyor',
        mesafe: 'Mesafe bilinmiyor',
        calismaSaatleri: kategori == 'Havaalanı'
            ? 'Uçuş operasyon saatleri değişebilir'
            : '${tags['opening_hours'] ?? 'Çalışma saati bilinmiyor'}',
        ikon: ikon(kategori),
        renk: renk(kategori),
        enlem: lat,
        boylam: lon,
        il: il,
        ilce: ilce,
      );
    }

    return result.values.toList();
  }

  static IconData ikon(String category) => switch (category) {
    'Eczane' => Icons.local_pharmacy_rounded,
    'Hastane' => Icons.local_hospital_rounded,
    'ATM' => Icons.local_atm_rounded,
    'Taksi' => Icons.local_taxi_rounded,
    'Veteriner' => Icons.pets_rounded,
    'Benzin' => Icons.local_gas_station_rounded,
    'Elektrikli Şarj İstasyonu' => Icons.ev_station_rounded,
    'Kargo' => Icons.local_shipping_rounded,
    'Otogar' => Icons.directions_bus_rounded,
    'Havaalanı' => Icons.local_airport_rounded,
    'Çekici' => Icons.car_repair_rounded,
    'Oto Lastik' => Icons.tire_repair_rounded,
    'Çilingir' => Icons.key_rounded,
    _ => Icons.place_rounded,
  };

  static Color renk(String category) => switch (category) {
    'Hastane' => const Color(0xFF2F80ED),
    'ATM' => const Color(0xFF7A5AF8),
    'Taksi' => const Color(0xFFFFB020),
    'Veteriner' => const Color(0xFF20B879),
    'Benzin' => const Color(0xFFFF8A00),
    'Elektrikli Şarj İstasyonu' => const Color(0xFFFF8A00),
    'Kargo' => const Color(0xFF8E6CEF),
    'Otogar' => const Color(0xFF3A86FF),
    'Havaalanı' => const Color(0xFF42A5F5),
    'Çekici' => const Color(0xFFEF7295),
    'Oto Lastik' => const Color(0xFF20C9A0),
    'Çilingir' => const Color(0xFFAC85FF),
    _ => const Color(0xFF3185E8),
  };
}
