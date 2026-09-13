import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/hizmet.dart';
import 'services/turkiye_hizmet_servisi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const EnobetTvApp());
}

class EnobetTvApp extends StatelessWidget {
  const EnobetTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme renkler = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE3262E),
      brightness: Brightness.dark,
      surface: const Color(0xFF111111),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ENöbet TV',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: renkler,
        scaffoldBackgroundColor: const Color(0xFF070707),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      home: const EnobetTvHome(),
    );
  }
}

class EnobetTvHome extends StatefulWidget {
  const EnobetTvHome({super.key});

  @override
  State<EnobetTvHome> createState() => _EnobetTvHomeState();
}

class _EnobetTvHomeState extends State<EnobetTvHome> {
  final TurkiyeHizmetServisi _servis = TurkiyeHizmetServisi();
  late final Future<List<Hizmet>> _veriFuture = _servis.getir();

  String? _seciliKategori;

  static const List<String> _oncelik = <String>[
    'Eczane',
    'AVM & Outlet',
    'Hastane',
    'Veteriner',
    'Elektrikli Şarj İstasyonu',
    'Akaryakıt İstasyonu',
    'Otel',
    'Noter',
    'ATM',
    'Taksi',
    'Kargo',
    'Otogar',
    'Havaalanı',
  ];

  List<String> _kategoriler(List<Hizmet> veriler) {
    final Set<String> tum = veriler
        .map((Hizmet e) => e.kategori.trim())
        .where((String e) => e.isNotEmpty)
        .toSet();

    final List<String> sonuc = <String>[];
    for (final String kategori in _oncelik) {
      if (tum.remove(kategori)) sonuc.add(kategori);
    }
    sonuc.addAll(tum.toList()..sort());
    return sonuc;
  }

  List<Hizmet> _kategoriKayitlari(List<Hizmet> veriler, String kategori) {
    final Map<String, Hizmet> benzersiz = <String, Hizmet>{};
    for (final Hizmet hizmet in veriler) {
      if (hizmet.kategori != kategori) continue;
      benzersiz['${hizmet.id}|${hizmet.kategori}'] = hizmet;
    }
    final List<Hizmet> sonuc = benzersiz.values.toList();
    sonuc.sort((Hizmet a, Hizmet b) {
      final int il = a.il.compareTo(b.il);
      if (il != 0) return il;
      final int ilce = a.ilce.compareTo(b.ilce);
      if (ilce != 0) return ilce;
      return a.isim.compareTo(b.isim);
    });
    return sonuc;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Hizmet>>(
          future: _veriFuture,
          builder: (BuildContext context, AsyncSnapshot<List<Hizmet>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _TvLoading();
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _TvError(
                mesaj: 'Yerel ENöbet verisi açılamadı.\n${snapshot.error ?? ''}',
              );
            }

            final List<Hizmet> veriler = snapshot.data!;
            final List<String> kategoriler = _kategoriler(veriler);
            if (kategoriler.isEmpty) {
              return const _TvError(mesaj: 'Gösterilecek hizmet verisi bulunamadı.');
            }

            final String kategori = _seciliKategori != null &&
                    kategoriler.contains(_seciliKategori)
                ? _seciliKategori!
                : kategoriler.first;
            final List<Hizmet> kayitlar = _kategoriKayitlari(veriler, kategori);

            return Column(
              children: <Widget>[
                _TvHeader(
                  toplamKayit: veriler.length,
                  kategoriSayisi: kategoriler.length,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          width: 330,
                          child: _KategoriPaneli(
                            kategoriler: kategoriler,
                            seciliKategori: kategori,
                            sayiBul: (String kat) =>
                                _kategoriKayitlari(veriler, kat).length,
                            onSec: (String kat) {
                              setState(() => _seciliKategori = kat);
                            },
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: _KayitPaneli(
                            kategori: kategori,
                            kayitlar: kayitlar,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TvHeader extends StatelessWidget {
  final int toplamKayit;
  final int kategoriSayisi;

  const _TvHeader({
    required this.toplamKayit,
    required this.kategoriSayisi,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE3262E),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66E3262E),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'E',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 18),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ENöbet TV',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Kumandayla gezinmek için yön tuşlarını ve OK tuşunu kullanın',
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          _BilgiRozeti(ikon: Icons.category_rounded, metin: '$kategoriSayisi kategori'),
          const SizedBox(width: 12),
          _BilgiRozeti(ikon: Icons.storage_rounded, metin: '$toplamKayit kayıt'),
          const SizedBox(width: 12),
          const _BilgiRozeti(
            ikon: Icons.tv_rounded,
            metin: 'TV deneme sürümü',
          ),
        ],
      ),
    );
  }
}

class _BilgiRozeti extends StatelessWidget {
  final IconData ikon;
  final String metin;

  const _BilgiRozeti({required this.ikon, required this.metin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Row(
        children: <Widget>[
          Icon(ikon, size: 19, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 8),
          Text(
            metin,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFDDDDDD),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KategoriPaneli extends StatelessWidget {
  final List<String> kategoriler;
  final String seciliKategori;
  final int Function(String kategori) sayiBul;
  final ValueChanged<String> onSec;

  const _KategoriPaneli({
    required this.kategoriler,
    required this.seciliKategori,
    required this.sayiBul,
    required this.onSec,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF202020)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: kategoriler.length,
        itemBuilder: (BuildContext context, int index) {
          final String kategori = kategoriler[index];
          return _TvKategoriButonu(
            autofocus: index == 0,
            secili: kategori == seciliKategori,
            baslik: kategori,
            adet: sayiBul(kategori),
            onPressed: () => onSec(kategori),
          );
        },
      ),
    );
  }
}

class _TvKategoriButonu extends StatefulWidget {
  final bool autofocus;
  final bool secili;
  final String baslik;
  final int adet;
  final VoidCallback onPressed;

  const _TvKategoriButonu({
    required this.autofocus,
    required this.secili,
    required this.baslik,
    required this.adet,
    required this.onPressed,
  });

  @override
  State<_TvKategoriButonu> createState() => _TvKategoriButonuState();
}

class _TvKategoriButonuState extends State<_TvKategoriButonu> {
  bool _odakli = false;

  @override
  Widget build(BuildContext context) {
    final bool aktif = _odakli || widget.secili;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _odakli ? 1.025 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            autofocus: widget.autofocus,
            borderRadius: BorderRadius.circular(16),
            onFocusChange: (bool value) {
              setState(() => _odakli = value);
              if (value) {
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 140),
                  alignment: 0.5,
                );
              }
            },
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: aktif
                    ? const Color(0xFF251113)
                    : const Color(0xFF151515),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _odakli
                      ? const Color(0xFFFF6870)
                      : widget.secili
                          ? const Color(0xFFE3262E)
                          : const Color(0xFF242424),
                  width: _odakli ? 2.4 : 1,
                ),
                boxShadow: _odakli
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x55E3262E),
                          blurRadius: 18,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.adet}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCCCCCC),
                        fontWeight: FontWeight.w700,
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
  }
}

