import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class DadiAvatar extends StatefulWidget {
  final double size;
  final bool aktif;
  final bool golge;

  const DadiAvatar({
    super.key,
    this.size = 48,
    this.aktif = false,
    this.golge = true,
  });

  @override
  State<DadiAvatar> createState() => _DadiAvatarState();
}

class _DadiAvatarState extends State<DadiAvatar>
    with TickerProviderStateMixin {
  static const Color _cimYesili = Color(0xFF2F8F32);
  static const Color _cimYesiliOrta = Color(0xFF176B2C);
  static const Color _cimYesiliKoyu = Color(0xFF0B4B1E);
  static const Color _gozKirmizi = Color(0xFFE3262E);

  late final AnimationController _nefesController;
  late final AnimationController _kafaController;
  late final AnimationController _blinkController;
  late final AnimationController _ziplaController;

  late final Animation<double> _nefes;
  late final Animation<double> _kafa;
  late final Animation<double> _gozAcikligi;
  late final Animation<double> _zipla;

  Timer? _blinkTimer;
  Timer? _ziplaTimer;

  bool _solGozKirpiyor = false;

  @override
  void initState() {
    super.initState();

    _nefesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..repeat(reverse: true);

    _nefes = Tween<double>(
      begin: 0.90,
      end: 1.12,
    ).animate(
      CurvedAnimation(
        parent: _nefesController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _kafaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat(reverse: true);

    _kafa = Tween<double>(
      begin: -0.30,
      end: 0.30,
    ).animate(
      CurvedAnimation(
        parent: _kafaController,
        curve: Curves.easeInOutSine,
      ),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _gozAcikligi = Tween<double>(
      begin: 1,
      end: 0.06,
    ).animate(
      CurvedAnimation(
        parent: _blinkController,
        curve: Curves.easeInOut,
      ),
    );

    _ziplaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _zipla = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: -7.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: -7.0, end: 0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 55,
      ),
    ]).animate(_ziplaController);

    _blinkTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _gozKirp(),
    );

    _ziplaTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (mounted && !_ziplaController.isAnimating) {
          _ziplaController.forward(from: 0);
        }
      },
    );
  }

  Future<void> _gozKirp() async {
    if (!mounted || _blinkController.isAnimating) return;

    _solGozKirpiyor = !_solGozKirpiyor;

    if (_solGozKirpiyor) {
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _solGozKirpiyor = false;
      });
      return;
    }

    await _blinkController.forward();
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 65));
    if (!mounted) return;

    await _blinkController.reverse();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _ziplaTimer?.cancel();
    _nefesController.dispose();
    _kafaController.dispose();
    _blinkController.dispose();
    _ziplaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _nefes,
        _kafa,
        _gozAcikligi,
        _zipla,
      ]),
      builder: (context, _) {
        final double donus = _kafa.value;
        final double gozKaymasi = donus * widget.size * 0.075;

        return Transform.translate(
          offset: Offset(0, _zipla.value),
          child: Transform.scale(
            scale: _nefes.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateY(donus)
                ..rotateZ(math.sin(_kafaController.value * math.pi * 2) * 0.018),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.30, -0.36),
                    radius: 1.10,
                    colors: <Color>[
                      _cimYesili,
                      _cimYesiliOrta,
                      _cimYesiliKoyu,
                    ],
                  ),
                  border: Border.all(
                    color: _cimYesili.withValues(
                      alpha: widget.aktif ? 1.0 : 0.82,
                    ),
                    width: widget.size < 55 ? 1.6 : 2.2,
                  ),
                  boxShadow: widget.golge
                      ? <BoxShadow>[
                          BoxShadow(
                            color: _cimYesili.withValues(
                              alpha: widget.aktif ? 0.42 : 0.25,
                            ),
                            blurRadius: widget.size * 0.32,
                            spreadRadius: widget.aktif ? 1.2 : 0,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned(
                      top: widget.size * 0.13,
                      right: widget.size * 0.18,
                      child: Container(
                        width: widget.size * 0.12,
                        height: widget.size * 0.12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(gozKaymasi, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _goz(
                            aciklik: _solGozKirpiyor
                                ? 0.08
                                : _gozAcikligi.value,
                          ),
                          SizedBox(width: widget.size * 0.13),
                          _goz(aciklik: _gozAcikligi.value),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: widget.size * 0.24,
                      child: Container(
                        width: widget.size * 0.16,
                        height: widget.size * 0.035,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.44),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _goz({required double aciklik}) {
    final double eyeWidth = widget.size * 0.17;
    final double eyeHeight = widget.size * 0.105;

    return Transform.scale(
      scaleY: aciklik,
      child: Container(
        width: eyeWidth,
        height: eyeHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFFFF7A7F),
              _gozKirmizi,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _gozKirmizi.withValues(alpha: 0.60),
              blurRadius: 7,
            ),
          ],
        ),
      ),
    );
  }
}
