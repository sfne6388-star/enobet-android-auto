import 'package:flutter_test/flutter_test.dart';
import 'package:enobet/services/hizli_yerel_hizmet_servisi.dart';
import 'package:enobet/services/hizmet_siralama.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Gerçek paket 81 ili içerir; kategori sadece seçilen ilçeyi döndürür', () async {
    final service = YerelHizmetServisi();
    final all = await service.tumu();
    expect(all.map((h) => h.il).toSet().length, 81);
    expect(all.length, greaterThan(1000));
    for (final category in ['Hastane', 'ATM', 'Taksi', 'Veteriner', 'Benzin', 'Elektrikli Şarj İstasyonu', 'Kargo', 'Otogar', 'Çekici', 'Oto Lastik', 'Çilingir']) {
      expect(all.any((h) => h.kategori == category), isTrue, reason: category);
    }
    final watch = Stopwatch()..start();
    for (final category in ['Hastane', 'ATM', 'Taksi', 'Veteriner', 'Benzin', 'Kargo', 'Otogar', 'Oto Lastik', 'Çilingir']) {
      final local = await service.getir(kategori: category, il: 'Edirne', ilce: 'Merkez');
      expect(local.every((h) => h.il == 'Edirne' && h.ilce == 'Merkez' && h.kategori == category), isTrue);
      expect(local.length, all.where((h) => h.il == 'Edirne' && h.ilce == 'Merkez' && h.kategori == category).length);
    }
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(1500));
    expect(all.where((h) => hizmetEslesir(h, 'istanbul')).isNotEmpty, isTrue);
    expect(await service.bolgeMerkezi('Edirne', 'Merkez'), isNotNull);
  });
}
