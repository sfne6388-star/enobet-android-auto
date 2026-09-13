import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DovizKurlariEkrani extends StatefulWidget {
  const DovizKurlariEkrani({super.key});

  @override
  State<DovizKurlariEkrani> createState() => _DovizKurlariEkraniState();
}

class _DovizKurlariEkraniState extends State<DovizKurlariEkrani> {
  static const Color _arka = Color(0xFF070707);
  static const Color _kart = Color(0xFF111111);
  static const Color _yesil = Color(0xFF22C55E);
  static const Color _kirmizi = Color(0xFFE3262E);
  static const Color _altin = Color(0xFFFFC107);
  static const Color _gumus = Color(0xFFBFC5CC);
  static const Color _bronz = Color(0xFFCD7F32);

  static const double _troyOnsGram = 31.1034768;
  static const double _ceyrekZiynetGram = 1.754;
  static const double _ceyrekZiynetMilyem = 0.9166;

  final Map<String, double> _kurlar = <String, double>{};
  final Map<String, double> _oncekiKurlar = <String, double>{};
  final Map<String, double> _metaller = <String, double>{};
  final Map<String, double> _oncekiMetaller = <String, double>{};

  Timer? _timer;
  bool _yukleniyor = true;
  String? _hata;
  DateTime? _sonKontrol;
  String? _acikMetal;

  final TextEditingController _miktar = TextEditingController(text: '1');
  String _kaynakPara = 'USD';
  String _hedefPara = 'TRY';

  static const List<_Para> _paralar = <_Para>[
    _Para('USD', 'Dolar', '\$', '🇺🇸'),
    _Para('EUR', 'Euro', '€', '🇪🇺'),
    _Para('GBP', 'Sterlin', '£', '🇬🇧'),
  ];

