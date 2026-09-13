import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hizmet.dart';
import '../theme/enobet_tema.dart';

class YakinHizmetlerHaritasi extends StatefulWidget {
  final List<Hizmet> eczaneler;
  final List<Hizmet> veterinerler;
  final List<Hizmet> cekiciler;
  final List<Hizmet> sarjIstasyonlari;
  final List<Hizmet> otoLastikler;
  final List<Hizmet> cilingirler;
  final List<Hizmet> digerHizmetler;

  final double? mevcutEnlem;
  final double? mevcutBoylam;

  /// true ise koordinat telefonun gerçek GPS konumudur.
  /// false ise koordinat manuel seçilen il/ilçenin merkezidir.
  final bool gpsKonumu;

  final String? il;
  final String? ilce;
  final String? baslangicKategori;

  const YakinHizmetlerHaritasi({
    super.key,
    required this.eczaneler,
    required this.veterinerler,
    required this.cekiciler,
    required this.sarjIstasyonlari,
    required this.otoLastikler,
    required this.cilingirler,
    this.digerHizmetler = const <Hizmet>[],
    this.mevcutEnlem,
    this.mevcutBoylam,
    this.gpsKonumu = false,
    this.il,
    this.ilce,
    this.baslangicKategori,
  });

  @override
  State<YakinHizmetlerHaritasi> createState() =>
      _YakinHizmetlerHaritasiState();
}

