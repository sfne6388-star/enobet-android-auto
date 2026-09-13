import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enobet/services/hizli_yerel_hizmet_servisi.dart';
import 'package:enobet/services/telefon_bilgisi.dart';
import 'package:enobet/screens/hizmet_detay.dart';

class MemoryCatalog extends CachingAssetBundle {
  final List<Map<String, dynamic>> records;
  int reads = 0;
  MemoryCatalog(this.records);
  @override
  Future<ByteData> load(String key) async {
    reads++;
    if (key != 'assets/data/turkiye_hizmetleri.json') throw StateError(key);
    return ByteData.sublistView(
      Uint8List.fromList(
        utf8.encode(jsonEncode({'version': 1, 'records': records})),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final elements = <Map<String, dynamic>>[
    {
      'type': 'node',
      'id': 1,
      'lat': 41.67,
      'lon': 26.55,
      'tags': {
        'amenity': 'taxi',
        'name': 'Örnek Taksi',
        'phone': '',
        'contact:phone': '+90 284 123 45 67',
      },
    },
    {
      'type': 'node',
      'id': 2,
      'lat': 41.68,
      'lon': 26.56,
      'tags': {'amenity': 'atm'},
    },
    {
      'type': 'way',
      'id': 3,
      'center': {'lat': 41.69, 'lon': 26.57},
      'tags': {'amenity': 'hospital'},
    },
  ];
  test('Kategori listeleri ilk açılışta paket verisinden gelir; ilçe dışına çıkmaz', () async {
    final source = MemoryCatalog([
      for (final e in elements)
        {
          ...e,
          'il': 'Edirne',
          'ilce': 'Merkez',
          'categories': [
            e['id'] == 1
                ? 'Taksi'
                : e['id'] == 2
                ? 'ATM'
                : 'Hastane',
          ],
        },
      {
        ...elements[0],
        'id': 99,
        'il': 'İstanbul',
        'ilce': 'Kadıköy',
        'categories': ['Taksi'],
      },
    ]);
    final service = YerelHizmetServisi(bundle: source);
    final results = await Future.wait(
      [
        'Taksi',
        'ATM',
        'Hastane',
      ].map((c) => service.getir(kategori: c, il: 'Edirne', ilce: 'Merkez')),
    );
    expect(results.every((r) => r.length == 1), isTrue);
    expect(source.reads, 1);
    expect(results.first.single.telefon, '+90 284 123 45 67');
    expect(
      (await service.getir(
        kategori: 'Taksi',
        il: 'İstanbul',
        ilce: 'Kadıköy',
      )).single.id,
      'osm_node_99',
    );
    expect(
      await service.getir(kategori: 'Taksi', il: 'Edirne', ilce: 'Keşan'),
      isEmpty,
    );
    expect((await service.tumu()).length, 4);
    expect(source.reads, 1);
  });
  test(
    'Koordinatsız kayıt listelenmez; merkez koordinatı ve telefon korunur',
    () {
      final records = YerelHizmetServisi.kayitlariOku(
        elements,
        kategori: 'Hastane',
        il: 'Edirne',
        ilce: 'Merkez',
      );
      expect(records.single.enlem, 41.69);
      expect(
        YerelHizmetServisi.kayitlariOku(
          [
            {
              'id': 5,
              'tags': {'amenity': 'atm'},
            },
          ],
          kategori: 'ATM',
          il: 'Edirne',
          ilce: 'Merkez',
        ),
        isEmpty,
      );
    },
  );
  test('Telefon numarası yokken başka numara üretilmez, birden fazla numara birleştirilmez', () {
    expect(aranacakTelefon('Bilgi yok'), isNull);
    expect(
      aranacakTelefon('+90 (284) 123 45 67; +90 284 765 43 21'),
      '+902841234567',
    );
    expect(aranacakTelefon('284 123 45 67'), '02841234567');
    expect(
      kayittanTelefon({'phone': '', 'contact:mobile': '0532 123 45 67'}),
      '0532 123 45 67',
    );
  });
  testWidgets('Taksi detayında ÇAĞIR ve Telefon birlikte görünür', (
    tester,
  ) async {
    final h = YerelHizmetServisi.kayitlariOku(
      elements,
      kategori: 'Taksi',
      il: 'Edirne',
      ilce: 'Merkez',
    ).single;
    await tester.pumpWidget(MaterialApp(home: HizmetDetay(hizmet: h)));
    await tester.pumpAndSettle();
    expect(find.text('ÇAĞIR'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('+90 284 123 45 67'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('ÇAĞIR'),
              matching: find.byType(ElevatedButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