  static const List<_Metal> _metalKartlari = <_Metal>[
    _Metal(
      'ALTIN',
      'Altın',
      'Gram ve Çeyrek',
      'Au',
      _altin,
      Icons.workspace_premium_rounded,
    ),
    _Metal(
      'GUMUS',
      'Gümüş',
      'Gram',
      'Ag',
      _gumus,
      Icons.circle_rounded,
    ),
    _Metal(
      'BRONZ',
      'Bronz',
      'Gram',
      'Br',
      _bronz,
      Icons.hexagon_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _kurlariGetir();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _kurlariGetir(sessiz: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _miktar.dispose();
    super.dispose();
  }

  Future<void> _kurlariGetir({bool sessiz = false}) async {
    if (!sessiz && mounted) {
      setState(() {
        _yukleniyor = true;
        _hata = null;
      });
    }

    final Map<String, double> yeniKurlar = <String, double>{};
    final Map<String, double> yeniMetaller = <String, double>{};
    final List<String> hatalar = <String>[];

    try {
      for (final _Para para in _paralar) {
        final Uri uri = Uri.parse(
          'https://api.frankfurter.dev/v2/rate/${para.kod}/TRY?providers=TCMB',
        );

        final http.Response response =
            await http.get(uri).timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          throw Exception('Kur servisi ${response.statusCode} yanıtı verdi.');
        }

        final dynamic veri = jsonDecode(response.body);
        final double? oran = _oranBul(veri);

        if (oran == null || oran <= 0) {
          throw Exception('${para.kod}/TRY kuru okunamadı.');
        }

        yeniKurlar[para.kod] = oran;
      }
    } catch (_) {
      hatalar.add('Döviz');
    }

    try {
      final Uri uri = Uri.parse(
        'https://xaus.com/api/v1/spot?currency=TRY&unit=gram',
      );

      final http.Response response =
          await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Metal servisi ${response.statusCode} yanıtı verdi.');
      }

      final dynamic veri = jsonDecode(response.body);
      if (veri is! Map) {
        throw Exception('Metal verisi geçersiz.');
      }

      final dynamic xau = veri['xau'];
      final double? gramAltin =
          xau is Map && xau['price'] is num ? (xau['price'] as num).toDouble() : null;
      final double? gumusOnsUsd = veri['silver_usd_oz'] is num
          ? (veri['silver_usd_oz'] as num).toDouble()
          : null;
      final double? usdTry = veri['fx_rate'] is num
          ? (veri['fx_rate'] as num).toDouble()
          : null;

      if (gramAltin == null || gramAltin <= 0) {
        throw Exception('Gram altın değeri okunamadı.');
      }

      yeniMetaller['ALTIN_GRAM'] = gramAltin;
      yeniMetaller['ALTIN_CEYREK'] =
          gramAltin * _ceyrekZiynetGram * _ceyrekZiynetMilyem;

      if (gumusOnsUsd != null &&
          gumusOnsUsd > 0 &&
          usdTry != null &&
          usdTry > 0) {
        yeniMetaller['GUMUS_GRAM'] =
            (gumusOnsUsd / _troyOnsGram) * usdTry;
      }
    } catch (_) {
      hatalar.add('Altın/Gümüş');
    }

    if (!mounted) return;

    setState(() {
      if (yeniKurlar.isNotEmpty) {
        _oncekiKurlar
          ..clear()
          ..addAll(_kurlar);
        _kurlar
          ..clear()
          ..addAll(yeniKurlar);
      }

      if (yeniMetaller.isNotEmpty) {
        _oncekiMetaller
          ..clear()
          ..addAll(_metaller);
        _metaller
          ..clear()
          ..addAll(yeniMetaller);
      }

      if (yeniKurlar.isNotEmpty || yeniMetaller.isNotEmpty) {
        _sonKontrol = DateTime.now();
      }

      _yukleniyor = false;

      if (hatalar.isEmpty) {
        _hata = null;
      } else if (_kurlar.isEmpty && _metaller.isEmpty) {
        _hata =
            'Döviz ve metal verileri şu anda alınamadı. İnternet bağlantını kontrol edip tekrar dene.';
      } else {
        _hata =
            '${hatalar.join(' ve ')} verisi yenilenemedi. Son alınan değerler gösteriliyor.';
      }
    });
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

  String _kurYaz(double deger) {
    if (deger < 1) return deger.toStringAsFixed(4);
    return deger.toStringAsFixed(3);
  }

  String _fiyatYaz(double deger) {
    if (deger >= 1000) return deger.toStringAsFixed(0);
    if (deger >= 100) return deger.toStringAsFixed(1);
    return deger.toStringAsFixed(2);
  }

  String _saatYaz(DateTime? tarih) {
    if (tarih == null) return '--:--';

    final String h = tarih.hour.toString().padLeft(2, '0');
    final String m = tarih.minute.toString().padLeft(2, '0');
    final String s = tarih.second.toString().padLeft(2, '0');

    return '$h:$m:$s';
  }

  double? _tlDegeri(String kod) {
    if (kod == 'TRY') return 1;
    return _kurlar[kod];
  }

  double? get _ceviriSonucu {
    final double? miktar = double.tryParse(_miktar.text.replaceAll(',', '.'));
    final double? kaynak = _tlDegeri(_kaynakPara);
    final double? hedef = _tlDegeri(_hedefPara);

    if (miktar == null || kaynak == null || hedef == null || hedef == 0) {
      return null;
    }

    return miktar * kaynak / hedef;
  }

  @override
  Widget build(BuildContext context) {
    final bool ilkYukleme =
        _yukleniyor && _kurlar.isEmpty && _metaller.isEmpty;

    return Scaffold(
      backgroundColor: _arka,
      body: SafeArea(
        child: RefreshIndicator(
          color: _yesil,
          backgroundColor: _kart,
          onRefresh: _kurlariGetir,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: <Widget>[
              _ustBar(),
              const SizedBox(height: 12),
              _hero(),
              const SizedBox(height: 18),
              if (ilkYukleme)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: _yesil),
                  ),
                )
              else ...<Widget>[
                if (_hata != null) _hataKarti(),
                if (_hata != null) const SizedBox(height: 12),
                const _BolumBasligi('Döviz'),
                const SizedBox(height: 9),
                for (final _Para para in _paralar) ...<Widget>[
                  _kurKarti(para),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                const _BolumBasligi('Değerli Metaller'),
                const SizedBox(height: 9),
                for (final _Metal metal in _metalKartlari) ...<Widget>[
                  _metalKarti(metal),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
                _cevirici(),
                const SizedBox(height: 16),
                _bilgi(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ustBar() {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const Expanded(
          child: Text(
            'Döviz Kurları',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: _yukleniyor ? null : () => _kurlariGetir(),
          icon: const Icon(Icons.refresh_rounded, color: _yesil),
        ),
      ],
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF092015),
            Color(0xFF0C1510),
            Color(0xFF101010),
          ],
        ),
        border: Border.all(color: _yesil.withValues(alpha: 0.28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _yesil.withValues(alpha: 0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _yesil.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              color: _yesil,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Döviz ve Metal Referansları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Dolar • Euro • Sterlin • Altın • Gümüş • Bronz\n'
                  'Son kontrol: ${_saatYaz(_sonKontrol)}',
                  style: const TextStyle(
                    color: Color(0xFF8FA398),
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (_yukleniyor)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _yesil,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kurKarti(_Para para) {
    final double? deger = _kurlar[para.kod];
    final double? onceki = _oncekiKurlar[para.kod];
    final bool yukari = deger != null && onceki != null && deger > onceki;
    final bool asagi = deger != null && onceki != null && deger < onceki;
    final Color hareketRengi =
        yukari ? _yesil : (asagi ? _kirmizi : const Color(0xFF777777));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: _kart,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: <Widget>[
          Text(para.bayrak, style: const TextStyle(fontSize: 27)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  para.ad,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  para.kod,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                deger == null ? '—' : '${_kurYaz(deger)} ₺',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              _hareket(
                yukari: yukari,
                asagi: asagi,
                renk: hareketRengi,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metalKarti(_Metal metal) {
    final bool acik = _acikMetal == metal.kod;

    final String? anaDegerAnahtari = switch (metal.kod) {
      'ALTIN' => 'ALTIN_GRAM',
      'GUMUS' => 'GUMUS_GRAM',
      _ => null,
    };

    final double? anaDeger =
        anaDegerAnahtari == null ? null : _metaller[anaDegerAnahtari];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _kart,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: metal.renk.withValues(alpha: acik ? 0.38 : 0.14),
          width: acik ? 1.2 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () {
              setState(() {
                _acikMetal = acik ? null : metal.kod;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: metal.renk.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: metal.renk.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Icon(metal.ikon, color: metal.renk, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          metal.ad,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          metal.altBaslik,
                          style: TextStyle(
                            color: metal.renk.withValues(alpha: 0.82),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (anaDeger != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_fiyatYaz(anaDeger)} ₺',
                        style: TextStyle(
                          color: metal.renk,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else if (metal.kod == 'BRONZ')
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'Referans',
                        style: TextStyle(
                          color: _bronz,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Icon(
                    acik
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF777777),
                  ),
                ],
              ),
            ),
          ),
          if (acik) ...<Widget>[
            Divider(
              height: 1,
              thickness: 1,
              color: metal.renk.withValues(alpha: 0.12),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _metalDetayi(metal),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metalDetayi(_Metal metal) {
    if (metal.kod == 'ALTIN') {
      return Column(
        children: <Widget>[
          _metalDegerSatiri(
            baslik: 'Gram Altın',
            altBaslik: '1 gram • spot referans',
            deger: _metaller['ALTIN_GRAM'],
            onceki: _oncekiMetaller['ALTIN_GRAM'],
            renk: _altin,
          ),
          const SizedBox(height: 10),
          _metalDegerSatiri(
            baslik: 'Çeyrek Altın',
            altBaslik: '1,754 g • 22 ayar • yaklaşık spot karşılığı',
            deger: _metaller['ALTIN_CEYREK'],
            onceki: _oncekiMetaller['ALTIN_CEYREK'],
            renk: _altin,
          ),
          const SizedBox(height: 9),
          const Text(
            'Çeyrek değeri, Darphane ziynet standardındaki 1,754 g ve '
            '916,6 milyem saflık üzerinden spot altın referansından yaklaşık '
            'hesaplanır. Kuyumcu alış/satış fiyatı değildir.',
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 9.8,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    if (metal.kod == 'GUMUS') {
      return _metalDegerSatiri(
        baslik: 'Gram Gümüş',
        altBaslik: '1 gram • spot referans',
        deger: _metaller['GUMUS_GRAM'],
        onceki: _oncekiMetaller['GUMUS_GRAM'],
        renk: _gumus,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bronz.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bronz.withValues(alpha: 0.16)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Gram Bronz',
            style: TextStyle(
              color: _bronz,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Bronz; bakır, kalay ve bazen başka metallerden oluşan bir alaşımdır. '
            'Altın veya gümüş gibi tek ve standart bir gram spot fiyatı yoktur. '
            'Bu nedenle uygulama burada uydurma bir canlı fiyat göstermiyor.',
            style: TextStyle(
              color: Color(0xFF9A8B82),
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metalDegerSatiri({
    required String baslik,
    required String altBaslik,
    required double? deger,
    required double? onceki,
    required Color renk,
  }) {
    final bool yukari = deger != null && onceki != null && deger > onceki;
    final bool asagi = deger != null && onceki != null && deger < onceki;
    final Color hareketRengi =
        yukari ? _yesil : (asagi ? _kirmizi : const Color(0xFF777777));

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                baslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                altBaslik,
                style: const TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 9.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              deger == null ? '—' : '${_fiyatYaz(deger)} ₺',
              style: TextStyle(
                color: renk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            _hareket(
              yukari: yukari,
              asagi: asagi,
              renk: hareketRengi,
            ),
          ],
        ),
      ],
    );
  }

  Widget _hareket({
    required bool yukari,
    required bool asagi,
    required Color renk,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          yukari
              ? Icons.arrow_upward_rounded
              : asagi
                  ? Icons.arrow_downward_rounded
                  : Icons.remove_rounded,
          size: 13,
          color: renk,
        ),
        const SizedBox(width: 2),
        Text(
          yukari
              ? 'Yükseldi'
              : asagi
                  ? 'Düştü'
                  : 'Değişmedi',
          style: TextStyle(
            color: renk,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _cevirici() {
    const List<String> paraKodlari = <String>['TRY', 'USD', 'EUR', 'GBP'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _yesil.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.calculate_rounded, color: _yesil, size: 21),
              SizedBox(width: 8),
              Text(
                'Döviz Çevirici',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _miktar,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              labelText: 'Miktar',
              labelStyle: const TextStyle(color: Color(0xFF888888)),
              filled: true,
              fillColor: const Color(0xFF181818),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _paraSecici(
                  _kaynakPara,
                  paraKodlari,
                  (String? v) => setState(() => _kaynakPara = v!),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF777777),
                ),
              ),
              Expanded(
                child: _paraSecici(
                  _hedefPara,
                  paraKodlari,
                  (String? v) => setState(() => _hedefPara = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _yesil.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _ceviriSonucu == null
                  ? 'Kur bekleniyor...'
                  : '${_ceviriSonucu!.toStringAsFixed(2)} $_hedefPara',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _yesil,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paraSecici(
    String deger,
    List<String> kodlar,
    ValueChanged<String?> degisti,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: deger,
      dropdownColor: const Color(0xFF181818),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF181818),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: kodlar
          .map(
            (String kod) => DropdownMenuItem<String>(
              value: kod,
              child: Text(kod),
            ),
          )
          .toList(),
      onChanged: degisti,
    );
  }

  Widget _hataKarti() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _kirmizi.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _kirmizi.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, color: _kirmizi, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _hata!,
              style: const TextStyle(
                color: Color(0xFFD9A3A6),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bilgi() {
    return const Text(
      'Döviz kurları TCMB referanslıdır. Altın ve gümüş değerleri spot '
      'referanslardan hesaplanır. Çeyrek altın değeri yaklaşık metal karşılığıdır; '
      'kuyumcu alış/satış fiyatı, işçilik veya piyasa primi içermez. Bronzun '
      'standart tek bir spot gram fiyatı bulunmadığından canlı fiyat gösterilmez.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF666666),
        fontSize: 10.5,
        height: 1.45,
      ),
    );
  }
}

class _Para {
  final String kod;
  final String ad;
  final String sembol;
  final String bayrak;

  const _Para(this.kod, this.ad, this.sembol, this.bayrak);
}

class _Metal {
  final String kod;
  final String ad;
  final String altBaslik;
  final String sembol;
  final Color renk;
  final IconData ikon;

  const _Metal(
    this.kod,
    this.ad,
    this.altBaslik,
    this.sembol,
    this.renk,
    this.ikon,
  );
}

class _BolumBasligi extends StatelessWidget {
  final String metin;

  const _BolumBasligi(this.metin);

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: const TextStyle(
        color: Color(0xFF8C8C8C),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}