class _YakinHizmetlerHaritasiState extends State<YakinHizmetlerHaritasi>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final AnimationController _pulseController;

  String? _seciliKategori;
  bool _kategoriMenusuAcik = false;

  late LatLng _merkez;
  late double _zoom;

  static const Color _appleMavi = Color(0xFF0A84FF);
  static const Color _enobetKirmizi = Color(0xFFE3262E);

  /// Nöbetçi Eczane burada bilerek yok.
  /// Eczane üst ortadaki ayrı ENöbet düğmesinden açılır.
  static const _kategoriler = <(String, IconData, Color)>[
    ('AVM & Outlet', Icons.local_mall_rounded, Color(0xFFB565F2)),
    ('ATM', Icons.local_atm_rounded, Color(0xFF7A5AF8)),
    ('Otel', Icons.hotel_rounded, Color(0xFF00A6A6)),
    ('Hastane', Icons.local_hospital_rounded, Color(0xFF2F80ED)),
    ('Kargo', Icons.local_shipping_rounded, Color(0xFF8E6CEF)),
    ('Otogar', Icons.directions_bus_rounded, Color(0xFF2677C9)),
    ('Veteriner', Icons.pets_rounded, Color(0xFF20A875)),
    ('Havaalanı', Icons.local_airport_rounded, Color(0xFF5C9DFF)),
    ('Elektrikli Şarj İstasyonu', Icons.ev_station_rounded, Color(0xFFF07800)),
    ('Noter', Icons.gavel_rounded, Color(0xFFB58B5B)),
    ('Taksi', Icons.local_taxi_rounded, Color(0xFFE09B00)),
  ];

  bool get _konumNoktasiVar =>
      widget.mevcutEnlem != null &&
      widget.mevcutBoylam != null &&
      _gecerliKoordinat(widget.mevcutEnlem!, widget.mevcutBoylam!);

  bool get _gercekGpsKonumu => _konumNoktasiVar && widget.gpsKonumu;

  bool _gecerliBaslangicKategori(String? kategori) {
    if (kategori == null || kategori.trim().isEmpty) return false;
    if (kategori == 'Nöbetçi Eczane') return true;
    return _kategoriler.any((item) => item.$1 == kategori);
  }

  static bool _gecerliKoordinat(double enlem, double boylam) {
    return enlem.isFinite &&
        boylam.isFinite &&
        enlem >= -90 &&
        enlem <= 90 &&
        boylam >= -180 &&
        boylam <= 180 &&
        !(enlem == 0 && boylam == 0);
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat();

    _merkeziBaslat();

    if (_gecerliBaslangicKategori(widget.baslangicKategori)) {
      _seciliKategori = widget.baslangicKategori;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _merkeziBaslat() {
    if (_konumNoktasiVar) {
      _merkez = LatLng(widget.mevcutEnlem!, widget.mevcutBoylam!);
      _zoom = widget.gpsKonumu ? 14.7 : 13.8;
      return;
    }

    final List<_HaritaHizmeti> tumu = _tumKayitlar();
    if (tumu.isNotEmpty) {
      final Hizmet ilk = tumu.first.hizmet;
      _merkez = LatLng(ilk.enlem, ilk.boylam);
      _zoom = 12.5;
      return;
    }

    _merkez = const LatLng(39.0, 35.0);
    _zoom = 6.0;
  }

  @override
  void didUpdateWidget(covariant YakinHizmetlerHaritasi oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool koordinatDegisti =
        oldWidget.mevcutEnlem != widget.mevcutEnlem ||
        oldWidget.mevcutBoylam != widget.mevcutBoylam ||
        oldWidget.gpsKonumu != widget.gpsKonumu;

    if (oldWidget.baslangicKategori != widget.baslangicKategori &&
        _gecerliBaslangicKategori(widget.baslangicKategori)) {
      _seciliKategori = widget.baslangicKategori;
    }

    if (!koordinatDegisti) return;

    _merkeziBaslat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(_merkez, _zoom);
    });
  }

  List<_HaritaHizmeti> _tumKayitlar() {
    final List<_HaritaHizmeti> sonuc = [];

    void ekle(
      List<Hizmet> hizmetler,
      String kategori,
      IconData ikon,
      Color renk,
    ) {
      for (final Hizmet hizmet in hizmetler) {
        if (!_gecerliKoordinat(hizmet.enlem, hizmet.boylam)) continue;

        sonuc.add(
          _HaritaHizmeti(
            hizmet: hizmet,
            kategori: kategori,
            ikon: ikon,
            renk: renk,
          ),
        );
      }
    }

    ekle(
      widget.eczaneler,
      'Nöbetçi Eczane',
      Icons.local_pharmacy_rounded,
      _enobetKirmizi,
    );
    ekle(widget.veterinerler, 'Veteriner', Icons.pets_rounded, const Color(0xFF20A875));
    ekle(
      widget.sarjIstasyonlari,
      'Elektrikli Şarj İstasyonu',
      Icons.ev_station_rounded,
      const Color(0xFFF07800),
    );

    const Set<String> aktifDigerKategoriler = <String>{
      'Hastane',
      'ATM',
      'Taksi',
      'Veteriner',
      'Elektrikli Şarj İstasyonu',
      'Kargo',
      'Otogar',
      'Noter',
      'Otel',
    };

    for (final Hizmet hizmet in widget.digerHizmetler) {
      if (!aktifDigerKategoriler.contains(hizmet.kategori)) continue;
      if (!_gecerliKoordinat(hizmet.enlem, hizmet.boylam)) continue;

      sonuc.add(
        _HaritaHizmeti(
          hizmet: hizmet,
          kategori: hizmet.kategori,
          ikon: hizmet.ikon,
          renk: hizmet.renk,
        ),
      );
    }

    return sonuc;
  }

  List<_HaritaHizmeti> _gorunenHizmetler() {
    final String? kategori = _seciliKategori;
    if (kategori == null) return const <_HaritaHizmeti>[];

    return _tumKayitlar()
        .where((kayit) => kayit.kategori == kategori)
        .toList();
  }

  void _kategoriSec(String kategori) {
    setState(() {
      _seciliKategori = kategori;
      _kategoriMenusuAcik = false;
    });
  }

  void _eczaneleriSec() {
    _kategoriSec('Nöbetçi Eczane');
    _nobetciEczaneleriListele();
  }

  double _mesafeDegeri(String metin) {
    final String temiz = metin.toLowerCase().replaceAll(',', '.').trim();
    final Match? eslesme = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(km|m)').firstMatch(temiz);

    if (eslesme == null) return double.infinity;

    final double? sayi = double.tryParse(eslesme.group(1) ?? '');
    if (sayi == null) return double.infinity;

    return eslesme.group(2) == 'km' ? sayi * 1000 : sayi;
  }

  Future<void> _nobetciEczaneleriListele() async {
    final List<Hizmet> sirali = List<Hizmet>.of(widget.eczaneler)
      ..sort(
        (a, b) => _mesafeDegeri(a.mesafe).compareTo(_mesafeDegeri(b.mesafe)),
      );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final tema = sheetContext.enobetTema;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.52,
          minChildSize: 0.30,
          maxChildSize: 0.84,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: tema.kart,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tema.sinir,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 15, 18, 10),
                      child: Row(
                        children: [
                          _yanipSonenE(kucuk: true),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nöbetçi Eczaneler',
                                  style: TextStyle(
                                    color: tema.anaYazi,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${sirali.length} sonuç • yakından uzağa',
                                  style: TextStyle(
                                    color: tema.ikincilYazi,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: tema.sinir),
                    Expanded(
                      child: sirali.isEmpty
                          ? Center(
                              child: Text(
                                'Bu konum için nöbetçi eczane bulunamadı.',
                                style: TextStyle(
                                  color: tema.ikincilYazi,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                              itemCount: sirali.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                indent: 58,
                                color: tema.sinir.withValues(alpha: 0.75),
                              ),
                              itemBuilder: (context, index) {
                                final Hizmet hizmet = sirali[index];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _enobetKirmizi.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'E',
                                        style: TextStyle(
                                          color: _enobetKirmizi,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    hizmet.isim,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tema.anaYazi,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${hizmet.mesafe} • ${hizmet.adres}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tema.ikincilYazi,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: tema.ikincilYazi,
                                  ),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _mapController.move(
                                      LatLng(hizmet.enlem, hizmet.boylam),
                                      16.2,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rotaAc(Hizmet hizmet) async {
    if (!_gecerliKoordinat(hizmet.enlem, hizmet.boylam)) return;

    final double hedefEnlem = hizmet.enlem;
    final double hedefBoylam = hizmet.boylam;

    late final Uri uri;

    /// Manuel il/ilçe merkezini gerçek kullanıcı başlangıcı gibi kullanmıyoruz.
    if (_gercekGpsKonumu) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${widget.mevcutEnlem},${widget.mevcutBoylam}'
        '&destination=$hedefEnlem,$hedefBoylam',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$hedefEnlem,$hedefBoylam',
      );
    }

    final bool acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!acildi) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  void _hizmetBilgileriniGoster(_HaritaHizmeti haritaHizmeti) {
    final Hizmet hizmet = haritaHizmeti.hizmet;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.enobetTema.kart,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final tema = context.enobetTema;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: tema.sinir,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: haritaHizmeti.renk.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: haritaHizmeti.kategori == 'Nöbetçi Eczane'
                            ? const Center(
                                child: Text(
                                  'E',
                                  style: TextStyle(
                                    color: _enobetKirmizi,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : Icon(
                                haritaHizmeti.ikon,
                                color: haritaHizmeti.renk,
                                size: 26,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hizmet.isim,
                              style: TextStyle(
                                color: tema.anaYazi,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              haritaHizmeti.kategori,
                              style: TextStyle(
                                color: haritaHizmeti.renk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (hizmet.adres.trim().isNotEmpty)
                    _bilgiSatiri(Icons.location_on_outlined, 'Adres', hizmet.adres),
                  if (hizmet.calismaSaatleri.trim().isNotEmpty)
                    _bilgiSatiri(
                      Icons.access_time_rounded,
                      'Çalışma Saatleri',
                      hizmet.calismaSaatleri,
                    ),
                  if (hizmet.durum.trim().isNotEmpty)
                    _bilgiSatiri(Icons.info_outline_rounded, 'Durum', hizmet.durum),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _rotaAc(hizmet);
                      },
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('YOL TARİFİ AL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appleMavi,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bilgiSatiri(IconData ikon, String baslik, String deger) {
    final tema = context.enobetTema;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 21, color: tema.ikincilYazi),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: tema.anaYazi,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(deger, style: TextStyle(color: tema.ikincilYazi)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _markerlar() {
    return _gorunenHizmetler().map((haritaHizmeti) {
      final Hizmet hizmet = haritaHizmeti.hizmet;

      return Marker(
        point: LatLng(hizmet.enlem, hizmet.boylam),
        width: 168,
        height: 82,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _hizmetBilgileriniGoster(haritaHizmeti),
          child: _hizmetIsareti(haritaHizmeti),
        ),
      );
    }).toList();
  }

  Widget _hizmetIsareti(_HaritaHizmeti kayit) {
    final bool eczane = kayit.kategori == 'Nöbetçi Eczane';
    final String ad = kayit.hizmet.isim.trim().isEmpty
        ? kayit.kategori
        : kayit.hizmet.isim.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 156),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: kayit.renk.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            ad,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF202124),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: kayit.renk, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: eczane
                ? const Text(
                    'E',
                    style: TextStyle(
                      color: _enobetKirmizi,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(kayit.ikon, color: kayit.renk, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _konumIsareti() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double t = Curves.easeOut.transform(_pulseController.value);
        final double halkaBoyutu = 22 + (34 * t);
        final double halkaOpakligi = (1 - t) * 0.48;

        return SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: halkaBoyutu,
                height: halkaBoyutu,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _appleMavi.withValues(alpha: halkaOpakligi * 0.16),
                  border: Border.all(
                    color: _appleMavi.withValues(alpha: halkaOpakligi),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _appleMavi.withValues(alpha: halkaOpakligi),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: _appleMavi,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _appleMavi.withValues(alpha: 0.48),
                      blurRadius: 9,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _yanipSonenE({bool kucuk = false}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double x = _pulseController.value;
        final double parlaklik = 0.34 + (0.66 * (1 - (2 * x - 1).abs()));
        final double boyut = kucuk ? 34 : 36;

        return Container(
          width: boyut,
          height: boyut,
          decoration: BoxDecoration(
            color: const Color(0xFF150607),
            shape: BoxShape.circle,
            border: Border.all(
              color: _enobetKirmizi.withValues(alpha: parlaklik),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: _enobetKirmizi.withValues(alpha: parlaklik * 0.58),
                blurRadius: 12 + (6 * parlaklik),
                spreadRadius: parlaklik,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'E',
              style: TextStyle(
                color: _enobetKirmizi.withValues(alpha: 0.50 + (0.50 * parlaklik)),
                fontSize: kucuk ? 22 : 23,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  void _merkeziKonumaGetir() {
    _mapController.move(_merkez, _zoom);
  }

  Widget _ustKontroller() {
    BoxDecoration camDekorasyon({Color? vurgu}) {
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (vurgu ?? const Color(0xFF8B8F94)).withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    const Color yaziRengi = Color(0xFF202124);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Geri',
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: camDekorasyon(),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: yaziRengi,
                size: 18,
              ),
            ),
          ),
        ),
        const Spacer(),
        Semantics(
          button: true,
          selected: _seciliKategori == 'Nöbetçi Eczane',
          label: 'Nöbetçi Eczaneler',
          child: GestureDetector(
            onTap: _eczaneleriSec,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 42,
              constraints: const BoxConstraints(maxWidth: 142),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: camDekorasyon(
                vurgu: _seciliKategori == 'Nöbetçi Eczane'
                    ? _enobetKirmizi
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _yanipSonenE(kucuk: true),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Nöbetçi Eczane',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: yaziRengi,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Semantics(
          button: true,
          label: 'Kategoriler',
          child: GestureDetector(
            onTap: () {
              setState(() {
                _kategoriMenusuAcik = !_kategoriMenusuAcik;
              });
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: camDekorasyon(
                vurgu: _kategoriMenusuAcik ? _appleMavi : null,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_rounded, color: yaziRengi, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Kategoriler',
                    style: TextStyle(
                      color: yaziRengi,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kategoriMenusu() {
    final tema = context.enobetTema;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 336,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFB8BDC3).withValues(alpha: 0.58),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: tema.koyu ? 0.30 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: Color(0xFF202124),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Kategoriler',
                      style: TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _kategoriMenusuAcik = false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF5F6368),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tema.sinir),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _kategoriler.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: 2.75,
                ),
                itemBuilder: (context, index) {
                  final kategori = _kategoriler[index];
                  final bool secili = _seciliKategori == kategori.$1;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _kategoriSec(kategori.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: secili
                              ? kategori.$3.withValues(alpha: 0.14)
                              : const Color(0xFFF5F6F7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: secili
                                ? kategori.$3.withValues(alpha: 0.58)
                                : const Color(0xFFD8DADD),
                            width: secili ? 1.3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: kategori.$3.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                kategori.$2,
                                color: kategori.$3,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                kategori.$1,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF202124),
                                  fontSize: kategori.$1 ==
                                          'Elektrikli Şarj İstasyonu'
                                      ? 9.6
                                      : 10.7,
                                  height: 1.08,
                                  fontWeight: secili
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (secili)
                              Icon(
                                Icons.check_rounded,
                                color: kategori.$3,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.enobetTema;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAED),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _merkez,
                initialZoom: _zoom,
                minZoom: 5,
                maxZoom: 19,
                backgroundColor: const Color(0xFFE8EAED),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.enobet.app',
                ),
                MarkerLayer(markers: _markerlar()),
                if (_konumNoktasiVar)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(widget.mevcutEnlem!, widget.mevcutBoylam!),
                        width: 64,
                        height: 64,
                        child: _konumIsareti(),
                      ),
                    ],
                  ),
              ],
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: _ustKontroller(),
            ),
          ),

          if (_kategoriMenusuAcik)
            Positioned(
              left: 10,
              right: 10,
              top: MediaQuery.paddingOf(context).top + 67,
              child: Align(
                alignment: Alignment.topRight,
                child: _kategoriMenusu(),
              ),
            ),

          Positioned(
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 20,
            child: FloatingActionButton.small(
              heroTag: 'harita_merkez',
              onPressed: _merkeziKonumaGetir,
              backgroundColor: Colors.white.withValues(alpha: 0.82),
              foregroundColor: _appleMavi,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.my_location_rounded, size: 21),
            ),
          ),

          if (_seciliKategori != null)
            Positioned(
              left: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 210),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tema.sinir),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '$_seciliKategori • ${_gorunenHizmetler().length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tema.anaYazi,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HaritaHizmeti {
  final Hizmet hizmet;
  final String kategori;
  final IconData ikon;
  final Color renk;

  const _HaritaHizmeti({
    required this.hizmet,
    required this.kategori,
    required this.ikon,
    required this.renk,
  });
}
