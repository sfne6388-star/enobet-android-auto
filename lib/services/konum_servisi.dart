import 'package:geolocator/geolocator.dart';

class KonumServisi {
  Future<Position> mevcutKonumuGetir() async {
    final bool servisAcik =
        await Geolocator.isLocationServiceEnabled();

    if (!servisAcik) {
      throw Exception(
        'Konum servisi kapalı. '
        'Lütfen telefonunuzun GPS konumunu açın.',
      );
    }

    LocationPermission izin =
        await Geolocator.checkPermission();

    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }

    if (izin == LocationPermission.denied) {
      throw Exception(
        'Konum izni verilmedi.',
      );
    }

    if (izin == LocationPermission.deniedForever) {
      throw Exception(
        'Konum izni kalıcı olarak reddedildi. '
        'Lütfen cihaz ayarlarından ENOBET için '
        'konum iznini açın.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(
        const Duration(seconds: 20),
      );
    } catch (e) {
      throw Exception(
        'Telefonun konumu alınamadı. '
        'GPS açık olduğundan ve konum izninin verildiğinden '
        'emin olun. Hata: $e',
      );
    }
  }
}