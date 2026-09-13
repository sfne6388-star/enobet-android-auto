import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/bildirim_servisi.dart';
import 'theme/enobet_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await BildirimServisi.baslat();
  }

  final prefs = await SharedPreferences.getInstance();
  String temaModu = prefs.getString(temaTercihiAnahtari) ?? '';

  if (!gecerliTema(temaModu)) {
    final eskiKoyuTema = prefs.getBool(eskiKoyuTemaAnahtari) ?? true;
    temaModu = eskiKoyuTema ? temaKoyu : temaAcik;
    await prefs.setString(temaTercihiAnahtari, temaModu);
  }

  runApp(EnobetApp(temaModu: temaModu));
}

class EnobetApp extends StatefulWidget {
  final String temaModu;

  const EnobetApp({
    super.key,
    required this.temaModu,
  });

  static String temaModuOf(BuildContext context) => context.enobetTema.mod;

  static Future<void> temaAyarla(
    BuildContext context,
    String yeniTema,
  ) async {
    final state = context.findAncestorStateOfType<_EnobetAppState>();
    if (state == null) {
      throw StateError('ENöbet tema yöneticisi bulunamadı.');
    }
    await state.temaDegistir(yeniTema);
  }

  @override
  State<EnobetApp> createState() => _EnobetAppState();
}

class _EnobetAppState extends State<EnobetApp> {
  late String _temaModu;

  @override
  void initState() {
    super.initState();
    _temaModu = gecerliTema(widget.temaModu) ? widget.temaModu : temaKoyu;
  }

  Future<void> temaDegistir(String yeniTema) async {
    if (!gecerliTema(yeniTema) || yeniTema == _temaModu) return;

    final prefs = await SharedPreferences.getInstance();
    final kaydedildi = await prefs.setString(temaTercihiAnahtari, yeniTema);

    if (!kaydedildi) {
      throw StateError('Tema tercihi kaydedilemedi.');
    }

    await prefs.setBool(eskiKoyuTemaAnahtari, yeniTema == temaKoyu);

    if (!mounted) return;
    setState(() => _temaModu = yeniTema);
  }

  @override
  Widget build(BuildContext context) {
    final aktifTema = enobetTemaOlustur(_temaModu);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ENöbet',
      theme: aktifTema,
      darkTheme: aktifTema,
      themeMode: ThemeMode.system,
      themeAnimationDuration: const Duration(milliseconds: 220),
      home: const SplashScreen(),
    );
  }
}
