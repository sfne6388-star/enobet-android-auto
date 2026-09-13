import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/enobet_tema.dart';

class AcilHatlar extends StatefulWidget {
  const AcilHatlar({super.key});

  @override
  State<AcilHatlar> createState() => _AcilHatlarState();
}

class _AcilHatlarState extends State<AcilHatlar> {
  static const List<_AcilHat> _hatlar = [
    _AcilHat(
      baslik: '112 Acil Çağrı Merkezi',
      aciklama: 'Ambulans • Polis • Jandarma • İtfaiye • Sahil Güvenlik • AFAD',
      numara: '112',
      ikon: Icons.emergency_rounded,
      renk: Color(0xFFE3262E),
    ),
    _AcilHat(
      baslik: 'Ulusal Zehir Danışma Merkezi',
      aciklama: 'Zehirlenme durumlarında danışma ve yönlendirme',
      numara: '114',
      ikon: Icons.health_and_safety_rounded,
      renk: Color(0xFF8E44AD),
    ),
    _AcilHat(
      baslik: 'ALO 183 Sosyal Destek',
      aciklama: 'Aile, kadın, çocuk, engelli ve sosyal destek hizmetleri',
      numara: '183',
      ikon: Icons.volunteer_activism_rounded,
      renk: Color(0xFFE91E63),
    ),
    _AcilHat(
      baslik: 'Doğalgaz Acil',
      aciklama: 'Doğalgaz kaçağı ve acil durum ihbarı',
      numara: '187',
      ikon: Icons.local_fire_department_rounded,
      renk: Color(0xFFFF6D00),
    ),
    _AcilHat(
      baslik: 'Elektrik Arıza',
      aciklama: 'Elektrik arıza ve kesinti bildirimi',
      numara: '186',
      ikon: Icons.electric_bolt_rounded,
      renk: Color(0xFFFFC107),
    ),
    _AcilHat(
      baslik: 'Su Arıza',
      aciklama: 'Su arıza ve kesinti bildirimi',
      numara: '185',
      ikon: Icons.water_drop_rounded,
      renk: Color(0xFF2196F3),
    ),
    _AcilHat(
      baslik: 'Karayolları Yol Danışma',
      aciklama: 'Yol durumu ve karayolları danışma hattı',
      numara: '159',
      ikon: Icons.add_road_rounded,
      renk: Color(0xFF00A86B),
    ),
  ];

  Timer? _blinkTimer;
  bool _parlak = true;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          _parlak = !_parlak;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  Future<void> _ara(BuildContext context, String numara) async {
    final uri = Uri(scheme: 'tel', path: numara);
    final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!acildi && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$numara arama ekranı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.enobetTema;

    return Scaffold(
      backgroundColor: tema.arkaPlan,
      appBar: AppBar(
        backgroundColor: tema.appBar,
        foregroundColor: tema.anaYazi,
        elevation: 0,
        title: const Text(
          'Acil Hatlar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: _hatlar.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final hat = _hatlar[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tema.kart,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tema.sinir),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hat.renk.withValues(
                        alpha: _parlak ? 0.16 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: hat.renk.withValues(
                            alpha: _parlak ? 0.18 : 0.03,
                          ),
                          blurRadius: _parlak ? 7 : 1,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      hat.ikon,
                      color: hat.renk.withValues(
                        alpha: _parlak ? 0.90 : 0.50,
                      ),
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hat.baslik,
                          style: TextStyle(
                            color: tema.anaYazi,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hat.aciklama,
                          style: TextStyle(
                            color: tema.ikincilYazi,
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          hat.numara,
                          style: TextStyle(
                            color: hat.renk,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: hat.renk,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _ara(context, hat.numara),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.phone_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AcilHat {
  final String baslik;
  final String aciklama;
  final String numara;
  final IconData ikon;
  final Color renk;

  const _AcilHat({
    required this.baslik,
    required this.aciklama,
    required this.numara,
    required this.ikon,
    required this.renk,
  });
}
