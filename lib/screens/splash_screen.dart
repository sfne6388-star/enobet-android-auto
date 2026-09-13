import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ana_sayfa.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _arkaPlan = Colors.black;
  static const Color _enobetKirmizi = Color(0xFFE3262E);
  static const String _ikonYolu = 'assets/enobet_splash_icon.png';
  static const Duration _toplamSure = Duration(seconds: 4);

  late final AnimationController _controller;
  late final Animation<double> _logoOpaklik;
  late final Animation<double> _logoOlcek;
  late final Animation<double> _sloganOpaklik;

  bool _gecisYapildi = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _toplamSure,
    );

    _logoOpaklik = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOut),
    );

    _logoOlcek = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeOutBack),
      ),
    );

    _sloganOpaklik = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.28, curve: Curves.easeOut),
    );

    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _uygulamayiAc();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
  }

  void _uygulamayiAc() {
    if (!mounted || _gecisYapildi) return;
    _gecisYapildi = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return const AnaSayfa();
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: _arkaPlan,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        FadeTransition(
                          opacity: _logoOpaklik,
                          child: ScaleTransition(
                            scale: _logoOlcek,
                            child: Image.asset(
                              _ikonYolu,
                              width: 184,
                              height: 184,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        FadeTransition(
                          opacity: _sloganOpaklik,
                          child: const Text(
                            'Bul, Yaklaş, Ulaş...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 1.15,
                              height: 1.15,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0x66E3262E),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _ilerlemeCizgisi(_controller.value),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ilerlemeCizgisi(double ilerleme) {
    return SizedBox(
      width: 230,
      height: 8,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            width: 230,
            height: 2.4,
            decoration: BoxDecoration(
              color: const Color(0xFF292929),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          FractionallySizedBox(
            widthFactor: ilerleme.clamp(0.0, 1.0),
            child: Container(
              height: 2.8,
              decoration: BoxDecoration(
                color: _enobetKirmizi,
                borderRadius: BorderRadius.circular(99),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x99E3262E),
                    blurRadius: 7,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
