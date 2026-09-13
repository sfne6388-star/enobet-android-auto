import 'package:geolocator/geolocator.dart';

import '../models/hizmet.dart';

String aramaMetni(String value) => value
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('i̇', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .trim();

String _kategoriAnahtarKelimeleri(String kategori) {
  switch (kategori) {
    case 'Eczane':
    case 'Nöbetçi Eczane':
      return 'eczane eczaneler nöbetçi nöbetçi eczane pharmacy';
    case 'Hastane':
      return 'hastane hastaneler sağlık acil hospital';
    case 'ATM':
      return 'atm banka bankamatik para çekme';
    case 'Taksi':
      return 'taksi taksi durağı taksi duragi taxi';
    case 'Veteriner':
      return 'veteriner veterinerler hayvan pet veterinary';
    case 'Benzin':
      return 'benzin benzinlik akaryakıt akaryakit yakıt yakit petrol fuel';
    case 'Elektrikli Şarj İstasyonu':
      return 'şarj sarj elektrikli araç elektrikli arac şarj istasyonu charging ev';
    case 'Kargo':
      return 'kargo kurye posta cargo courier';
    case 'Otogar':
      return 'otogar terminal otobüs terminali bus station';
    case 'Çekici':
      return 'çekici cekici yol yardım yol yardim oto kurtarma towing';
    case 'Oto Lastik':
      return 'lastik lastikçi lastikci oto lastik tyre tire';
    case 'Çilingir':
      return 'çilingir cilingir anahtarcı anahtarci locksmith';
    default:
      return '';
  }
}

bool hizmetEslesir(Hizmet h, String query) {
  final String text = aramaMetni(
    '${h.isim} ${h.kategori} ${_kategoriAnahtarKelimeleri(h.kategori)} '
    '${h.adres} ${h.il} ${h.ilce} ${h.telefon}',
  );
  final List<String> kelimeler = aramaMetni(query)
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  return kelimeler.every(text.contains);
}

List<Hizmet> mesafeyeGoreSirala(Iterable<Hizmet> source, Position? position) {
  double distance(Hizmet h) {
    if (position == null ||
        !h.enlem.isFinite ||
        !h.boylam.isFinite ||
        h.enlem == 0 ||
        h.boylam == 0 ||
        h.enlem.abs() > 90 ||
        h.boylam.abs() > 180) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      h.enlem,
      h.boylam,
    );
  }

  final entries = source.map((h) => (h, distance(h))).toList();
  entries.sort((a, b) {
    final comparison = a.$2.compareTo(b.$2);
    return comparison != 0 ? comparison : a.$1.id.compareTo(b.$1.id);
  });
  return entries
      .map(
        (entry) => entry.$1.copyWith(
          mesafe: !entry.$2.isFinite
              ? 'Mesafe bilinmiyor'
              : entry.$2 < 1000
              ? '${entry.$2.round()} m'
              : '${(entry.$2 / 1000).toStringAsFixed(1)} km',
        ),
      )
      .toList();
}
