import 'package:flutter/material.dart';

import '../services/akaryakit_servisi.dart';

class AkaryakitFiyatlariEkrani extends StatefulWidget {
  final String baslangicIl;
  final String baslangicIlce;
  final bool gpsKonumu;

  const AkaryakitFiyatlariEkrani({
    super.key,
    required this.baslangicIl,
    required this.baslangicIlce,
    required this.gpsKonumu,
  });

  @override
  State<AkaryakitFiyatlariEkrani> createState() =>
      _AkaryakitFiyatlariEkraniState();
}

class _AkaryakitFiyatlariEkraniState extends State<AkaryakitFiyatlariEkrani> {
  static const Color _arkaPlan = Color(0xFF080808);
  static const Color _celik = Color(0xFF9EA5AE);
  static const Color _koyuCelik = Color(0xFF5E6670);
  static const Color _panelSiyah = Color(0xFF0A0A0A);
  static const Color _neonKirmizi = Color(0xFFE3262E);
  static const Color _beyaz = Color(0xFFF7F7F7);
  static const String _ikonYolu = 'assets/enobet_splash_icon.png';

  final AkaryakitServisi _akaryakitServisi = AkaryakitServisi();

  bool _yukleniyor = true;
  String? _hata;
  _AkaryakitSonucu? _sonuc;

  String get _il => widget.baslangicIl.trim();
  String get _ilce => widget.baslangicIlce.trim();

  @override
  void initState() {
    super.initState();
    _fiyatlariGetir();
  }

