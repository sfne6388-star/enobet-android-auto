import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BildirimServisi {
  BildirimServisi._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static const String _bildirimAyariKey = 'bildirimler_acik';
  static const String _eczaneTopic = 'eczane_notifications';

  // Bildirime dokunularak uygulama açıldığında bu değer true olur.
  static final ValueNotifier<bool> eczaneBildirimIleAcildi =
      ValueNotifier<bool>(false);

  static Future<void> baslat() async {
    await _tokeniHazirla();
    await _kayitliBildirimAyariniUygula();
    await _ilkBildirimKontrolu();
    _dinleyicileriHazirla();
  }

  static Future<void> _tokeniHazirla() async {
    try {
      final token = await _messaging.getToken();

      if (kDebugMode) {
        debugPrint('ENOBET FCM TOKEN: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM token alınamadı: $e');
      }
    }
  }

  static Future<void> _kayitliBildirimAyariniUygula() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bildirimlerAcik =
          prefs.getBool(_bildirimAyariKey) ?? false;

      if (bildirimlerAcik) {
        await _messaging.subscribeToTopic(_eczaneTopic);

        if (kDebugMode) {
          debugPrint(
            'ENOBET: Eczane bildirim konusu yeniden etkinleştirildi.',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ENOBET: Kayıtlı bildirim ayarı uygulanamadı: $e',
        );
      }
    }
  }

  static Future<void> _ilkBildirimKontrolu() async {
    try {
      final RemoteMessage? message =
          await _messaging.getInitialMessage();

      if (message == null) {
        return;
      }

      _bildirimVerisiniKontrolEt(message);

      if (kDebugMode) {
        debugPrint(
          'ENOBET: Uygulama bildirim üzerinden başlatıldı.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ENOBET: İlk bildirim kontrolü başarısız: $e',
        );
      }
    }
  }

  static Future<bool> bildirimleriAc() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus ==
          AuthorizationStatus.denied) {
        return false;
      }

      await _messaging.subscribeToTopic(_eczaneTopic);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _bildirimAyariKey,
        true,
      );

      if (kDebugMode) {
        debugPrint(
          'ENOBET: Eczane bildirimleri açıldı.',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ENOBET: Bildirimler açılamadı: $e',
        );
      }

      return false;
    }
  }

  static Future<void> bildirimleriKapat() async {
    try {
      await _messaging.unsubscribeFromTopic(_eczaneTopic);

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _bildirimAyariKey,
        false,
      );

      if (kDebugMode) {
        debugPrint(
          'ENOBET: Eczane bildirimleri kapatıldı.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'ENOBET: Bildirimler kapatılamadı: $e',
        );
      }
    }
  }

  static Future<bool> bildirimlerAcikMi() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(
          _bildirimAyariKey,
        ) ??
        false;
  }

  static void _dinleyicileriHazirla() {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        if (kDebugMode) {
          debugPrint(
            'ENOBET bildirim aldı: '
            '${message.notification?.title}',
          );
        }
      },
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        _bildirimVerisiniKontrolEt(message);

        if (kDebugMode) {
          debugPrint(
            'ENOBET bildirime dokunuldu: '
            '${message.notification?.title}',
          );
        }
      },
    );
  }

  static void _bildirimVerisiniKontrolEt(
    RemoteMessage message,
  ) {
    final data = message.data;

    final bildirimTuru =
        data['type']?.toString().toLowerCase();

    if (bildirimTuru == 'eczane' ||
        bildirimTuru == 'eczane_notifications' ||
        bildirimTuru == 'nobetci_eczane') {
      eczaneBildirimIleAcildi.value = true;

      if (kDebugMode) {
        debugPrint(
          'ENOBET: Nöbetçi eczane bildirimi algılandı.',
        );
      }

      return;
    }

    // Bildirim data alanında type bulunmasa bile,
    // kullandığımız eczane topic'inden gelen bildirimleri
    // nöbetçi eczane bildirimi olarak kabul ediyoruz.
    eczaneBildirimIleAcildi.value = true;

    if (kDebugMode) {
      debugPrint(
        'ENOBET: Bildirim eczane bildirimi olarak işaretlendi.',
      );
    }
  }

  static void bildirimiTuket() {
    eczaneBildirimIleAcildi.value = false;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (kDebugMode) {
    debugPrint(
      'ENOBET arka planda bildirim aldı: '
      '${message.notification?.title}',
    );
  }
}