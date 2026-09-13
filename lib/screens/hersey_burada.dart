import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/hizmet.dart';
import '../services/akaryakit_servisi.dart';
import 'akaryakit_fiyatlari.dart';
import 'acil_hatlar.dart';
import 'doviz_kurlari.dart';
import 'hava_durumu.dart';
import 'yakin_hizmetler_haritasi.dart';

class HerseyBuradaEkrani extends StatefulWidget {
  final List<Hizmet> eczaneler;
  final List<Hizmet> veterinerler;
  final List<Hizmet> sarjIstasyonlari;
  final List<Hizmet> digerHizmetler;
  final double? mevcutEnlem;
  final double? mevcutBoylam;
  final bool gpsKonumu;
  final String il;
  final String ilce;

  const HerseyBuradaEkrani({
    super.key,
    required this.eczaneler,
    required this.veterinerler,
    required this.sarjIstasyonlari,
    required this.digerHizmetler,
    required this.mevcutEnlem,
    required this.mevcutBoylam,
    required this.gpsKonumu,
    required this.il,
    required this.ilce,
  });

  @override
  State<HerseyBuradaEkrani> createState() => _HerseyBuradaEkraniState();
}

class _HerseyBuradaEkraniState extends State<HerseyBuradaEkrani> {
  static const Color _arkaPlan = Color(0xFF070707);
  static const Color _kart = Color(0xFF111111);
  static const Color _kirmizi = Color(0xFFE3262E);
  static const Color _kirmiziYumusak = Color(0xFFB64149);
  static const Color _yesil = Color(0xFF22C55E);
  static const Color _yesilYumusak = Color(0xFF2F9C59);
  static const Color _mavi = Color(0xFF4EA7FF);
  static const Color _sari = Color(0xFFFFC107);
  static const Color _acikYazi = Color(0xFFF5F5F5);
  static const Color _celikKoyu = Color(0xFF89939F);
  static const Color _panelSiyah = Color(0xFF0A0A0A);
  static const Color _mor = Color(0xFF8B7CFF);
  static const Color _turuncu = Color(0xFFFF8A3D);
  static const double _troyOnsGram = 31.1034768;

  final AkaryakitServisi _akaryakitServisi = AkaryakitServisi();

  bool _dovizYukleniyor = true;
  String? _dovizHata;
  double? _usd;
  double? _eur;
  double? _altin;
  double? _gumusGram;

  bool _havaYukleniyor = true;
  String? _havaHata;
  int? _havaCode;
  int? _havaSicaklik;
  bool _havaGunduz = true;