  Future<void> _fiyatlariGetir() async {
    if (_il.isEmpty) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _sonuc = null;
        _hata =
            'Akaryakıt fiyatlarını göstermek için önce ana sayfadan konumunuzu belirleyin veya il / ilçe seçin.';
      });
      return;
    }

    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final AkaryakitFiyatlari veri = await _akaryakitServisi.getir(
        il: _il,
        ilce: _ilce,
      );

      if (!mounted) return;
      setState(() {
        _sonuc = _AkaryakitSonucu(
          benzin: veri.benzin,
          motorin: veri.motorin,
          lpg: veri.lpg,
          tarih: veri.tarih,
          benzinAdet: veri.benzin == null ? 0 : 1,
          motorinAdet: veri.motorin == null ? 0 : 1,
          lpgAdet: veri.lpg == null ? 0 : 1,
        );
        _hata = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sonuc = null;
        _hata =
            'Güncel akaryakıt fiyatları şu anda alınamadı. Lütfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _yukleniyor = false;
        });
      }
    }
  }

  _AkaryakitSonucu _veriyiCoz(dynamic decoded) {
    final Map<_YakitTuru, Set<double>> bulunan = <_YakitTuru, Set<double>>{
      _YakitTuru.benzin: <double>{},
      _YakitTuru.motorin: <double>{},
      _YakitTuru.lpg: <double>{},
    };

    String? tarih;

    void fiyatEkle(_YakitTuru tur, dynamic value) {
      final double? fiyat = _fiyataCevir(value);
      if (fiyat == null) return;
      bulunan[tur]!.add(double.parse(fiyat.toStringAsFixed(3)));
    }

    void tara(dynamic node, {String? ustEtiket}) {
      if (node is List) {
        for (final dynamic item in node) {
          tara(item, ustEtiket: ustEtiket);
        }
        return;
      }

      if (node is! Map) return;

      final Map<dynamic, dynamic> map = node;

      String etiket = ustEtiket ?? '';
      for (final dynamic key in map.keys) {
        final String anahtar = _duzenle(key.toString());
        if (_etiketAnahtari(anahtar)) {
          final dynamic value = map[key];
          if (value is String || value is num) {
            etiket = '$etiket ${value.toString()}'.trim();
          }
        }

        if (tarih == null && _tarihAnahtari(anahtar)) {
          final String aday = map[key]?.toString().trim() ?? '';
          if (aday.isNotEmpty && aday.length <= 40) {
            tarih = aday;
          }
        }
      }

      final _YakitTuru? nesneTuru = _yakitTuru(etiket);
      if (nesneTuru != null) {
        for (final dynamic key in map.keys) {
          final String anahtar = _duzenle(key.toString());
          if (_fiyatAnahtari(anahtar)) {
            fiyatEkle(nesneTuru, map[key]);
          }
        }
      }

      for (final MapEntry<dynamic, dynamic> entry in map.entries) {
        final String anahtar = entry.key.toString();
        final _YakitTuru? tur = _yakitTuru(anahtar);
        if (tur != null) {
          final double? direkt = _fiyataCevir(entry.value);
          if (direkt != null) {
            fiyatEkle(tur, direkt);
          } else {
            final double? icFiyat = _icFiyatBul(entry.value);
            if (icFiyat != null) fiyatEkle(tur, icFiyat);
          }
        }
      }

      for (final MapEntry<dynamic, dynamic> entry in map.entries) {
        final String yeniEtiket = _yakitTuru(entry.key.toString()) != null
            ? entry.key.toString()
            : etiket;
        tara(entry.value, ustEtiket: yeniEtiket);
      }
    }

    tara(decoded);

    return _AkaryakitSonucu(
      benzin: _ortalama(bulunan[_YakitTuru.benzin]!),
      motorin: _ortalama(bulunan[_YakitTuru.motorin]!),
      lpg: _ortalama(bulunan[_YakitTuru.lpg]!),
      tarih: tarih,
      benzinAdet: bulunan[_YakitTuru.benzin]!.length,
      motorinAdet: bulunan[_YakitTuru.motorin]!.length,
      lpgAdet: bulunan[_YakitTuru.lpg]!.length,
    );
  }

  double? _icFiyatBul(dynamic node) {
    if (node is num || node is String) return _fiyataCevir(node);
    if (node is! Map) return null;

    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      final String key = _duzenle(entry.key.toString());
      if (_fiyatAnahtari(key)) {
        final double? fiyat = _fiyataCevir(entry.value);
        if (fiyat != null) return fiyat;
      }
    }
    return null;
  }

  double? _fiyataCevir(dynamic value) {
    if (value is num) {
      final double fiyat = value.toDouble();
      return fiyat >= 1 && fiyat <= 200 ? fiyat : null;
    }

    if (value is! String) return null;

    String text = value.trim();
    if (text.isEmpty) return null;

    text = text
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .replaceAll('tl', '')
        .replaceAll(RegExp(r'[^0-9,\.]'), '');

    if (text.isEmpty) return null;

    if (text.contains(',') && text.contains('.')) {
      if (text.lastIndexOf(',') > text.lastIndexOf('.')) {
        text = text.replaceAll('.', '').replaceAll(',', '.');
      } else {
        text = text.replaceAll(',', '');
      }
    } else {
      text = text.replaceAll(',', '.');
    }

    final double? fiyat = double.tryParse(text);
    if (fiyat == null || !fiyat.isFinite || fiyat < 1 || fiyat > 200) {
      return null;
    }
    return fiyat;
  }

  double? _ortalama(Set<double> fiyatlar) {
    if (fiyatlar.isEmpty) return null;
    final double toplam = fiyatlar.fold<double>(0, (a, b) => a + b);
    return toplam / fiyatlar.length;
  }

  _YakitTuru? _yakitTuru(String value) {
    final String text = _duzenle(value);

    if (text.contains('lpg') ||
        text.contains('otogaz') ||
        text.contains('oto gaz')) {
      return _YakitTuru.lpg;
    }

    if (text.contains('motorin') ||
        text.contains('dizel') ||
        text.contains('diesel') ||
        text.contains('mazot')) {
      return _YakitTuru.motorin;
    }

    if (text.contains('benzin') ||
        text.contains('gasoline') ||
        text.contains('95 oktan') ||
        text.contains('kursunsuz')) {
      return _YakitTuru.benzin;
    }

    return null;
  }

  bool _etiketAnahtari(String key) =>
      key == 'yakit' ||
      key == 'fuel' ||
      key == 'urun' ||
      key == 'product' ||
      key == 'tur' ||
      key == 'type' ||
      key == 'name' ||
      key == 'ad' ||
      key == 'isim';

  bool _fiyatAnahtari(String key) =>
      key.contains('fiyat') ||
      key.contains('price') ||
      key.contains('satis') ||
      key == 'value' ||
      key == 'litre' ||
      key == 'liter';

  bool _tarihAnahtari(String key) =>
      key.contains('tarih') ||
      key.contains('date') ||
      key.contains('updated') ||
      key.contains('guncelle');

  String _duzenle(String text) => text
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();

  String _slug(String text) => _duzenle(text)
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String _neonFiyat(double? fiyat) {
    if (fiyat == null) return '--,--';
    return fiyat.toStringAsFixed(2).replaceAll('.', ',');
  }

  String get _konumBasligi {
    if (_il.isEmpty) return 'Konum belirlenmedi';
    if (_ilce.isEmpty) return _il;
    return '$_il • $_ilce';
  }

  String get _konumAciklamasi {
    if (_il.isEmpty) return 'Önce konum seçin';
    if (widget.gpsKonumu) {
      return 'Bulunduğunuz ile ait güncel akaryakıt fiyatları';
    }
    return 'Seçtiğiniz ile ait güncel akaryakıt fiyatları';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaPlan,
      body: SafeArea(
        child: RefreshIndicator(
          color: _neonKirmizi,
          backgroundColor: _panelSiyah,
          onRefresh: _fiyatlariGetir,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: <Widget>[
              _ustBar(),
              const SizedBox(height: 14),
              _konumKarti(),
              const SizedBox(height: 18),
              _anaTabela(),
              const SizedBox(height: 16),
              _bilgiKarti(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ustBar() {
    return Row(
      children: <Widget>[
        _camButon(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Text(
            'Akaryakıt Fiyatları',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _beyaz,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _camButon(
          icon: Icons.refresh_rounded,
          onTap: _yukleniyor ? null : _fiyatlariGetir,
        ),
      ],
    );
  }

  Widget _camButon({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _konumKarti() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.gpsKonumu
                  ? Icons.my_location_rounded
                  : Icons.location_on_rounded,
              color: _beyaz,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _konumBasligi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _beyaz,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _konumAciklamasi,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.3,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anaTabela() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFDDE3E8), Color(0xFF8E97A1), Color(0xFFCDD3D8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _celik.withValues(alpha: 0.65), width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _koyuCelik.withValues(alpha: 0.70)),
        ),
        child: Column(
          children: <Widget>[
            _tabelaUstu(),
            Container(height: 2, color: const Color(0xFF2E2E2E)),
            _tabelaEkrani(),
          ],
        ),
      ),
    );
  }

  Widget _tabelaUstu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: _beyaz,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: <Widget>[
          Image.asset(
            _ikonYolu,
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'E',
                  style: TextStyle(
                    color: _neonKirmizi,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'Nöbet',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _il.isEmpty ? 'ŞEHİR' : _il.toUpperCase(),
              style: const TextStyle(
                color: _beyaz,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabelaEkrani() {
    if (_yukleniyor) {
      return SizedBox(
        height: 286,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: _neonKirmizi,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              _neonMetin(
                'GÜNCEL FİYATLAR',
                fontSize: 15,
                alpha: 0.88,
              ),
              const SizedBox(height: 5),
              Text(
                'yükleniyor...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hata != null) {
      return SizedBox(
        height: 286,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.signal_wifi_connected_no_internet_4_rounded,
                color: _neonKirmizi,
                size: 42,
              ),
              const SizedBox(height: 14),
              _neonMetin('VERİ ALINAMADI', fontSize: 17),
              const SizedBox(height: 10),
              Text(
                _hata!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fiyatlariGetir,
                style: FilledButton.styleFrom(
                  backgroundColor: _neonKirmizi,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Tekrar Dene',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final _AkaryakitSonucu sonuc = _sonuc!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _panelSiyah,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _neonKirmizi.withValues(alpha: 0.05),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _fiyatSatiri(
            etiket: 'BENZIN',
            fiyat: sonuc.benzin,
            renk: _neonKirmizi,
          ),
          const SizedBox(height: 10),
          _fiyatSatiri(
            etiket: 'MOTORIN',
            fiyat: sonuc.motorin,
            renk: _neonKirmizi,
          ),
          const SizedBox(height: 10),
          _fiyatSatiri(
            etiket: 'LPG',
            fiyat: sonuc.lpg,
            renk: _neonKirmizi,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Birim: TL / Litre',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if ((sonuc.tarih ?? '').trim().isNotEmpty)
                Text(
                  'Tarih: ${sonuc.tarih!.trim()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.54),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fiyatSatiri({
    required String etiket,
    required double? fiyat,
    required Color renk,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              etiket,
              style: const TextStyle(
                color: _beyaz,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: renk.withValues(alpha: 0.38)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: renk.withValues(alpha: 0.18),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _neonFiyat(fiyat),
                  style: TextStyle(
                    color: renk,
                    fontSize: 28,
                    height: 0.98,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    shadows: <Shadow>[
                      Shadow(
                        color: renk.withValues(alpha: 0.86),
                        blurRadius: 12,
                      ),
                      Shadow(
                        color: renk.withValues(alpha: 0.36),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'TL',
                  style: TextStyle(
                    color: renk.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                    shadows: <Shadow>[
                      Shadow(
                        color: renk.withValues(alpha: 0.78),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _neonMetin(String text, {double fontSize = 18, double alpha = 1}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _neonKirmizi.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
        shadows: <Shadow>[
          Shadow(
            color: _neonKirmizi.withValues(alpha: 0.82 * alpha),
            blurRadius: 10,
          ),
          Shadow(
            color: _neonKirmizi.withValues(alpha: 0.30 * alpha),
            blurRadius: 22,
          ),
        ],
      ),
    );
  }

  Widget _bilgiKarti() {
    final String tarih = _sonuc?.tarih?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded, color: _beyaz, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Bilgilendirme',
                style: TextStyle(
                  color: _beyaz,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Bu ekran, benzin istasyonu giriş tabelası havasında tasarlandı. '
            'Gösterilen değerler seçili il için çevrimiçi servisten alınan güncel akaryakıt fiyatlarıdır. '
            'İstasyona, markaya ve anlık değişime göre küçük farklar olabilir.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 11.2,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tarih.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Veri tarihi: $tarih',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 10.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Kaynak: Petrol Ofisi güncel fiyatları',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _YakitTuru { benzin, motorin, lpg }

class _AkaryakitSonucu {
  final double? benzin;
  final double? motorin;
  final double? lpg;
  final String? tarih;
  final int benzinAdet;
  final int motorinAdet;
  final int lpgAdet;

  const _AkaryakitSonucu({
    required this.benzin,
    required this.motorin,
    required this.lpg,
    required this.tarih,
    required this.benzinAdet,
    required this.motorinAdet,
    required this.lpgAdet,
  });

  bool get veriVar => benzin != null || motorin != null || lpg != null;
}
