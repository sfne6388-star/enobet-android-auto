import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:enobet/models/hizmet.dart';
import 'package:enobet/services/hizmet_siralama.dart';
import 'package:enobet/services/hizli_yerel_hizmet_servisi.dart';

Hizmet sample(
  String id,
  double lat,
  double lon, {
  String name = 'Ufuk Eczanesi',
  String city = 'İstanbul',
}) => Hizmet(
  id: id,
  isim: name,
  kategori: 'Eczane',
  adres: city,
  telefon: '',
  durum: '',
  mesafe: '1 m',
  calismaSaatleri: '',
  ikon: Icons.local_pharmacy,
  renk: Colors.red,
  enlem: lat,
  boylam: lon,
  il: city,
  ilce: 'Merkez',
);
Position position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  test('Türkiye araması şehirden bağımsız ve Türkçe harflere duyarsızdır', () {
    final data = [
      sample('1', 41, 29),
      sample('2', 39, 32, city: 'Ankara'),
      sample('3', 38, 27, name: 'Başka Eczane'),
    ];
    expect(data.where((h) => hizmetEslesir(h, 'UFUK ECZANESI')).length, 2);
    expect(data.where((h) => hizmetEslesir(h, 'ankara ufuk')).single.id, '2');
    expect(hizmetEslesir(data.first, 'istanbul'), isTrue);
  });
  test('Koordinatlar kullanılır; konum değişince sıra değişir', () {
    final data = [
      sample('ankara', 39.93, 32.86),
      sample('istanbul', 41.01, 28.97),
      sample('bilinmiyor', 0, 0),
    ];
    expect(mesafeyeGoreSirala(data, position(41, 29)).map((h) => h.id), [
      'istanbul',
      'ankara',
      'bilinmiyor',
    ]);
    expect(mesafeyeGoreSirala(data, position(39.93, 32.86)).first.id, 'ankara');
    expect(data.first.mesafe, '1 m');
    expect(
      mesafeyeGoreSirala(
        data,
        null,
      ).every((h) => h.mesafe == 'Mesafe bilinmiyor'),
      isTrue,
    );
  });
  test('Yuvarlanmış gösterim sıralamayı etkilemez', () {
    final data = [
      sample('a_uzak', 41.000004, 29),
      sample('z_yakin', 41.000001, 29),
    ];
    expect(mesafeyeGoreSirala(data, position(41, 29)).first.id, 'z_yakin');
  });
  test('Yeni kategori eşlemeleri ve doğrulanmamış nöbet durumu', () {
    for (final entry in {
      'hospital': 'Hastane',
      'atm': 'ATM',
      'taxi': 'Taksi',
      'fuel': 'Benzin',
      'charging_station': 'Elektrikli Şarj İstasyonu',
      'post_office': 'Kargo',
      'bus_station': 'Otogar',
    }.entries) {
      final h = YerelHizmetServisi.kayitlariOku(
        [
          {
            'type': 'way',
            'id': 1,
            'center': {'lat': 41.0, 'lon': 29.0},
            'tags': {'amenity': entry.key},
          },
        ],
        kategori: entry.value,
        il: 'İstanbul',
        ilce: 'Kadıköy',
      ).single;
      expect(h.kategori, entry.value);
      expect(h.enlem, 41);
    }
    final pharmacy = YerelHizmetServisi.kayitlariOku(
      [
        {
          'type': 'node',
          'id': 2,
          'lat': 41.0,
          'lon': 29.0,
          'categories': ['Eczane'],
          'tags': {'amenity': 'pharmacy'},
        },
      ],
      kategori: 'Eczane',
      il: 'İstanbul',
      ilce: 'Kadıköy',
    ).single;
    expect(pharmacy.durum, 'Nöbet bilgisi doğrulanmadı');
  });
}