  bool _akaryakitYukleniyor = true;
  String? _akaryakitHata;
  double? _benzin;
  double? _motorin;
  double? _lpg;
  String? _akaryakitTarih;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    await Future.wait(<Future<void>>[
      _dovizGetir(),
      _havaGetir(),
      _akaryakitGetir(),
    ]);
  }

  Future<void> _dovizGetir() async {
    if (mounted) {
      setState(() {
        _dovizYukleniyor = true;
        _dovizHata = null;
      });
    }

    try {
      final double usd = await _kurGetir('USD');
      final double eur = await _kurGetir('EUR');

      final Uri metalUri = Uri.parse(
        'https://xaus.com/api/v1/spot?currency=TRY&unit=gram',
      );
      final http.Response metalResponse =
          await http.get(metalUri).timeout(const Duration(seconds: 12));
      if (metalResponse.statusCode != 200) {
        throw Exception('Metal servisi çalışmıyor');
      }
      final dynamic metalVeri = jsonDecode(metalResponse.body);
      final double? gramAltin = metalVeri is Map &&
              metalVeri['xau'] is Map &&
              metalVeri['xau']['price'] is num
          ? (metalVeri['xau']['price'] as num).toDouble()
          : null;
      final double? gumusOnsUsd =
          metalVeri is Map && metalVeri['silver_usd_oz'] is num
              ? (metalVeri['silver_usd_oz'] as num).toDouble()
              : null;
      final double? usdTry = metalVeri is Map && metalVeri['fx_rate'] is num
          ? (metalVeri['fx_rate'] as num).toDouble()
          : null;

      if (gramAltin == null || gramAltin <= 0) {
        throw Exception('Altın verisi alınamadı');
      }

      if (!mounted) return;
      setState(() {
        _usd = usd;
        _eur = eur;
        _altin = gramAltin;
        _gumusGram = gumusOnsUsd != null && usdTry != null
            ? (gumusOnsUsd / _troyOnsGram) * usdTry
            : null;
        _dovizYukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dovizYukleniyor = false;
        _dovizHata = 'Kur verisi alınamadı';
      });
    }
  }

  Future<double> _kurGetir(String kod) async {
    final Uri uri = Uri.parse(
      'https://api.frankfurter.dev/v2/rate/$kod/TRY?providers=TCMB',
    );
    final http.Response response =
        await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Kur servisi çalışmıyor');
    }
    final dynamic veri = jsonDecode(response.body);
    final double? oran = _oranBul(veri);
    if (oran == null || oran <= 0) {
      throw Exception('Geçersiz kur');
    }
    return oran;
  }

  double? _oranBul(dynamic veri) {
    if (veri is num) return veri.toDouble();
    if (veri is Map) {
      for (final String anahtar in const <String>['rate', 'value', 'amount']) {
        final dynamic deger = veri[anahtar];
        if (deger is num) return deger.toDouble();
      }
      for (final dynamic deger in veri.values) {
        final double? bulunan = _oranBul(deger);
        if (bulunan != null) return bulunan;
      }
    }
    if (veri is List) {
      for (final dynamic eleman in veri) {
        final double? bulunan = _oranBul(eleman);
        if (bulunan != null) return bulunan;
      }
    }
    return null;
  }

  Future<void> _havaGetir() async {
    if (mounted) {
      setState(() {
        _havaYukleniyor = true;
        _havaHata = null;
      });
    }

    if (widget.mevcutEnlem == null || widget.mevcutBoylam == null) {
      if (!mounted) return;
      setState(() {
        _havaYukleniyor = false;
        _havaHata = 'Konum bekleniyor';
      });
      return;
    }

    try {
      final Uri uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': widget.mevcutEnlem!.toStringAsFixed(6),
        'longitude': widget.mevcutBoylam!.toStringAsFixed(6),
        'current': 'temperature_2m,weather_code,is_day',
        'timezone': 'auto',
      });
      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Hava durumu alınamadı');
      }
      final dynamic veri = jsonDecode(response.body);
      final Map<String, dynamic>? current =
          veri is Map && veri['current'] is Map
              ? Map<String, dynamic>.from(veri['current'] as Map)
              : null;
      if (current == null) {
        throw Exception('Hava verisi yok');
      }
      if (!mounted) return;
      setState(() {
        _havaCode = (current['weather_code'] as num?)?.toInt() ?? 0;
        _havaSicaklik = (current['temperature_2m'] as num?)?.round();
        _havaGunduz = ((current['is_day'] as num?)?.toInt() ?? 1) == 1;
        _havaYukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _havaYukleniyor = false;
        _havaHata = 'Hava verisi alınamadı';
      });
    }
  }

  Future<void> _akaryakitGetir() async {
    if (mounted) {
      setState(() {
        _akaryakitYukleniyor = true;
        _akaryakitHata = null;
      });
    }

    if (widget.il.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _akaryakitYukleniyor = false;
        _akaryakitHata = 'İl bilgisi yok';
      });
      return;
    }

    try {
      final AkaryakitFiyatlari sonuc = await _akaryakitServisi.getir(
        il: widget.il,
        ilce: widget.ilce,
      );

      if (!mounted) return;
      setState(() {
        _benzin = sonuc.benzin;
        _motorin = sonuc.motorin;
        _lpg = sonuc.lpg;
        _akaryakitTarih = sonuc.tarih;
        _akaryakitYukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _akaryakitYukleniyor = false;
        _akaryakitHata = 'Fiyat verisi alınamadı';
      });
    }
  }

  String _kurYaz(double? value) {
    if (value == null) return '--';
    return value >= 100 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
  }

  String _havaAciklamasi(int? code) {
    final int c = code ?? -1;
    if (c == 0) return 'Açık';
    if (c == 1) return 'Az Bulutlu';
    if (c == 2) return 'Parçalı Bulutlu';
    if (c == 3) return 'Çok Bulutlu';
    if (c <= 48) return 'Sisli';
    if (c <= 67) return 'Yağmurlu';
    if (c <= 77) return 'Karlı';
    if (c <= 82) return 'Sağanak';
    if (c <= 86) return 'Kar Sağanağı';
    return 'Fırtınalı';
  }

  List<Color> _havaRenkleri() {
    final int c = _havaCode ?? 0;
    if (!_havaGunduz) {
      return const <Color>[Color(0xFF08111D), Color(0xFF17304B), Color(0xFF365C82)];
    }
    if (c == 0) {
      return const <Color>[Color(0xFF58B7FF), Color(0xFF9ADBFF), Color(0xFFEAF8FF)];
    }
    if (c == 1 || c == 2) {
      return const <Color>[Color(0xFF6DBDFF), Color(0xFFA1D3FF), Color(0xFFDDEEFF)];
    }
    if (c == 3) {
      return const <Color>[Color(0xFF6A7582), Color(0xFF94A0A8), Color(0xFFC9D3D9)];
    }
    if (c >= 51 && c <= 99) {
      return const <Color>[Color(0xFF51606C), Color(0xFF7B8D98), Color(0xFFADB9C1)];
    }
    return const <Color>[Color(0xFF7DA6C4), Color(0xFFB8CDD8), Color(0xFFE6EFF3)];
  }

  String get _konumMetni {
    if (widget.ilce.trim().isNotEmpty && widget.il.trim().isNotEmpty) {
      return '${widget.ilce}, ${widget.il}';
    }
    if (widget.il.trim().isNotEmpty) return widget.il;
    return widget.gpsKonumu ? 'Mevcut Konum' : 'Konum Bekleniyor';
  }

  void _eczaneHaritasiniAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YakinHizmetlerHaritasi(
          eczaneler: widget.eczaneler,
          veterinerler: widget.veterinerler,
          cekiciler: const <Hizmet>[],
          sarjIstasyonlari: widget.sarjIstasyonlari,
          otoLastikler: const <Hizmet>[],
          cilingirler: const <Hizmet>[],
          digerHizmetler: widget.digerHizmetler,
          mevcutEnlem: widget.mevcutEnlem,
          mevcutBoylam: widget.mevcutBoylam,
          gpsKonumu: widget.gpsKonumu,
          il: widget.gpsKonumu ? '' : widget.il,
          ilce: widget.gpsKonumu ? '' : widget.ilce,
          baslangicKategori: 'Nöbetçi Eczane',
        ),
      ),
    );
  }

  void _dovizDetayaGit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DovizKurlariEkrani()),
    );
  }

  void _havaDetayaGit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HavaDurumuEkrani(
          baslangicIl: widget.il,
          baslangicIlce: widget.ilce,
          baslangicEnlem: widget.mevcutEnlem,
          baslangicBoylam: widget.mevcutBoylam,
          gpsKonumu: widget.gpsKonumu,
        ),
      ),
    );
  }

  void _akaryakitDetayaGit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AkaryakitFiyatlariEkrani(
          baslangicIl: widget.il,
          baslangicIlce: widget.ilce,
          gpsKonumu: widget.gpsKonumu,
        ),
      ),
    );
  }

  void _yakindakiHaritayiAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YakinHizmetlerHaritasi(
          eczaneler: widget.eczaneler,
          veterinerler: widget.veterinerler,
          cekiciler: const <Hizmet>[],
          sarjIstasyonlari: widget.sarjIstasyonlari,
          otoLastikler: const <Hizmet>[],
          cilingirler: const <Hizmet>[],
          digerHizmetler: widget.digerHizmetler,
          mevcutEnlem: widget.mevcutEnlem,
          mevcutBoylam: widget.mevcutBoylam,
          gpsKonumu: widget.gpsKonumu,
          il: widget.gpsKonumu ? '' : widget.il,
          ilce: widget.gpsKonumu ? '' : widget.ilce,
        ),
      ),
    );
  }

  void _acilEkraniniAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AcilHatlar(),
      ),
    );
  }

  Hizmet? _kategoriIlki(String kategori) {
    for (final Hizmet hizmet in widget.digerHizmetler) {
      if (hizmet.kategori == kategori) return hizmet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaPlan,
      body: SafeArea(
        child: RefreshIndicator(
          color: _kirmizi,
          backgroundColor: _kart,
          onRefresh: _verileriYukle,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Material(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _acikYazi,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'HERŞEY BURADA!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _acikYazi,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kirmizi.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.widgets_rounded,
                        color: _kirmizi,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _konumMetni,
                            style: const TextStyle(
                              color: _acikYazi,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'En önemli bilgileri tek ekranda gör, kartlara dokunarak detaylara geç.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 10.4,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.92,
                children: <Widget>[
                  _eczaneKarti(),
                  _yakindakiKarti(),
                  _acilKarti(),
                  _havaKarti(),
                  _akaryakitKarti(),
                  _dovizKarti(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kartSablon({
    required Widget child,
    required VoidCallback? onTap,
    Color? renk,
    Gradient? gradient,
    List<BoxShadow>? shadows,
    EdgeInsetsGeometry padding = const EdgeInsets.all(11),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: gradient == null ? _kart : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (renk ?? Colors.white).withValues(alpha: 0.10),
            ),
            boxShadow: shadows,
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _baslikSatiri(IconData icon, String text, Color renk) {
    return Row(
      children: <Widget>[
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: renk, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _acikYazi,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eczaneKarti() {
    return _kartSablon(
      onTap: _eczaneHaritasiniAc,
      renk: _kirmizi,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF251214),
          _kirmiziYumusak.withValues(alpha: 0.35),
          const Color(0xFF141112),
        ],
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: _kirmizi.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _baslikSatiri(Icons.local_pharmacy_rounded, 'Nöbetçi Eczane', _kirmizi),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  '${widget.eczaneler.length}',
                  style: const TextStyle(
                    color: _acikYazi,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.gpsKonumu
                        ? 'yakın nöbetçi eczane'
                        : 'seçili yerde nöbetçi eczane',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.gpsKonumu
                ? 'Bulunduğunuz konuma göre hızlı erişim.'
                : 'Seçili il / ilçe merkezine göre hızlı erişim.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 10.2,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.eczaneler.isNotEmpty
                  ? widget.eczaneler.take(2).map((e) => e.isim).join(' • ')
                  : 'Dokununca haritada nöbetçi eczaneler direkt açılır.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF3DCDD),
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dovizKarti() {
    return _kartSablon(
      onTap: _dovizDetayaGit,
      renk: _yesil,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF122018),
          _yesilYumusak.withValues(alpha: 0.32),
          const Color(0xFF111512),
        ],
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: _yesil.withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _baslikSatiri(Icons.currency_exchange_rounded, 'Döviz', _yesil),
          const SizedBox(height: 12),
          if (_dovizYukleniyor)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _yesil, strokeWidth: 2.4),
              ),
            )
          else if (_dovizHata != null)
            Expanded(
              child: Center(
                child: Text(
                  _dovizHata!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: <Widget>[
                  _renkliMiniSatir('Dolar', '${_kurYaz(_usd)} ₺', _yesil),
                  _renkliMiniSatir('Euro', '${_kurYaz(_eur)} ₺', _yesil),
                  _renkliMiniSatir('Altın', '${_kurYaz(_altin)} ₺', _yesil),
                  _renkliMiniSatir('Gümüş', '${_kurYaz(_gumusGram)} ₺', _yesil),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Detay için karta dokun.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _havaKarti() {
    return _kartSablon(
      onTap: _havaDetayaGit,
      renk: _mavi,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _havaRenkleri(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hava Durumu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_havaYukleniyor)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
              ),
            )
          else if (_havaHata != null)
            Expanded(
              child: Center(
                child: Text(
                  _havaHata!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${_havaSicaklik ?? '--'}°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _havaAciklamasi(_havaCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _konumMetni,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Detaylı hava ekranı için dokun.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _akaryakitKarti() {
    return _kartSablon(
      onTap: _akaryakitGetir,
      renk: _sari,
      padding: const EdgeInsets.all(7),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFDDE2E6),
          Color(0xFF929BA4),
          Color(0xFFCDD2D6),
        ],
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _celikKoyu.withValues(alpha: 0.70),
          ),
        ),
        child: Column(
          children: <Widget>[
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_gas_station_rounded,
                      color: _kirmizi,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Akaryakıt',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF171717),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
                child: _akaryakitYukleniyor
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _kirmizi,
                          strokeWidth: 2.2,
                        ),
                      )
                    : _akaryakitHata != null
                        ? Center(
                            child: Text(
                              _akaryakitHata!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 9.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Column(
                            children: <Widget>[
                              _akaryakitNeonSatir(
                                'BENZIN',
                                _kurYaz(_benzin),
                              ),
                              const SizedBox(height: 5),
                              _akaryakitNeonSatir(
                                'MOTORIN',
                                _kurYaz(_motorin),
                              ),
                              const SizedBox(height: 5),
                              _akaryakitNeonSatir(
                                'LPG',
                                _kurYaz(_lpg),
                              ),
                              const Spacer(),
                              Text(
                                'Dokun → fiyatları yenile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.46),
                                  fontSize: 8.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _yakindakiKarti() {
    final Hizmet? hastane = _kategoriIlki('Hastane');
    final Hizmet? atm = _kategoriIlki('ATM');
    final Hizmet? taksi = _kategoriIlki('Taksi');

    return _kartSablon(
      onTap: _yakindakiHaritayiAc,
      renk: _mor,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF17152A),
          Color(0xFF27234B),
          Color(0xFF11121B),
        ],
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: _mor.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _baslikSatiri(
            Icons.near_me_rounded,
            'Yakınımdakiler',
            _mor,
          ),
          const SizedBox(height: 9),
          _yakindakiSatir(
            Icons.local_hospital_rounded,
            const Color(0xFF5AA7FF),
            'Hastane',
            hastane,
          ),
          const SizedBox(height: 6),
          _yakindakiSatir(
            Icons.local_atm_rounded,
            const Color(0xFFA994FF),
            'ATM',
            atm,
          ),
          const SizedBox(height: 6),
          _yakindakiSatir(
            Icons.local_taxi_rounded,
            const Color(0xFFFFC04D),
            'Taksi',
            taksi,
          ),
          const Spacer(),
          Text(
            'Tüm yakın hizmetleri haritada gör',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acilKarti() {
    final Hizmet? hastane = _kategoriIlki('Hastane');

    return _kartSablon(
      onTap: _acilEkraniniAc,
      renk: _turuncu,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFF281710),
          Color(0xFF3A1B17),
          Color(0xFF151111),
        ],
      ),
      shadows: <BoxShadow>[
        BoxShadow(
          color: _turuncu.withValues(alpha: 0.07),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _baslikSatiri(
            Icons.emergency_rounded,
            'Acil',
            _turuncu,
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _turuncu.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Text(
                  '112',
                  style: TextStyle(
                    color: Color(0xFFFFB27E),
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Acil Çağrı\nMerkezi',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.91),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Ambulans • Polis • İtfaiye',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 9.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.local_hospital_outlined,
                  color: Color(0xFFFFA46B),
                  size: 13,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    hastane == null
                        ? 'En yakın hastane bilgisi yok'
                        : '${hastane.isim} • ${hastane.mesafe}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 8.7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yakindakiSatir(
    IconData ikon,
    Color renk,
    String baslik,
    Hizmet? hizmet,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.055),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(ikon, color: renk, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hizmet?.isim ?? baslik,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 9.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            hizmet?.mesafe ?? '--',
            maxLines: 1,
            style: TextStyle(
              color: renk.withValues(alpha: 0.95),
              fontSize: 8.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renkliMiniSatir(String baslik, String deger, Color vurgu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              baslik,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            deger,
            style: TextStyle(
              color: _acikYazi,
              fontSize: 11.8,
              fontWeight: FontWeight.w900,
              shadows: <Shadow>[
                Shadow(
                  color: vurgu.withValues(alpha: 0.16),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _akaryakitNeonSatir(String etiket, String fiyat) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _panelSiyah,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              etiket,
              maxLines: 1,
              style: const TextStyle(
                color: _acikYazi,
                fontSize: 9.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.35,
              ),
            ),
          ),
          Text(
            fiyat,
            style: TextStyle(
              color: _kirmizi,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              shadows: <Shadow>[
                Shadow(
                  color: _kirmizi.withValues(alpha: 0.70),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

