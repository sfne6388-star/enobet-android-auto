import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../theme/enobet_tema.dart';
import '../services/bildirim_servisi.dart';
import '../services/favori_servisi.dart';
import 'favoriler.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> with WidgetsBindingObserver {
  static const _adAnahtari = 'kullanici_adi';
  static const _fotoAnahtari = 'profil_fotografi_v1';

  static const _kirmizi = Color(0xFFE3262E);

  Uint8List? _fotograf;
  bool _fotoMesgul = true;

  String _ad = 'ENOBET Kullanıcısı';
  int? _favoriSayisi;

  bool _bildirimler = false;
  bool _bildirimYukleniyor = true;
  bool _bildirimKaydediliyor = false;

  bool _konumMesgul = false;
  bool _temaMesgul = false;

  String _konumDurumu = 'Kontrol ediliyor…';

  EnobetTemaRenkleri get _tema => context.enobetTema;

  String get _temaModu => _tema.mod;
  bool get _koyu => _tema.koyu;
  bool get _gumus => _tema.gumus;

  Color get _kart => _tema.kart;
  Color get _ikincil => _tema.ikincilYazi;
  Color get _sayfaArkaPlan => _tema.arkaPlan;

  List<Color> get _profilGradient {
    if (_koyu) {
      return const [
        Color(0xFF39171E),
        Color(0xFF19191E),
      ];
    }

    if (_gumus) {
      return const [
        Color(0xFFD0BFC3),
        Color(0xFFD9DBDF),
      ];
    }

    return const [
      Color(0xFFFFE7EA),
      Colors.white,
    ];
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _profilYukle();
    _fotografiYukle();
    _favorileriYukle();
    _bildirimYukle();
    _konumuKontrolEt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _konumuKontrolEt();

      if (!_bildirimKaydediliyor) {
        _bildirimYukle();
      }
    }
  }

  void _mesaj(String mesaj) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
      ),
    );
  }

  // ============================================================
  // PROFİL FOTOĞRAFI
  // ============================================================

  Future<void> _fotografiYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final kayit = prefs.getString(_fotoAnahtari);

      if (kayit != null && kayit.isNotEmpty) {
        try {
          final bytes = base64Decode(kayit);

          if (mounted) {
            setState(() {
              _fotograf = bytes;
            });
          }
        } catch (_) {
          await prefs.remove(_fotoAnahtari);
        }
      }

      // Android'de fotoğraf seçilirken uygulama sistem tarafından
      // kapatılmışsa seçilen fotoğrafı geri almaya çalış.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final sonuc = await ImagePicker().retrieveLostData();

        if (!sonuc.isEmpty) {
          final dosyalar = sonuc.files;

          if (dosyalar != null && dosyalar.isNotEmpty) {
            await _fotografiKaydet(dosyalar.first);
          } else if (sonuc.exception != null) {
            _mesaj(
              'Fotoğraf seçimi tamamlanamadı. Tekrar seçebilirsiniz.',
            );
          }
        }
      }
    } catch (_) {
      _mesaj(
        'Profil fotoğrafı yüklenemedi. Yeniden fotoğraf seçebilirsiniz.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _fotoMesgul = false;
        });
      }
    }
  }

  Future<void> _fotografiKaydet(XFile dosya) async {
    final veri = await dosya.readAsBytes();

    if (veri.isEmpty) {
      throw StateError('Fotoğraf okunamadı');
    }

    // SharedPreferences ve özellikle web tarayıcı depolaması
    // için çok büyük fotoğrafları kabul etmiyoruz.
    if (veri.length > 5 * 1024 * 1024) {
      throw StateError('Fotoğraf çok büyük');
    }

    final prefs = await SharedPreferences.getInstance();

    final kaydedildi = await prefs.setString(
      _fotoAnahtari,
      base64Encode(veri),
    );

    if (!kaydedildi) {
      throw StateError('Fotoğraf kaydedilemedi');
    }

    if (!mounted) return;

    setState(() {
      _fotograf = veri;
    });
  }

  Future<void> _fotoSecenekleri() async {
    if (_fotoMesgul) return;

    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Profil fotoğrafı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                ),
                title: const Text(
                  'Galeriden fotoğraf seç',
                ),
                onTap: () {
                  Navigator.pop(sheetContext, 'sec');
                },
              ),
              if (_fotograf != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                  ),
                  title: const Text(
                    'Fotoğrafı kaldır',
                  ),
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                      'kaldir',
                    );
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (secim == null || !mounted) return;

    setState(() {
      _fotoMesgul = true;
    });

    try {
      if (secim == 'kaldir') {
        final prefs =
            await SharedPreferences.getInstance();

        await prefs.remove(_fotoAnahtari);

        if (mounted) {
          setState(() {
            _fotograf = null;
          });
        }

        _mesaj(
          'Profil fotoğrafı kaldırıldı.',
        );

        return;
      }

      final picker = ImagePicker();

      final dosya = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
        requestFullMetadata: false,
      );

      if (dosya == null) {
        return;
      }

      await _fotografiKaydet(dosya);

      _mesaj(
        'Profil fotoğrafınız güncellendi.',
      );
    } catch (e) {
      debugPrint(
        'Profil fotoğrafı hatası: $e',
      );

      _mesaj(
        'Fotoğraf eklenemedi. Başka bir fotoğraf seçip tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _fotoMesgul = false;
        });
      }
    }
  }

  Widget _fotoAlani() {
    return Semantics(
      button: true,
      label: 'Profil fotoğrafını değiştir',
      child: InkWell(
        onTap:
            _fotoMesgul ? null : _fotoSecenekleri,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _fotograf == null
                      ? _basHarf()
                      : Image.memory(
                          _fotograf!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder:
                              (_, error, stack) {
                            return _basHarf();
                          },
                        ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: _kirmizi,
                  child: _fotoMesgul
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basHarf() {
    final temizAd = _ad.trim();

    final harf = temizAd.isEmpty
        ? 'E'
        : temizAd.characters.first.toUpperCase();

    return ColoredBox(
      color: _kirmizi,
      child: Center(
        child: Text(
          harf,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFİL ADI
  // ============================================================

  Future<void> _profilYukle() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final ad =
          prefs.getString(_adAnahtari)?.trim();

      if (!mounted) return;

      if (ad != null && ad.isNotEmpty) {
        setState(() {
          _ad = ad;
        });
      }
    } catch (_) {
      _mesaj(
        'Profil adı okunamadı. Lütfen tekrar deneyin.',
      );
    }
  }

  Future<void> _adDuzenle() async {
    final yeniAd = await showDialog<String>(
      context: context,
      builder: (_) {
        return _AdDuzenleme(
          ad: _ad == 'ENOBET Kullanıcısı'
              ? ''
              : _ad,
        );
      },
    );

    if (yeniAd == null || !mounted) return;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final kaydedildi = await prefs.setString(
        _adAnahtari,
        yeniAd,
      );

      if (!kaydedildi) {
        throw StateError(
          'Ad kaydedilemedi',
        );
      }

      if (!mounted) return;

      setState(() {
        _ad = yeniAd;
      });

      _mesaj(
        'Profil adınız güncellendi.',
      );
    } catch (_) {
      _mesaj(
        'Adınız kaydedilemedi. Lütfen tekrar deneyin.',
      );
    }
  }

  // ============================================================
  // FAVORİLER
  // ============================================================

  Future<void> _favorileriYukle() async {
    try {
      final favoriler =
          await FavoriServisi().favorileriGetir();

      if (mounted) {
        setState(() {
          _favoriSayisi = favoriler.length;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _favoriSayisi = null;
        });
      }

      _mesaj(
        'Favori sayısı yüklenemedi.',
      );
    }
  }

  Future<void> _favorileriAc() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            const Favoriler(hizmetler: []),
      ),
    );

    if (mounted) {
      await _favorileriYukle();
    }
  }

  // ============================================================
  // BİLDİRİMLER
  // ============================================================

  Future<void> _bildirimYukle() async {
    try {
      final acik =
          await BildirimServisi.bildirimlerAcikMi();

      if (!mounted) return;

      setState(() {
        _bildirimler = acik;
        _bildirimYukleniyor = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _bildirimYukleniyor = false;
        });
      }

      _mesaj(
        'Bildirim tercihi okunamadı. Sayfayı yeniden açın.',
      );
    }
  }

  Future<void> _bildirimDegistir(
    bool acik,
  ) async {
    if (_bildirimKaydediliyor) return;

    if (kIsWeb) {
      _mesaj(
        'Bildirimleri Android uygulamasından yönetebilirsiniz.',
      );
      return;
    }

    setState(() {
      _bildirimKaydediliyor = true;
    });

    try {
      if (acik) {
        if (!await BildirimServisi
            .bildirimleriAc()) {
          _mesaj(
            'Bildirimler açılamadı. İnternet bağlantınızı ve telefonunuzdaki bildirim iznini kontrol edin.',
          );

          return;
        }
      } else {
        await BildirimServisi
            .bildirimleriKapat();
      }

      final kayitli =
          await BildirimServisi.bildirimlerAcikMi();

      if (!mounted) return;

      setState(() {
        _bildirimler = kayitli;
      });

      _mesaj(
        kayitli == acik
            ? (acik
                ? 'Bildirimler açıldı.'
                : 'Bildirimler kapatıldı.')
            : 'Tercihiniz kaydedilemedi. Lütfen tekrar deneyin.',
      );
    } catch (_) {
      _mesaj(
        'Bildirim ayarı değiştirilemedi. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _bildirimKaydediliyor = false;
        });
      }
    }
  }

  // ============================================================
  // KONUM
  // ============================================================

  Future<void> _konumuKontrolEt() async {
    try {
      final servis =
          await Geolocator.isLocationServiceEnabled();

      final izin =
          await Geolocator.checkPermission();

      if (!mounted) return;

      setState(() {
        _konumDurumu = !servis
            ? 'Telefonun konum servisi kapalı'
            : izin == LocationPermission.always ||
                    izin ==
                        LocationPermission
                            .whileInUse
                ? 'Konum erişimi açık'
                : 'Konum izni gerekli';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _konumDurumu =
              'Konum durumu okunamadı';
        });
      }
    }
  }

  Future<void> _konumYonet() async {
    if (_konumMesgul) return;

    setState(() {
      _konumMesgul = true;
    });

    try {
      var izin =
          await Geolocator.checkPermission();

      if (izin == LocationPermission.denied) {
        izin =
            await Geolocator.requestPermission();
      }

      if (!mounted) return;

      if (izin ==
          LocationPermission.deniedForever) {
        if (kIsWeb ||
            !await Geolocator.openAppSettings()) {
          _mesaj(
            'Cihazınızın uygulama ayarlarından ENOBET konum iznini açın.',
          );
        }
      } else if (!await Geolocator
          .isLocationServiceEnabled()) {
        if (kIsWeb ||
            !await Geolocator
                .openLocationSettings()) {
          _mesaj(
            'Cihazınızın ayarlarından konum servisini açın.',
          );
        }
      } else {
        _mesaj(
          izin == LocationPermission.always ||
                  izin ==
                      LocationPermission
                          .whileInUse
              ? 'Konum erişimi açık. İl ve ilçeyi ana sayfanın üstündeki konum alanından seçebilirsiniz.'
              : 'Konum izni verilmedi. Ana sayfadan il ve ilçe seçebilirsiniz.',
        );
      }

      await _konumuKontrolEt();
    } catch (_) {
      _mesaj(
        'Konum ayarları açılamadı. Telefon ayarlarından kontrol edin.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _konumMesgul = false;
        });
      }
    }
  }

  // ============================================================
  // TEMA
  // ============================================================

  Future<void> _temaDegistir(
    String tema,
  ) async {
    if (_temaMesgul || tema == _temaModu) return;

    setState(() {
      _temaMesgul = true;
    });

    try {
      await EnobetApp.temaAyarla(context, tema);
    } catch (_) {
      _mesaj(
        'Tema tercihi kaydedilemedi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _temaMesgul = false;
        });
      }
    }
  }

  Widget _temaSecici() {
    return Material(
      color: _kart,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8860D0)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Color(0xFF8860D0),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uygulama teması',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _temaModu == temaKoyu
                            ? 'Koyu görünüm kullanılıyor'
                            : _temaModu == temaGumus
                                ? 'Gümüş görünüm kullanılıyor'
                                : 'Açık görünüm kullanılıyor',
                        style: TextStyle(
                          color: _ikincil,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_temaMesgul)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _temaButonu(
                    temaKoyu,
                    Icons.dark_mode_rounded,
                    'Koyu',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _temaButonu(
                    temaGumus,
                    Icons.brightness_medium_rounded,
                    'Gümüş',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _temaButonu(
                    temaAcik,
                    Icons.light_mode_rounded,
                    'Açık',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _temaButonu(
    String tema,
    IconData ikon,
    String baslik,
  ) {
    final secili = _temaModu == tema;

    final arkaPlan = secili
        ? _kirmizi.withValues(alpha: _koyu ? 0.22 : 0.12)
        : _tema.ikinciKart;

    return Semantics(
      button: true,
      selected: secili,
      label: '$baslik tema',
      child: InkWell(
        onTap: _temaMesgul
            ? null
            : () => _temaDegistir(tema),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: arkaPlan,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: secili
                  ? _kirmizi
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                secili
                    ? Icons.check_circle_rounded
                    : ikon,
                size: 21,
                color: secili
                    ? _kirmizi
                    : Theme.of(context)
                        .colorScheme
                        .onSurface,
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  baslik,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: secili
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BİLGİ PENCERESİ
  // ============================================================

  void _bilgi(
    String baslik,
    String metin,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _kart,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  metin,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: _ikincil,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      sheetContext,
                    );
                  },
                  child:
                      const Text('Tamam'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // EKRAN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sayfaArkaPlan,
      appBar: AppBar(
        title: const Text(
          'Profilim',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            32,
          ),
          children: [
            Container(
              padding:
                  const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _profilGradient,
                ),
                borderRadius:
                    BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _fotoAlani(),
                      const Spacer(),
                      IconButton(
                        tooltip:
                            'Profil adını düzenle',
                        onPressed:
                            _adDuzenle,
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _ad,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tercihlerin ve favorilerin bir arada.',
                    style: TextStyle(
                      color: _ikincil,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _satir(
              Icons.favorite_rounded,
              _kirmizi,
              'Favorilerim',
              _favoriSayisi == null
                  ? 'Kaydettiğiniz hizmetleri görüntüleyin'
                  : '$_favoriSayisi kayıtlı hizmet',
              onTap: _favorileriAc,
            ),

            _baslik('TERCİHLERİM'),

            _satir(
              Icons.notifications_outlined,
              const Color(0xFFD58B00),
              'Eczane bildirimleri',
              _bildirimYukleniyor
                  ? 'Tercih yükleniyor…'
                  : _bildirimler
                      ? 'Bildirim tercihiniz açık'
                      : 'Nöbetçi eczane duyurularını alın',
              trailing:
                  _bildirimKaydediliyor
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Switch(
                          value:
                              _bildirimler,
                          onChanged:
                              _bildirimYukleniyor
                                  ? null
                                  : _bildirimDegistir,
                          activeThumbColor:
                              _kirmizi,
                        ),
            ),

            const SizedBox(height: 10),

            _temaSecici(),

            const SizedBox(height: 10),

            _satir(
              Icons.location_on_outlined,
              const Color(0xFF139B8E),
              'Konum ayarları',
              _konumDurumu,
              onTap: _konumMesgul
                  ? null
                  : _konumYonet,
              trailing: _konumMesgul
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),

            _baslik('YARDIM VE BİLGİ'),

            _satir(
              Icons.help_outline_rounded,
              const Color(0xFF3185E8),
              'Nasıl kullanılır?',
              'Arama, favoriler ve bölge seçimi',
              onTap: () => _bilgi(
                'ENöbet nasıl kullanılır?',
                'Hizmet bul\n'
                    'Ana sayfadan bir kategori seçin veya arama alanına işletme ya da hizmet adını yazın.\n\n'
                    'Bölge seç\n'
                    'Ana sayfanın üstündeki konuma dokunarak il ve ilçe seçebilirsiniz.\n\n'
                    'Favorilere ekle\n'
                    'Hizmet detayındaki kalp simgesine dokunun. Kaydettiklerinize bu sayfadaki Favorilerim bölümünden ulaşın.\n\n'
                    'Bildirimler\n'
                    'Eczane duyuruları için bildirim tercihini açın. Telefonunuzda ENOBET bildirim izni de açık olmalıdır.',
              ),
            ),

            const SizedBox(height: 10),

            _satir(
              Icons.info_outline_rounded,
              const Color(0xFF8860D0),
              'ENöbet hakkında',
              'Uygulama bilgileri',
              onTap: () => _bilgi(
                'ENöbet',
                'İhtiyacın olan hizmete en hızlı şekilde ulaş.\n\n'
                    'Eczane, hastane, taksi, veteriner ve diğer yerel hizmetleri tek yerden keşfedin.\n\n'
                    'Profil adınız ve favorileriniz bu cihazda saklanır.\n\n'
                    'Sürüm 1.0.0',
              ),
            ),

            const SizedBox(height: 28),

            Center(
              child: Text(
                'ENöbet • Sen Ne Ararsan…',
                style: TextStyle(
                  color: _ikincil,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baslik(String baslik) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 26,
        bottom: 12,
      ),
      child: Text(
        baslik,
        style: TextStyle(
          color: _ikincil,
          fontSize: 12,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _satir(
    IconData ikon,
    Color renk,
    String baslik,
    String aciklama, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: _kart,
      borderRadius:
          BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: renk.withValues(
              alpha: 0.12,
            ),
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: Icon(
            ikon,
            color: renk,
          ),
        ),
        title: Text(
          baslik,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(top: 5),
          child: Text(
            aciklama,
            style: TextStyle(
              color: _ikincil,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        trailing: trailing ??
            const Icon(
              Icons.chevron_right_rounded,
            ),
        onTap: onTap,
      ),
    );
  }
}

class _AdDuzenleme extends StatefulWidget {
  final String ad;

  const _AdDuzenleme({
    required this.ad,
  });

  @override
  State<_AdDuzenleme> createState() =>
      _AdDuzenlemeState();
}

class _AdDuzenlemeState
    extends State<_AdDuzenleme> {
  late final TextEditingController
      _controller;

  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text: widget.ad,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _kaydet() {
    if (_form.currentState!.validate()) {
      Navigator.pop(
        context,
        _controller.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Profil adını düzenle',
      ),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 32,
          textCapitalization:
              TextCapitalization.words,
          textInputAction:
              TextInputAction.done,
          decoration:
              const InputDecoration(
            labelText: 'Görünen ad',
            hintText: 'Adınızı yazın',
          ),
          validator: (value) =>
              value == null ||
                      value.trim().isEmpty
                  ? 'Lütfen bir ad yazın.'
                  : null,
          onFieldSubmitted: (_) {
            _kaydet();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _kaydet,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}