class _KayitPaneli extends StatelessWidget {
  final String kategori;
  final List<Hizmet> kayitlar;

  const _KayitPaneli({required this.kategori, required this.kayitlar});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF202020)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    kategori,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${kayitlar.length} sonuç',
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF222222)),
          Expanded(
            child: kayitlar.isEmpty
                ? const Center(
                    child: Text(
                      'Bu kategoride yerel kayıt bulunamadı.',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: kayitlar.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Hizmet hizmet = kayitlar[index];
                      return _TvHizmetSatiri(hizmet: hizmet);
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'TV sürümünde harita, GPS, Yol Asistanı, kamera ve telefon özellikleri kapalıdır.',
              textAlign: TextAlign.right,
              style: TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvHizmetSatiri extends StatefulWidget {
  final Hizmet hizmet;

  const _TvHizmetSatiri({required this.hizmet});

  @override
  State<_TvHizmetSatiri> createState() => _TvHizmetSatiriState();
}

class _TvHizmetSatiriState extends State<_TvHizmetSatiri> {
  bool _odakli = false;

  void _detayGoster() {
    final Hizmet h = widget.hizmet;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: Text(h.isim),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${h.il} / ${h.ilce}'),
                if (h.adres.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(h.adres),
                ],
                if (h.telefon.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('Telefon: ${h.telefon}'),
                ],
                if (h.calismaSaatleri.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text('Çalışma: ${h.calismaSaatleri}'),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Hizmet h = widget.hizmet;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onFocusChange: (bool value) {
            setState(() => _odakli = value);
            if (value) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 140),
                alignment: 0.5,
              );
            }
          },
          onTap: _detayGoster,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: _odakli ? const Color(0xFF182028) : const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _odakli ? const Color(0xFF7CC4FF) : const Color(0xFF242424),
                width: _odakli ? 2.2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: h.renk.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(h.ikon, color: h.renk, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        h.isim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${h.il} / ${h.ilce}${h.adres.trim().isEmpty ? '' : '  •  ${h.adres}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF777777)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvLoading extends StatelessWidget {
  const _TvLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('ENöbet TV verileri hazırlanıyor…', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class _TvError extends StatelessWidget {
  final String mesaj;

  const _TvError({required this.mesaj});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          mesaj,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, color: Color(0xFFFF8A8F)),
        ),
      ),
    );
  }
}
