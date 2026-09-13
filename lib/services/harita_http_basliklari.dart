import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String _uygulamaKimligi =
    'ENOBET/1.0 (Flutter mobile application)';

/// Tarayıcılar User-Agent başlığını uygulamanın kendisinin ayarlamasına
/// izin vermez. Tarayıcı zaten kendi geçerli kimliğini gönderir; Android ve
/// diğer yerel platformlarda ise Nominatim için uygulama kimliğini ekleriz.
Map<String, String> nominatimBasliklari() {
  return <String, String>{
    'Accept': 'application/json',
    if (!kIsWeb) 'User-Agent': _uygulamaKimligi,
  };
}

Map<String, String> overpassBasliklari() {
  return <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded',
    if (!kIsWeb) 'User-Agent': _uygulamaKimligi,
  };
}

const List<String> _overpassUclari = <String>[
  'https://overpass-api.de/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];

/// Ücretsiz Overpass sunucularında zaman zaman yoğunluk görülebilir. İlk
/// sunucu yanıt vermezse aynı sorguyu ikinci genel kapsama sahip sunucuda
/// deneriz. Başarılı olmayan yanıtlar işlenmeden bir sonraki uca geçilir.
Future<http.Response> overpassSorgusuCalistir(
  String sorgu,
) async {
  Object? sonHata;

  for (final String uc in _overpassUclari) {
    try {
      final http.Response response = await http
          .post(
            Uri.parse(uc),
            headers: overpassBasliklari(),
            body: <String, String>{
              'data': sorgu,
            },
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        return response;
      }

      sonHata = 'Sunucu kodu: ${response.statusCode}';
    } catch (hata) {
      sonHata = hata;
    }
  }

  throw Exception(
    'Ücretsiz işletme veri sunucularına ulaşılamadı: $sonHata',
  );
}
