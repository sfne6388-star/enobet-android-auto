import 'dart:math' as math;

import 'package:flutter/material.dart';

class HerseyBuradaIkon extends StatefulWidget {
  final double size;

  const HerseyBuradaIkon({
    super.key,
    this.size = 62,
  });

  @override
  State<HerseyBuradaIkon> createState() => _HerseyBuradaIkonState();
}

class _HerseyBuradaIkonState extends State<HerseyBuradaIkon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _kirmizi = Color(0xFFE3262E);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _sinirParlama(double progress) {
    final double mesafe = math.min(progress, 1 - progress);

    if (mesafe >= 0.16) {
      return 0;
    }

    final double t = 1 - (mesafe / 0.16);

    return math.sin(t * math.pi).abs();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double p = _controller.value;

        // Üç karenin sırası: sol üst -> sağ üst -> sol alt -> tekrar başa.
        final double kareFaz = p * 3;
        final int aktifKare = kareFaz.floor() % 3;
        final double kareIlerleme = kareFaz - kareFaz.floor();

        // Bir kare sönerken sıradaki kare yumuşak şekilde devreye girer.
        final List<double> kareParlaklik = List<double>.filled(3, 0.20);
        kareParlaklik[aktifKare] = 1 - (kareIlerleme * 0.36);
        kareParlaklik[(aktifKare + 1) % 3] =
            math.max(kareParlaklik[(aktifKare + 1) % 3], kareIlerleme * 0.82);

        // Tur başa dönerken + işareti büyüyüp küçülür.
        final double basaDonus = _sinirParlama(p);
        final double artiScale = 1 + (basaDonus * 0.38);
        final double artiParlaklik = 0.68 + (basaDonus * 0.32);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.square(widget.size),
                painter: _DonenIsikPainter(
                  progress: p,
                  renk: _kirmizi,
                ),
              ),
              Container(
                width: widget.size * 0.82,
                height: widget.size * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF090B0F),
                  border: Border.all(
                    color: _kirmizi.withValues(alpha: 0.20),
                    width: 1,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _kirmizi.withValues(alpha: 0.10),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: widget.size * 0.34,
                    height: widget.size * 0.34,
                    child: Stack(
                      children: <Widget>[
                        _kare(
                          alignment: Alignment.topLeft,
                          parlaklik: kareParlaklik[0],
                        ),
                        _kare(
                          alignment: Alignment.topRight,
                          parlaklik: kareParlaklik[1],
                        ),
                        _kare(
                          alignment: Alignment.bottomLeft,
                          parlaklik: kareParlaklik[2],
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Transform.scale(
                            scale: artiScale,
                            child: Container(
                              width: widget.size * 0.145,
                              height: widget.size * 0.145,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kirmizi.withValues(
                                  alpha: 0.08 + (basaDonus * 0.14),
                                ),
                                boxShadow: <BoxShadow>[
                                  if (basaDonus > 0.05)
                                    BoxShadow(
                                      color: _kirmizi.withValues(
                                        alpha: 0.38 * basaDonus,
                                      ),
                                      blurRadius: 8 * basaDonus,
                                      spreadRadius: 0.5 * basaDonus,
                                    ),
                                ],
                              ),
                              child: Text(
                                '+',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _kirmizi.withValues(
                                    alpha: artiParlaklik,
                                  ),
                                  height: 0.92,
                                  fontSize: widget.size * 0.155,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kare({
    required Alignment alignment,
    required double parlaklik,
  }) {
    final double opacity = parlaklik.clamp(0.18, 1.0);

    return Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: widget.size * 0.145,
        height: widget.size * 0.145,
        decoration: BoxDecoration(
          color: _kirmizi.withValues(alpha: 0.10 + (opacity * 0.82)),
          borderRadius: BorderRadius.circular(widget.size * 0.026),
          border: Border.all(
            color: _kirmizi.withValues(alpha: 0.32 + (opacity * 0.68)),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            if (opacity > 0.45)
              BoxShadow(
                color: _kirmizi.withValues(
                  alpha: 0.46 * opacity,
                ),
                blurRadius: 7 * opacity,
                spreadRadius: 0.4 * opacity,
              ),
          ],
        ),
      ),
    );
  }
}

class _DonenIsikPainter extends CustomPainter {
  final double progress;
  final Color renk;

  const _DonenIsikPainter({
    required this.progress,
    required this.renk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset merkez = size.center(Offset.zero);
    final double yaricap = (size.shortestSide / 2) - 2.2;

    // Çok hafif sabit halka.
    final Paint zemin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..color = renk.withValues(alpha: 0.16);

    canvas.drawCircle(merkez, yaricap, zemin);

    final double baslangic = (-math.pi / 2) + (progress * math.pi * 2);
    const double yayUzunlugu = math.pi * 0.72;

    // Dönen ışığın dış halesi.
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.2
      ..strokeCap = StrokeCap.round
      ..color = renk.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      );

    canvas.drawArc(
      Rect.fromCircle(center: merkez, radius: yaricap),
      baslangic,
      yayUzunlugu,
      false,
      glow,
    );

    // Asıl parlak kırmızı ışık.
    final Paint parlak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..color = renk;

    canvas.drawArc(
      Rect.fromCircle(center: merkez, radius: yaricap),
      baslangic,
      yayUzunlugu,
      false,
      parlak,
    );

    // Hareket yönünü daha net belli eden parlak uç noktası.
    final double ucAci = baslangic + yayUzunlugu;
    final Offset uc = Offset(
      merkez.dx + math.cos(ucAci) * yaricap,
      merkez.dy + math.sin(ucAci) * yaricap,
    );

    final Paint ucGlow = Paint()
      ..color = renk.withValues(alpha: 0.72)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      );

    canvas.drawCircle(uc, 3.8, ucGlow);

    final Paint ucNokta = Paint()..color = renk;
    canvas.drawCircle(uc, 2.0, ucNokta);
  }

  @override
  bool shouldRepaint(covariant _DonenIsikPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.renk != renk;
  }
}
