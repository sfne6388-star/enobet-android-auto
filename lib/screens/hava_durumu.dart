
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/konum_verileri.dart';

class HavaDurumuEkrani extends StatefulWidget {
  final String baslangicIl;
  final String baslangicIlce;
  final double? baslangicEnlem;
  final double? baslangicBoylam;
  final bool gpsKonumu;

  const HavaDurumuEkrani({
    super.key,
    required this.baslangicIl,
    required this.baslangicIlce,
    required this.baslangicEnlem,
    required this.baslangicBoylam,
    required this.gpsKonumu,
  });

  @override
  State<HavaDurumuEkrani> createState() => _HavaDurumuEkraniState();
}

class _HavaDurumuEkraniState extends State<HavaDurumuEkrani>
    with TickerProviderStateMixin {
  static const Color _vurguMavi = Color(0xFF63C7FF);
  static const Color _kartBeyaz = Color(0x26FFFFFF);
  static const Color _kartSinir = Color(0x40FFFFFF);

  bool _yukleniyor = true;
  String? _hata;
  Map<String, dynamic>? _veri;
  String _il = '';
  String _ilce = '';
  double? _enlem;
  double? _boylam;

  late final AnimationController _gokyuzuController;
  late final AnimationController _yagmurController;
  late final AnimationController _nefesController;

  @override
  void initState() {
    super.initState();
    _il = widget.baslangicIl;
    _ilce = widget.baslangicIlce;
    _enlem = widget.baslangicEnlem;
    _boylam = widget.baslangicBoylam;

    _gokyuzuController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    _yagmurController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _nefesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
      lowerBound: 0.92,
      upperBound: 1.04,
    )..repeat(reverse: true);

    _baslat();
  }

  @override
  void dispose() {
    _gokyuzuController.dispose();
    _yagmurController.dispose();
    _nefesController.dispose();
    super.dispose();
  }

  Future<void> _baslat() async {
    if (_enlem != null && _boylam != null) {
      await _havaDurumunuGetir();
      return;
    }
    if (_il.isNotEmpty) {
      await _sehirKoordinatiBulVeGetir(_il, _ilce);
      return;
    }
    if (mounted) {
      setState(() {
        _yukleniyor = false;
        _hata =
            'Konum belirlenemedi. İl / ilçe seçerek hava durumunu görüntüleyin.';
      });
    }
  }

  Future<void> _sehirKoordinatiBulVeGetir(String il, String ilce) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final String arama = ilce.trim().isEmpty ? il : '$ilce, $il';
      final Uri uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': arama,
        'count': '10',
        'language': 'tr',
        'format': 'json',
        'countryCode': 'TR',
      });

      http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      List<dynamic> sonuclar = (json['results'] as List?) ?? const <dynamic>[];

      if (sonuclar.isEmpty && ilce.trim().isNotEmpty) {
        final Uri ikinci =
            Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
          'name': ilce,
          'count': '10',
          'language': 'tr',
          'format': 'json',
          'countryCode': 'TR',
        });
        response = await http.get(ikinci).timeout(const Duration(seconds: 15));
        json = jsonDecode(response.body) as Map<String, dynamic>;
        sonuclar = (json['results'] as List?) ?? const <dynamic>[];
      }

      if (sonuclar.isEmpty) {
        throw Exception('Konum bulunamadı');
      }

      Map<String, dynamic> secilen =
          Map<String, dynamic>.from(sonuclar.first as Map);
      final String ilKucuk = il.toLowerCase();
      for (final dynamic item in sonuclar) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(item as Map);
        final String admin = (m['admin1'] ?? '').toString().toLowerCase();
        if (admin.contains(ilKucuk) || ilKucuk.contains(admin)) {
          secilen = m;
          break;
        }
      }

      _enlem = (secilen['latitude'] as num).toDouble();
      _boylam = (secilen['longitude'] as num).toDouble();
      await _havaDurumunuGetir();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata =
            'Seçilen konumun koordinatı bulunamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _havaDurumunuGetir() async {
    if (_enlem == null || _boylam == null) return;

    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final Uri uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': _enlem!.toStringAsFixed(6),
        'longitude': _boylam!.toStringAsFixed(6),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m',
        'hourly':
            'temperature_2m,weather_code,precipitation_probability',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '7',
      });

      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dynamic json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        throw Exception('Geçersiz veri');
      }

      if (!mounted) return;
      setState(() {
        _veri = json;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata =
            'Hava durumu alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _konumSec() async {
    String seciliIl =
        _il.isNotEmpty && konumVerileri.containsKey(_il)
            ? _il
            : konumVerileri.keys.first;
    String seciliIlce = _ilce;

    final List<String>? sonuc = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final List<String> ilceler =
                konumVerileri[seciliIl] ?? const <String>[];
            if (!ilceler.contains(seciliIlce)) {
              seciliIlce = ilceler.isEmpty ? '' : ilceler.first;
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      decoration: BoxDecoration(
                        color: const Color(0xDD10253D),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0x30FFFFFF)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Hava Durumu Konumu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mevcut konumu kullanabilir veya farklı bir il / ilçe seçebilirsin.',
                            style: TextStyle(
                              color: Color(0xC8FFFFFF),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _secimKutusu(
                            child: DropdownButtonFormField<String>(
                              initialValue: seciliIl,
                              dropdownColor: const Color(0xFF16304C),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'İl',
                                labelStyle: TextStyle(color: Colors.white70),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items: konumVerileri.keys
                                  .map(
                                    (String e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) {
                                modalSetState(() {
                                  if (v == null) return;
                                  seciliIl = v;
                                  final List<String> liste =
                                      konumVerileri[v] ?? const <String>[];
                                  seciliIlce =
                                      liste.isEmpty ? '' : liste.first;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _secimKutusu(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  seciliIlce.isEmpty ? null : seciliIlce,
                              dropdownColor: const Color(0xFF16304C),
                              iconEnabledColor: Colors.white,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'İlçe',
                                labelStyle: TextStyle(color: Colors.white70),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              items: ilceler
                                  .map(
                                    (String e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? v) {
                                modalSetState(() => seciliIlce = v ?? '');
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _vurguMavi,
                                foregroundColor: const Color(0xFF06243A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed:
                                  () => Navigator.pop(
                                    context,
                                    <String>[seciliIl, seciliIlce],
                                  ),
                              child: const Text(
                                'Hava Durumunu Göster',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (sonuc == null || sonuc.length < 2) return;

    setState(() {
      _il = sonuc[0];
      _ilce = sonuc[1];
      _enlem = null;
      _boylam = null;
    });

    await _sehirKoordinatiBulVeGetir(_il, _ilce);
  }

  Widget _secimKutusu({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }

  int get _weatherCode =>
      ((_veri?['current'] as Map?)?['weather_code'] as num?)?.toInt() ?? 1;

  bool get _isDay =>
      (((_veri?['current'] as Map?)?['is_day'] as num?)?.toInt() ?? 1) == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _canliArkaPlan()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                _ustBar(),
                Expanded(
                  child: _yukleniyor
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _hata != null
                      ? _hataAlani()
                      : _icerik(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _canliArkaPlan() {
    final int code = _weatherCode;
    final bool isDay = _isDay;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _gokyuzuController,
        _yagmurController,
        _nefesController,
      ]),
      builder: (BuildContext context, Widget? child) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _gokyuzuRenkleri(code, isDay),
                ),
              ),
            ),
            if (!_yagisli(code) && !_cokBulutlu(code)) ...<Widget>[
              _gokCismi(code, isDay),
            ] else if (_yagisli(code) && isDay) ...<Widget>[
              Positioned(
                top: 70,
                right: -40,
                child: Transform.scale(
                  scale: _nefesController.value,
                  child: _parlayanGunes(kapaliArka: true),
                ),
              ),
            ] else if (!isDay) ...<Widget>[
              Positioned(
                top: 70,
                right: 28,
                child: _ay(),
              ),
            ],
            ..._bulutKatmanlari(code, isDay),
            if (_sisli(code)) _sisKatmani(),
            if (_yagisli(code)) _yagmurKatmani(code),
            if (_karli(code)) _karKatmani(),
          ],
        );
      },
    );
  }

  List<Color> _gokyuzuRenkleri(int code, bool isDay) {
    if (!isDay) {
      if (_yagisli(code) || _cokBulutlu(code)) {
        return const <Color>[
          Color(0xFF0B1320),
          Color(0xFF141F2F),
          Color(0xFF253244),
          Color(0xFF394A5B),
        ];
      }
      return const <Color>[
        Color(0xFF05101F),
        Color(0xFF12233A),
        Color(0xFF274666),
        Color(0xFF49698C),
      ];
    }

    if (_yagisli(code) || _karli(code)) {
      return const <Color>[
        Color(0xFF536C82),
        Color(0xFF6D8799),
        Color(0xFF8197A8),
        Color(0xFFA6B7C2),
      ];
    }

    if (_cokBulutlu(code)) {
      return const <Color>[
        Color(0xFF607080),
        Color(0xFF7D8D98),
        Color(0xFFA3B2BA),
        Color(0xFFD0D9DF),
      ];
    }

    if (_azBulutlu(code)) {
      return const <Color>[
        Color(0xFF63B7FF),
        Color(0xFF84CBFF),
        Color(0xFFA9DBFF),
        Color(0xFFDDF2FF),
      ];
    }

    if (_sisli(code)) {
      return const <Color>[
        Color(0xFF7D9AB4),
        Color(0xFF9DB5C8),
        Color(0xFFC3D0D8),
        Color(0xFFE1E8EC),
      ];
    }

    return const <Color>[
      Color(0xFF48A9FF),
      Color(0xFF6BC0FF),
      Color(0xFFA6E0FF),
      Color(0xFFF3FBFF),
    ];
  }

  Widget _gokCismi(int code, bool isDay) {
    if (isDay) {
      return Positioned(
        top: 58,
        right: -35,
        child: Transform.scale(
          scale: _nefesController.value,
          child: _parlayanGunes(),
        ),
      );
    }

    return Positioned(top: 70, right: 28, child: _ay());
  }

  Widget _parlayanGunes({bool kapaliArka = false}) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: kapaliArka ? 160 : 210,
          height: kapaliArka ? 160 : 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFFFF4A0).withValues(
                  alpha: kapaliArka ? 0.22 : 0.38,
                ),
                blurRadius: kapaliArka ? 55 : 90,
                spreadRadius: kapaliArka ? 20 : 34,
              ),
            ],
          ),
        ),
        Container(
          width: kapaliArka ? 74 : 96,
          height: kapaliArka ? 74 : 96,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Color(0xFFFFFFFF),
                Color(0xFFFFF1A8),
                Color(0xFFFFD65C),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ay() {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFFDAECFF).withValues(alpha: 0.22),
                blurRadius: 45,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                Color(0xFFF6FAFF),
                Color(0xFFDDEBFA),
                Color(0xFFBED1E7),
              ],
            ),
          ),
        ),
        Positioned(
          right: 7,
          top: 9,
          child: Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF18304A),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _bulutKatmanlari(int code, bool isDay) {
    final List<Widget> katmanlar = <Widget>[];
    final double t = _gokyuzuController.value;
    final Color acikBulut = isDay
        ? Colors.white.withValues(alpha: 0.72)
        : const Color(0xFFC9D5E2).withValues(alpha: 0.34);
    final Color koyuBulut = isDay
        ? const Color(0xFF76818B).withValues(alpha: 0.92)
        : const Color(0xFF394552).withValues(alpha: 0.95);

    if (_gunesli(code)) {
      katmanlar.addAll(<Widget>[
        Positioned(
          top: 96,
          left: -20 + (t * 35),
          child: _Bulut(
            width: 122,
            height: 52,
            color: Colors.white.withValues(alpha: 0.38),
          ),
        ),
        Positioned(
          top: 160,
          right: 20 - (t * 45),
          child: _Bulut(
            width: 98,
            height: 42,
            color: Colors.white.withValues(alpha: 0.26),
          ),
        ),
      ]);
      return katmanlar;
    }

    if (_azBulutlu(code)) {
      katmanlar.addAll(<Widget>[
        Positioned(
          top: 104,
          left: -50 + (t * 80),
          child: _Bulut(width: 158, height: 64, color: acikBulut),
        ),
        Positioned(
          top: 178,
          right: -40 + ((1 - t) * 76),
          child: _Bulut(
            width: 132,
            height: 58,
            color: Colors.white.withValues(alpha: 0.58),
          ),
        ),
      ]);
      return katmanlar;
    }

    if (_cokBulutlu(code) || _yagisli(code) || _karli(code)) {
      katmanlar.addAll(<Widget>[
        Positioned(
          top: 86,
          left: -50 + (t * 42),
          child: _Bulut(width: 214, height: 88, color: koyuBulut),
        ),
        Positioned(
          top: 126,
          right: -60 + ((1 - t) * 32),
          child: _Bulut(
            width: 238,
            height: 96,
            color: (_yagisli(code) || _karli(code))
                ? const Color(0xFF5D6872).withValues(alpha: 0.98)
                : const Color(0xFF8C98A2).withValues(alpha: 0.98),
          ),
        ),
        Positioned(
          top: 190,
          left: 20 - (t * 16),
          child: _Bulut(
            width: 190,
            height: 78,
            color: (_yagisli(code) || _karli(code))
                ? const Color(0xFF727F89).withValues(alpha: 0.84)
                : const Color(0xFFADB8C0).withValues(alpha: 0.72),
          ),
        ),
      ]);
    }

    return katmanlar;
  }

  Widget _sisKatmani() {
    final double t = _gokyuzuController.value;
    return Stack(
      children: <Widget>[
        Positioned(
          top: 220,
          left: -40 + (t * 30),
          right: -10,
          child: _SisBand(opacity: 0.24, height: 110),
        ),
        Positioned(
          bottom: 120,
          left: -20,
          right: -40 + ((1 - t) * 34),
          child: _SisBand(opacity: 0.34, height: 130),
        ),
      ],
    );
  }

  Widget _yagmurKatmani(int code) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _YagmurPainter(
              progress: _yagmurController.value,
              yogunluk: code >= 95 ? 1.0 : 0.78,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.03),
                    Colors.white.withValues(alpha: 0.01),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _karKatmani() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _KarPainter(progress: _yagmurController.value),
      ),
    );
  }

  Widget _ustBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 4),
      child: Row(
        children: <Widget>[
          _yuvarlakButon(
            onTap: () => Navigator.pop(context),
            icon: Icons.arrow_back_ios_new_rounded,
          ),
          const Expanded(
            child: Text(
              'Hava Durumu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _yuvarlakButon(
            onTap: _konumSec,
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _yuvarlakButon({required VoidCallback onTap, required IconData icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hataAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _camKart(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.cloud_off_rounded,
                size: 58,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _hata!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _vurguMavi,
                  foregroundColor: const Color(0xFF05253B),
                ),
                onPressed: _konumSec,
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('İl / İlçe Seç'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icerik() {
    final Map<String, dynamic> current =
        Map<String, dynamic>.from(_veri!['current'] as Map);
    final Map<String, dynamic> daily =
        Map<String, dynamic>.from(_veri!['daily'] as Map);
    final int code = (current['weather_code'] as num).toInt();
    final int sicaklik = (current['temperature_2m'] as num).round();
    final int hissedilen = (current['apparent_temperature'] as num).round();
    final int nem = (current['relative_humidity_2m'] as num).round();
    final int ruzgar = (current['wind_speed_10m'] as num).round();
    final int yon = (current['wind_direction_10m'] as num).round();
    final int max = ((daily['temperature_2m_max'] as List).first as num).round();
    final int min = ((daily['temperature_2m_min'] as List).first as num).round();

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: const Color(0xFF1C3550),
      onRefresh: _havaDurumunuGetir,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _konumSec,
            child: _camKart(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.gpsKonumu && _il.isNotEmpty
                              ? 'Konumunuz'
                              : 'Seçili Konum',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xD8FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _konumAdi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Text(
              '$sicaklik°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                height: 1,
                fontWeight: FontWeight.w300,
                letterSpacing: -5,
              ),
            ),
          ),
          Center(
            child: Text(
              _aciklama(code),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(
              'Hissedilen $hissedilen°   •   En yüksek $max°   •   En düşük $min°',
              style: const TextStyle(
                color: Color(0xEDFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _saatlikKart(),
          const SizedBox(height: 14),
          _gunlukKart(),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _miniKart(Icons.water_drop_rounded, 'Nem', '%$nem'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKart(Icons.air_rounded, 'Rüzgar', '$ruzgar km/sa'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKart(Icons.explore_rounded, 'Yön', _ruzgarYonu(yon)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Hava durumu verisi: Open-Meteo',
              style: TextStyle(fontSize: 11, color: Color(0xE6FFFFFF)),
            ),
          ),
        ],
      ),
    );
  }

  String get _konumAdi {
    if (_ilce.isNotEmpty && _il.isNotEmpty) return '$_ilce, $_il';
    if (_il.isNotEmpty) return _il;
    return 'Mevcut Konum';
  }

  Widget _saatlikKart() {
    final Map<String, dynamic> hourly =
        Map<String, dynamic>.from(_veri!['hourly'] as Map);
    final List<String> times = List<String>.from(hourly['time'] as List);
    final List<dynamic> temps = List<dynamic>.from(hourly['temperature_2m'] as List);
    final List<dynamic> codes = List<dynamic>.from(hourly['weather_code'] as List);
    final List<dynamic> probs =
        List<dynamic>.from(hourly['precipitation_probability'] as List);
    final DateTime now = DateTime.now();
    int start = times.indexWhere((String t) {
      final DateTime? d = DateTime.tryParse(t);
      return d != null &&
          !d.isBefore(DateTime(now.year, now.month, now.day, now.hour));
    });
    if (start < 0) start = 0;
    final int end = (start + 12).clamp(0, times.length);

    return _camKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'SAATLİK TAHMİN',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xE6FFFFFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 22),
          SizedBox(
            height: 114,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: end - start,
              separatorBuilder: (_, __) => const SizedBox(width: 22),
              itemBuilder: (BuildContext context, int i) {
                final int idx = start + i;
                final DateTime? d = DateTime.tryParse(times[idx]);
                return SizedBox(
                  width: 50,
                  child: Column(
                    children: <Widget>[
                      Text(
                        i == 0
                            ? 'Şimdi'
                            : '${d?.hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        _ikon((codes[idx] as num).toInt()),
                        size: 27,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(temps[idx] as num).round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '%${(probs[idx] as num).round()}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: _vurguMavi,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _gunlukKart() {
    final Map<String, dynamic> daily =
        Map<String, dynamic>.from(_veri!['daily'] as Map);
    final List<String> times = List<String>.from(daily['time'] as List);
    final List<dynamic> codes = List<dynamic>.from(daily['weather_code'] as List);
    final List<dynamic> maxs =
        List<dynamic>.from(daily['temperature_2m_max'] as List);
    final List<dynamic> mins =
        List<dynamic>.from(daily['temperature_2m_min'] as List);
    final List<dynamic> probs =
        List<dynamic>.from(daily['precipitation_probability_max'] as List);

    return _camKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '7 GÜNLÜK TAHMİN',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xE6FFFFFF),
              fontWeight: FontWeight.w800,
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.14), height: 22),
          ...List<Widget>.generate(times.length, (int i) {
            final DateTime d = DateTime.tryParse(times[i]) ?? DateTime.now();
            return Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 82,
                        child: Text(
                          i == 0 ? 'Bugün' : _gunAdi(d.weekday),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _ikon((codes[i] as num).toInt()),
                        size: 25,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '%${(probs[i] as num).round()}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _vurguMavi,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(mins[i] as num).round()}°',
                        style: const TextStyle(
                          color: Color(0xD6FFFFFF),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${(maxs[i] as num).round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != times.length - 1)
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.14)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _miniKart(IconData icon, String baslik, String deger) {
    return _camKart(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 22, color: _vurguMavi),
          const SizedBox(height: 6),
          Text(
            baslik,
            style: const TextStyle(fontSize: 11, color: Color(0xD6FFFFFF)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              deger,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _camKart({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(15),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kartBeyaz,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _kartSinir),
          ),
          child: child,
        ),
      ),
    );
  }

  bool _gunesli(int c) => c == 0;
  bool _azBulutlu(int c) => c == 1 || c == 2;
  bool _cokBulutlu(int c) => c == 3;
  bool _sisli(int c) => c >= 45 && c <= 48;
  bool _karli(int c) => (c >= 71 && c <= 77) || (c >= 85 && c <= 86);
  bool _yagisli(int c) => (c >= 51 && c <= 67) || (c >= 80 && c <= 99);

  IconData _ikon(int c) {
    if (c == 0) return Icons.wb_sunny_rounded;
    if (c == 1) return Icons.sunny_snowing;
    if (c == 2) return Icons.cloud_queue_rounded;
    if (c == 3) return Icons.cloud_rounded;
    if (c <= 48) return Icons.foggy;
    if (c <= 57) return Icons.grain_rounded;
    if (c <= 67) return Icons.water_drop_rounded;
    if (c <= 77) return Icons.ac_unit_rounded;
    if (c <= 82) return Icons.umbrella_rounded;
    if (c <= 86) return Icons.ac_unit_rounded;
    return Icons.thunderstorm_rounded;
  }

  String _aciklama(int c) {
    if (c == 0) return 'Açık Hava';
    if (c == 1) return 'Az Bulutlu';
    if (c == 2) return 'Parçalı Bulutlu';
    if (c == 3) return 'Çok Bulutlu';
    if (c <= 48) return 'Sisli';
    if (c <= 57) return 'Çisenti';
    if (c <= 67) return 'Yağmurlu';
    if (c <= 77) return 'Karlı';
    if (c <= 82) return 'Sağanak Yağışlı';
    if (c <= 86) return 'Kar Sağanaklı';
    return 'Gök Gürültülü';
  }

  String _gunAdi(int w) => const <String>[
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ][w - 1];

  String _ruzgarYonu(int derece) {
    const List<String> yonler = <String>['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    return yonler[((derece + 22.5) ~/ 45) % 8];
  }
}

class _Bulut extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const _Bulut({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double mainW = width * 0.62;
    final double mainH = height * 0.68;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: width * 0.18,
            bottom: 0,
            child: Container(
              width: mainW,
              height: mainH,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          Positioned(
            left: width * 0.03,
            bottom: height * 0.16,
            child: Container(
              width: width * 0.34,
              height: height * 0.48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: width * 0.24,
            top: 0,
            child: Container(
              width: width * 0.36,
              height: height * 0.56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: width * 0.06,
            bottom: height * 0.14,
            child: Container(
              width: width * 0.36,
              height: height * 0.52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SisBand extends StatelessWidget {
  final double opacity;
  final double height;

  const _SisBand({required this.opacity, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Colors.white.withValues(alpha: opacity * 0.18),
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity * 0.16),
          ],
        ),
      ),
    );
  }
}

class _YagmurPainter extends CustomPainter {
  final double progress;
  final double yogunluk;

  const _YagmurPainter({required this.progress, required this.yogunluk});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;

    final int adet = (150 * yogunluk).round();

    for (int i = 0; i < adet; i++) {
      final double px = ((i * 37.0) % size.width);
      final double baseY = ((i * 53.0) % size.height);
      final double speed = 120 + ((i % 7) * 22);
      final double y = (baseY + (progress * speed * 12)) % (size.height + 30);
      final double len = 10 + (i % 4) * 3;
      canvas.drawLine(
        Offset(px, y),
        Offset(px - 5.5, y + len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _YagmurPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.yogunluk != yogunluk;
  }
}

class _KarPainter extends CustomPainter {
  final double progress;

  const _KarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 72; i++) {
      final double baseX = (i * 29.0) % size.width;
      final double sway = math.sin((progress * math.pi * 2) + i) * 9;
      final double x = baseX + sway;
      final double baseY = (i * 47.0) % size.height;
      final double y = (baseY + (progress * (80 + i % 5 * 18) * 10)) % size.height;
      final double r = 1.4 + (i % 4) * 0.45;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _KarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
