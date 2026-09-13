import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/konum_verileri.dart';
import '../models/hizmet.dart';
import '../services/eczane_servisi.dart';
import '../services/avm_servisi.dart';
import '../services/telefon_bilgisi.dart';
import '../services/harita_http_basliklari.dart';
import '../theme/enobet_tema.dart';
import '../widgets/dadi_avatar.dart';
import '../widgets/hersey_burada_ikon.dart';
import 'acil_hatlar.dart';
import 'akaryakit_fiyatlari.dart';
import 'barkod_sorgulama.dart';
import '../services/hizmet_siralama.dart';
import '../services/turkiye_hizmet_servisi.dart';
import '../services/hizli_yerel_hizmet_servisi.dart';
import '../services/veteriner_servisi.dart';
import 'hizmet_detay.dart';
import 'hava_durumu.dart';
import 'hersey_burada.dart';
import 'doviz_kurlari.dart';
import 'dadi.dart';
import 'profil.dart';
import 'yakin_hizmetler_haritasi.dart';
import 'yol_asistani.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  static const double _gpsYaricapKm = 30;

  // Uygulamadan kaldırılmış hizmetler ana sayfa, Türkiye geneli arama
  // ve Yakınımdaki sonuçlarına kesinlikle dahil edilmez.
  static const Set<String> _kaldirilanKategoriler = <String>{
    'Çekici',
    'Oto Lastik',
    'Çilingir',
    'Oto Ekspertiz',
    'Oto Yetkili Servis',
  };

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _turkiyeServisi = TurkiyeHizmetServisi();

  List<Hizmet> _turkiyeHizmetleri = [];
  bool _turkiyeYukleniyor = false;
  String? _turkiyeHatasi;
  Timer? _aramaBekleme;

  Future<void> _turkiyeGetir() async {
    if (_turkiyeYukleniyor || _turkiyeHizmetleri.isNotEmpty) return;

    setState(() {
      _turkiyeYukleniyor = true;
      _turkiyeHatasi = null;
    });

    try {
      final data = await _turkiyeServisi.getir();

      if (mounted) {
        setState(() {
          _turkiyeHizmetleri = data
              .where((hizmet) => !_kaldirilanKategoriler.contains(hizmet.kategori))
              .toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _turkiyeHatasi =
              'Türkiye verisi yüklenemedi. Görünen sonuçlar eksik olabilir.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _turkiyeYukleniyor = false;
        });
      }
    }
  }

  int _gorunenAdet = 50;
  int _bolgeSurumu = 0;
  int _konumSurumu = 0;
  int _veriSurumu = 0;

  Timer? _timer;

  final ValueNotifier<bool> _yanipSonme = ValueNotifier<bool>(true);

  int _seciliMenu = 0;

  final TextEditingController _aramaController = TextEditingController();

  final FocusNode _aramaFocusNode = FocusNode();

  final GlobalKey _aramaAnahtari = GlobalKey();

  final ScrollController _scrollController = ScrollController();

  final EczaneServisi _eczaneServisi = EczaneServisi();

  final AvmServisi _avmServisi = AvmServisi();

  final VeterinerServisi _veterinerServisi = VeterinerServisi();

  final YerelHizmetServisi _yerelHizmetServisi = YerelHizmetServisi();

  String _aramaMetni = '';
  String? _seciliKategori;

  String _seciliIl = '';
  String _seciliIlce = '';

  Position? _mevcutKonum;

  /// false:
  /// Telefonun gerçek GPS konumu kullanılıyor.
  ///
  /// true:
  /// Kullanıcı İl / İlçe seçimini kendisi yaptı.
  bool _manuelKonumSecildi = false;

  bool _konumYukleniyor = true;
  String? _konumHatasi;

  /// GPS modunda 30 km çevredeki bütün yerel kayıtları yalnızca
  /// bir kez hesaplayıp burada tutuyoruz.
  List<Hizmet>? _gpsYerelOnbellek;

  Future<List<Hizmet>>? _gpsYerelBekleyenIslem;

  /// GPS 30 km alanıyla kesişen iller.
  ///
  /// Nöbetçi eczane API'si il bazlı çalıştığı için kullanılıyor.

  List<Hizmet> _eczaneler = [];
  bool _eczanelerYukleniyor = false;
  String? _eczaneHatasi;

  List<Hizmet> _hastaneler = [];
  bool _hastanelerYukleniyor = false;
  String? _hastaneHatasi;

  List<Hizmet> _atmler = [];
  bool _atmlerYukleniyor = false;
  String? _atmHatasi;

  List<Hizmet> _taksiler = [];
  bool _taksilerYukleniyor = false;
  String? _taksiHatasi;

  List<Hizmet> _noterler = [];
  bool _noterlerYukleniyor = false;
  String? _noterHatasi;

  List<Hizmet> _oteller = [];
  bool _otellerYukleniyor = false;
  String? _otelHatasi;

  List<Hizmet> _kargolar = [];
  bool _kargolarYukleniyor = false;
  String? _kargoHatasi;

  List<Hizmet> _otogarlar = [];
  bool _otogarlarYukleniyor = false;
  String? _otogarHatasi;

  List<Hizmet> _havaalanlari = [];
  bool _havaalanlariYukleniyor = false;
  String? _havaalaniHatasi;

  List<Hizmet> _avmler = [];
  bool _avmlerYukleniyor = false;
  String? _avmHatasi;

  List<Hizmet> _veterinerler = [];
  bool _veterinerlerYukleniyor = false;
  String? _veterinerHatasi;

  List<Hizmet> _cekiciler = [];
  bool _cekicilerYukleniyor = false;
  String? _cekiciHatasi;

  List<Hizmet> _sarjIstasyonlari = [];
  bool _sarjIstasyonlariYukleniyor = false;
  String? _sarjIstasyonuHatasi;

  List<Hizmet> _otoLastikler = [];
  bool _otoLastiklerYukleniyor = false;
  String? _otoLastikHatasi;

  List<Hizmet> _cilingirlar = [];
  bool _cilingirlarYukleniyor = false;
  String? _cilingirHatasi;

  bool get _gpsModu => !_manuelKonumSecildi && _mevcutKonum != null;

  bool get _konumKullanilabilir =>
      _gpsModu ||
      (_manuelKonumSecildi && _seciliIl.isNotEmpty && _seciliIlce.isNotEmpty);

  List<Hizmet> get _yerelKayitlar {
    final List<Hizmet> tumKayitlar = {
      for (final h in [
        ..._eczaneler,
        ..._hastaneler,
        ..._atmler,
        ..._taksiler,
        ..._noterler,
        ..._oteller,
        ..._veterinerler,
        ..._sarjIstasyonlari,
        ..._kargolar,
        ..._otogarlar,
        ..._havaalanlari,
        ..._avmler,
      ])
        '${h.id}|${h.kategori}': h,
    }.values.toList();

    /// GPS modunda hizmetler zaten gerçek konuma göre 30 km
    /// içerisinden alınmıştır. Burada il/ilçe filtresi YOK.
    if (_gpsModu) {
      return tumKayitlar;
    }

    /// Manuel modda yalnızca kullanıcının seçtiği il/ilçe.
    return tumKayitlar.where((h) {
      final bool ayniIl = aramaMetni(h.il) == aramaMetni(_seciliIl);
      if (!ayniIl) return false;

      // Havaalanları ilçe sınırına bağlı kalmadan il genelinde gösterilir.
      // Böylece örneğin merkez ilçede olan kullanıcı aynı ilin havalimanını
      // yine görebilir.
      if (h.kategori == 'Havaalanı' || h.kategori == 'AVM & Outlet') {
        return true;
      }

      return aramaMetni(h.ilce) == aramaMetni(_seciliIlce);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _yanipSonme.value = !_yanipSonme.value;
    });

    unawaited(_turkiyeGetir());
    _konumuGetir();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _yanipSonme.dispose();
    _yerelHizmetServisi.dispose();
    _aramaBekleme?.cancel();
    _aramaController.dispose();
    _aramaFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  EnobetTemaRenkleri get _tema => context.enobetTema;

  bool get _koyuTema => _tema.koyu;
  bool get _gumusTema => _tema.gumus;

  Color get _arkaPlan => _tema.arkaPlan;
  Color get _kartRengi => _tema.kart;
  Color get _ikinciKartRengi => _tema.ikinciKart;
  Color get _anaYazi => _tema.anaYazi;
  Color get _ikincilYazi => _tema.ikincilYazi;

  void _aramaTemizle() {
    _aramaController.clear();

    setState(() {
      _aramaMetni = '';
    });

    _aramaFocusNode.requestFocus();
  }

  void _gpsOnbellegiTemizle() {
    _gpsYerelOnbellek = null;
    _gpsYerelBekleyenIslem = null;
  }

  Future<List<Hizmet>> _gpsYerelTumunuGetir() async {
    if (!_gpsModu || _mevcutKonum == null) {
      return const <Hizmet>[];
    }

    if (_gpsYerelOnbellek != null) {
      return _gpsYerelOnbellek!;
    }

    final capturedPosition = _mevcutKonum;
    final Future<List<Hizmet>> pending = _gpsYerelBekleyenIslem ??=
        _yerelHizmetServisi.yakindakiTumHizmetleriGetir(
          konum: _mevcutKonum!,
          yaricapKm: _gpsYaricapKm,
        );

    try {
      final List<Hizmet> sonuc = await pending;

      if (_gpsModu && identical(capturedPosition, _mevcutKonum)) {
        _gpsYerelOnbellek = sonuc;
      }

      return sonuc;
    } finally {
      if (identical(_gpsYerelBekleyenIslem, pending)) {
        _gpsYerelBekleyenIslem = null;
      }
    }
  }

  double _gpsKategoriYaricapiKm(String kategori) {
    return switch (kategori) {
      'ATM' => 5,
      'Taksi' => 5,
      'Veteriner' => 20,
      'Elektrikli Şarj İstasyonu' => 20,
      _ => _gpsYaricapKm,
    };
  }

  bool _ilGeneliFallbackKategorisi(String kategori) {
    return kategori == 'Noter';
  }

  Future<List<Hizmet>> _ilGeneliKategoriKayitlariniGetir(
    String kategori,
  ) async {
    final String il = _seciliIl.trim();
    if (il.isEmpty) {
      return const <Hizmet>[];
    }

    final List<Hizmet> tumKayitlar = await _yerelHizmetServisi.tumu();
    final List<Hizmet> ilGeneli = tumKayitlar
        .where((h) => h.kategori == kategori && h.il == il)
        .toList();

    return mesafeyeGoreSirala(ilGeneli, _mevcutKonum);
  }

  Future<List<Hizmet>> _yerelKategoriVerisiniGetir(String kategori) async {
    if (_gpsModu && _mevcutKonum != null) {
      final List<Hizmet> tumu = await _gpsYerelTumunuGetir();
      final double maksimumMetre = _gpsKategoriYaricapiKm(kategori) * 1000;
      final Position konum = _mevcutKonum!;

      final List<Hizmet> sonuc = tumu.where((h) {
        if (h.kategori != kategori) return false;
        if (!h.enlem.isFinite ||
            !h.boylam.isFinite ||
            h.enlem == 0 ||
            h.boylam == 0 ||
            h.enlem.abs() > 90 ||
            h.boylam.abs() > 180) {
          return false;
        }

        return Geolocator.distanceBetween(
              konum.latitude,
              konum.longitude,
              h.enlem,
              h.boylam,
            ) <=
            maksimumMetre;
      }).toList();

      if (sonuc.isNotEmpty || !_ilGeneliFallbackKategorisi(kategori)) {
        return mesafeyeGoreSirala(sonuc, konum);
      }

      // Noter kaydı yakın çevrede bulunamazsa il genelindeki kayıtları
      // en yakından uzağa doğru göstermeyi deneriz.
      return _ilGeneliKategoriKayitlariniGetir(kategori);
    }

    if (_seciliIl.isEmpty || _seciliIlce.isEmpty) {
      return const <Hizmet>[];
    }

    final List<Hizmet> ilceSonucu = await _yerelHizmetServisi.getir(
      kategori: kategori,
      il: _seciliIl,
      ilce: _seciliIlce,
    );

    if (ilceSonucu.isNotEmpty || !_ilGeneliFallbackKategorisi(kategori)) {
      return ilceSonucu;
    }

    // Manuel il/ilçe seçiminde seçilen ilçede noter kaydı yoksa
    // aynı ilin diğer ilçelerindeki kayıtları da erişilebilir tut.
    return _ilGeneliKategoriKayitlariniGetir(kategori);
  }

  Future<List<String>> _gpsEczaneIlleriniGetir() async {
    final konum = _mevcutKonum;
    if (!_gpsModu || konum == null) return const <String>[];
    final iller = await _yerelHizmetServisi.yakinIlleriGetir(
      konum: konum,
      yaricapKm: _gpsYaricapKm,
    );
    if (_seciliIl.isNotEmpty && !iller.contains(_seciliIl)) {
      iller.add(_seciliIl);
    }
    return iller;
  }

  Future<Position?> _seciliKonumKoordinatiniGetir() async {
    final String il = _seciliIl.trim();
    final String ilce = _seciliIlce.trim();

    if (il.isEmpty || ilce.isEmpty) {
      return null;
    }

    Position merkezPosition(double enlem, double boylam, {double accuracy = 250}) {
      return Position(
        latitude: enlem,
        longitude: boylam,
        timestamp: DateTime.now(),
        accuracy: accuracy,
        altitude: 0,
        altitudeAccuracy: 1000,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    /// Manuel il/ilçe seçiminde önce gerçek yerleşim merkezini arıyoruz.
    /// İdari sınırın geometrik merkezi bazı ilçelerde köylere kayabildiği
    /// için place=city/town sonuçlarına yüksek öncelik veriyoruz.
    try {
      final Uri url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$ilce, $il, Türkiye',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '10',
        'countrycodes': 'tr',
        'accept-language': 'tr',
      });

      final http.Response response = await http
          .get(url, headers: nominatimBasliklari())
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic veri = jsonDecode(response.body);

        if (veri is List) {
          Map<String, dynamic>? enIyiAday;
          int enIyiPuan = -100000;

          final String hedefIl = _aramaIcinDuzenle(il);
          final String hedefIlce = _aramaIcinDuzenle(ilce);

          for (final dynamic item in veri) {
            if (item is! Map) continue;

            final Map<String, dynamic> aday = Map<String, dynamic>.from(item);
            final dynamic adresDynamic = aday['address'];
            final Map<String, dynamic> adres = adresDynamic is Map
                ? Map<String, dynamic>.from(adresDynamic)
                : <String, dynamic>{};

            final String adayIl = _aramaIcinDuzenle(
              _ilkDoluKonumDegeri([
                adres['state'],
                adres['province'],
                adres['region'],
              ]),
            );

            if (adayIl.isNotEmpty && adayIl != hedefIl) {
              continue;
            }

            final String tip =
                (aday['type'] ?? aday['addresstype'] ?? '').toString().toLowerCase();
            final String adresTipi =
                (aday['addresstype'] ?? '').toString().toLowerCase();
            final String sinif =
                (aday['class'] ?? aday['category'] ?? '').toString().toLowerCase();
            final String display =
                _aramaIcinDuzenle((aday['display_name'] ?? '').toString());
            final String adayAdi =
                _aramaIcinDuzenle((aday['name'] ?? '').toString());

            final String adayIlce = _aramaIcinDuzenle(
              _ilkDoluKonumDegeri([
                adres['town'],
                adres['city'],
                adres['municipality'],
                adres['county'],
                adres['city_district'],
                adres['district'],
              ]),
            );

            int puan = 0;

            if (adayAdi == hedefIlce) puan += 130;
            if (adayIlce == hedefIlce) puan += 90;
            if (display.startsWith(hedefIlce)) puan += 45;
            if (display.contains(hedefIl)) puan += 20;

            if (sinif == 'place') puan += 120;
            if (const <String>{'city', 'town', 'municipality'}.contains(tip)) {
              puan += 150;
            }
            if (const <String>{'city', 'town', 'municipality'}.contains(adresTipi)) {
              puan += 120;
            }

            /// Administrative boundary sadece fallback olsun; büyük ilçelerde
            /// sınır centroid'i gerçek yerleşim merkezinden uzaklaşabiliyor.
            if (sinif == 'boundary' || tip == 'administrative') {
              puan -= 40;
            }

            final double? enlem = double.tryParse(aday['lat']?.toString() ?? '');
            final double? boylam = double.tryParse(aday['lon']?.toString() ?? '');

            if (enlem == null ||
                boylam == null ||
                !enlem.isFinite ||
                !boylam.isFinite ||
                enlem.abs() > 90 ||
                boylam.abs() > 180 ||
                (enlem == 0 && boylam == 0)) {
              continue;
            }

            if (puan > enIyiPuan) {
              enIyiPuan = puan;
              enIyiAday = aday;
            }
          }

          if (enIyiAday != null) {
            final double? enlem =
                double.tryParse(enIyiAday['lat']?.toString() ?? '');
            final double? boylam =
                double.tryParse(enIyiAday['lon']?.toString() ?? '');

            if (enlem != null && boylam != null) {
              return merkezPosition(enlem, boylam);
            }
          }
        }
      }
    } catch (_) {
      // İnternet/geocoding hatasında yerel medyan merkez fallback'i kullanılır.
    }

    final center = await _yerelHizmetServisi.bolgeMerkezi(il, ilce);

    if (center == null) return null;

    return merkezPosition(center.$1, center.$2, accuracy: 1000);
  }

  Future<void> _yakinHizmetlerHaritasiniAc() async {
    setState(() {
      _seciliMenu = 1;
    });

    Position? haritaKonumu = _mevcutKonum;

    if (haritaKonumu == null &&
        _seciliIl.isNotEmpty &&
        _seciliIlce.isNotEmpty) {
      haritaKonumu = await _seciliKonumKoordinatiniGetir();
    }

    if (!mounted) return;

    if (_avmler.isEmpty && !_avmlerYukleniyor) {
      await _avmleriGetir();
    }

    if (!mounted) return;

    // Haritadaki Otel kategorisi mesafe yarıçapına göre değil, kullanıcının
    // bulunduğu/seçili idari bölgenin tamamına göre gösterilir.
    List<Hizmet> haritaOtelleri = List<Hizmet>.of(_oteller);
    final String haritaIl = _seciliIl.trim();
    final String haritaIlce = _seciliIlce.trim();

    if (haritaIl.isNotEmpty) {
      try {
        if (haritaIlce.isNotEmpty) {
          haritaOtelleri = await YerelHizmetServisi.ortak.getir(
            kategori: 'Otel',
            il: haritaIl,
            ilce: haritaIlce,
          );
        } else {
          final List<Hizmet> tumKayitlar =
              await YerelHizmetServisi.ortak.tumu();
          haritaOtelleri = tumKayitlar
              .where(
                (hizmet) =>
                    hizmet.kategori == 'Otel' && hizmet.il == haritaIl,
              )
              .toList();
        }
        haritaOtelleri = _mesafeleriHesapla(haritaOtelleri);
      } catch (_) {
        // Harita için geniş bölge verisi okunamazsa mevcut otel listesi korunur.
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => YakinHizmetlerHaritasi(
          eczaneler: _eczaneler,
          veterinerler: _veterinerler,
          cekiciler: const <Hizmet>[],
          sarjIstasyonlari: _sarjIstasyonlari,
          otoLastikler: const <Hizmet>[],
          cilingirler: const <Hizmet>[],
          digerHizmetler: <Hizmet>[
            ..._hastaneler,
            ..._atmler,
            ..._taksiler,
            ..._noterler,
            ...haritaOtelleri,
            ..._kargolar,
            ..._otogarlar,
            ..._havaalanlari,
            ..._avmler,
          ],
          mevcutEnlem: haritaKonumu?.latitude,
          mevcutBoylam: haritaKonumu?.longitude,
          gpsKonumu: _gpsModu,

          /// GPS modunda haritaya idari filtre göndermiyoruz.
          il: _gpsModu ? '' : _seciliIl,
          ilce: _gpsModu ? '' : _seciliIlce,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _seciliMenu = 0;
    });
  }

  Future<void> _herseyBuradaAc() async {
    setState(() {
      _seciliMenu = 2;
    });

    Position? ekranKonumu;

    if (_gpsModu) {
      ekranKonumu = _mevcutKonum;
    } else if (_seciliIl.isNotEmpty && _seciliIlce.isNotEmpty) {
      ekranKonumu = await _seciliKonumKoordinatiniGetir();
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HerseyBuradaEkrani(
          eczaneler: _eczaneler,
          veterinerler: _veterinerler,
          sarjIstasyonlari: _sarjIstasyonlari,
          digerHizmetler: <Hizmet>[
            ..._hastaneler,
            ..._atmler,
            ..._taksiler,
            ..._noterler,
            ..._oteller,
            ..._kargolar,
            ..._otogarlar,
            ..._havaalanlari,
            ..._avmler,
          ],
          mevcutEnlem: ekranKonumu?.latitude,
          mevcutBoylam: ekranKonumu?.longitude,
          gpsKonumu: _gpsModu,
          il: _seciliIl,
          ilce: _seciliIlce,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _seciliMenu = 0;
    });
  }

  Future<void> _dadiAc() async {
    setState(() {
      _seciliMenu = 3;
    });

    final String? eylem = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DadiEkrani(
          il: _seciliIl,
          ilce: _seciliIlce,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _seciliMenu = 0;
    });

    if (eylem == null || eylem.trim().isEmpty) return;

    if (eylem == 'yakinimdaki') {
      await _yakinHizmetlerHaritasiniAc();
      return;
    }

    if (eylem == 'acil') {
      _acilHatlariAc();
      return;
    }

    if (eylem == 'akaryakit') {
      _akaryakitFiyatlariniAc();
      return;
    }

    if (eylem == 'doviz') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DovizKurlariEkrani(),
        ),
      );
      return;
    }

    if (eylem == 'hava') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HavaDurumuEkrani(
            baslangicIl: _seciliIl,
            baslangicIlce: _seciliIlce,
            baslangicEnlem: _mevcutKonum?.latitude,
            baslangicBoylam: _mevcutKonum?.longitude,
            gpsKonumu: _gpsModu,
          ),
        ),
      );
      return;
    }

    if (eylem == 'yol_asistani') {
      _yolAsistaniYakinda();
      return;
    }

    _aramaBekleme?.cancel();
    _aramaController.clear();

    setState(() {
      _aramaMetni = '';
      _seciliKategori = eylem;
      _gorunenAdet = 50;
    });

    await _kategoriYerelVerisiniGetir(eylem);

    if (!mounted) return;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _profilAc() async {
    setState(() {
      _seciliMenu = 4;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Profil()),
    );

    if (!mounted) return;

    setState(() {
      _seciliMenu = 0;
    });
  }

  Future<Map<String, String>> _nominatimdanKonumGetir(Position konum) async {
    final Uri url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': konum.latitude.toString(),
      'lon': konum.longitude.toString(),
      'format': 'jsonv2',
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'tr',
    });

    final response = await http
        .get(url, headers: nominatimBasliklari())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception(
        'Konum adresi alınamadı. Sunucu kodu: '
        '${response.statusCode}',
      );
    }

    final dynamic veri = jsonDecode(response.body);

    if (veri is! Map<String, dynamic>) {
      throw Exception('Konum adres bilgisi geçersiz.');
    }

    final dynamic adres = veri['address'];

    if (adres is! Map) {
      throw Exception('Konum adres bilgisi bulunamadı.');
    }

    final String il = _ilkDoluKonumDegeri([
      adres['state'],
      adres['province'],
      adres['region'],
    ]);

    final String ilce = _ilkDoluKonumDegeri([
      adres['county'],
      adres['town'],
      adres['municipality'],
      adres['city_district'],
      adres['district'],
      adres['city'],
      adres['suburb'],
    ]);

    return {'il': _konumMetniniTemizle(il), 'ilce': _konumMetniniTemizle(ilce)};
  }

  String _ilkDoluKonumDegeri(List<dynamic> degerler) {
    for (final dynamic deger in degerler) {
      if (deger == null) continue;

      final String metin = deger.toString().trim();

      if (metin.isNotEmpty) {
        return metin;
      }
    }

    return '';
  }

  Future<void> _konumuGetir() async {
    if (!mounted) return;

    final int version = ++_konumSurumu;
    _bolgeSurumu++;

    setState(() {
      _konumYukleniyor = true;
      _konumHatasi = null;

      _eczaneHatasi = null;
      _hastaneHatasi = null;
      _atmHatasi = null;
      _taksiHatasi = null;
      _kargoHatasi = null;
      _otogarHatasi = null;
      _veterinerHatasi = null;
      _cekiciHatasi = null;
      _sarjIstasyonuHatasi = null;
      _otoLastikHatasi = null;
      _cilingirHatasi = null;
    });

    try {
      LocationPermission izin = await Geolocator.checkPermission();

      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }

      if (izin == LocationPermission.denied) {
        throw Exception('Konum izni verilmedi.');
      }

      if (izin == LocationPermission.deniedForever) {
        throw Exception('Konum izni kalıcı olarak reddedildi.');
      }

      final bool servisAcik = await Geolocator.isLocationServiceEnabled();

      if (!servisAcik) {
        throw Exception('Konum servisi kapalı.');
      }

      Position? konum;

      try {
        konum = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        ).timeout(const Duration(seconds: 30));
      } catch (_) {
        konum = await Geolocator.getLastKnownPosition();
      }

      if (konum == null) {
        throw Exception('Telefonun konumu alınamadı.');
      }

      if (!mounted || version != _konumSurumu) {
        return;
      }

      /// GPS başarıyla alındığı anda otomatik moda geçiyoruz.
      ///
      /// İl/ilçe bulunamasa bile yerel hizmetler GPS koordinatına
      /// göre 30 km içinde gösterilebilecek.
      setState(() {
        _manuelKonumSecildi = false;
        _mevcutKonum = konum;
        _gpsOnbellegiTemizle();
      });

      String bulunanIl = '';
      String bulunanIlce = '';

      /// İl / ilçe artık GPS filtresi için değil, yalnızca ekranda
      /// konum adı göstermek ve eczane API'sine yardımcı olmak için
      /// bulunuyor.
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          konum.latitude,
          konum.longitude,
        ).timeout(const Duration(seconds: 8));

        if (placemarks.isNotEmpty) {
          final Placemark yer = placemarks.first;

          bulunanIl = _ilkDoluKonumDegeri([
            yer.administrativeArea,
            yer.subAdministrativeArea,
            yer.locality,
          ]);

          bulunanIlce = _ilkDoluKonumDegeri([
            yer.subAdministrativeArea,
            yer.locality,
            yer.subLocality,
          ]);
        }
      } catch (_) {}

      String eslesmisIl = _ilAdiEsle(bulunanIl);

      String eslesmisIlce = eslesmisIl.isEmpty
          ? ''
          : _ilceAdiEsle(eslesmisIl, bulunanIlce);

      if (eslesmisIl.isEmpty || eslesmisIlce.isEmpty) {
        try {
          final Map<String, String> nominatimKonumu =
              await _nominatimdanKonumGetir(konum);

          if (eslesmisIl.isEmpty) {
            bulunanIl = nominatimKonumu['il'] ?? '';
          }

          if (eslesmisIlce.isEmpty) {
            bulunanIlce = nominatimKonumu['ilce'] ?? '';
          }
        } catch (_) {}
      }

      eslesmisIl = _ilAdiEsle(bulunanIl);

      if (eslesmisIl.isNotEmpty) {
        eslesmisIlce = _ilceAdiEsle(eslesmisIl, bulunanIlce);

        if (eslesmisIlce.isEmpty) {
          final List<String> ilceler = konumVerileri[eslesmisIl] ?? [];

          for (final String kayitliIlce in ilceler) {
            if (_aramaIcinDuzenle(kayitliIlce).contains('merkez')) {
              eslesmisIlce = kayitliIlce;
              break;
            }
          }
        }
      }

      if (!mounted || version != _konumSurumu) {
        return;
      }

      setState(() {
        _manuelKonumSecildi = false;
        _mevcutKonum = konum;

        _seciliIl = eslesmisIl;
        _seciliIlce = eslesmisIlce;

        _konumYukleniyor = false;
        _konumHatasi = null;

        _eczaneler = [];
        _hastaneler = [];
        _atmler = [];
        _taksiler = [];
        _veterinerler = [];
        _sarjIstasyonlari = [];
        _kargolar = [];
        _otogarlar = [];
        _cekiciler = [];
        _otoLastikler = [];
        _cilingirlar = [];

        _gpsOnbellegiTemizle();
      });

      await _tumHizmetleriGetir();

      if (_seciliKategori != null &&
          const <String>{
            'Kargo',
            'Otogar',
            'Havaalanı',
            'AVM & Outlet',
          }.contains(_seciliKategori)) {
        await _kategoriYerelVerisiniGetir(_seciliKategori!);
      }
    } catch (_) {
      if (!mounted || version != _konumSurumu) {
        return;
      }

      setState(() {
        _mevcutKonum = null;
        _manuelKonumSecildi = false;
        _gpsOnbellegiTemizle();

        _konumYukleniyor = false;

        _konumHatasi = 'Otomatik konum alınamadı. İl ve ilçe seçerek hizmetleri kullanabilirsiniz.';

        _eczaneler = [];
        _hastaneler = [];
        _atmler = [];
        _taksiler = [];
        _noterler = [];
        _kargolar = [];
        _otogarlar = [];
        _veterinerler = [];
        _cekiciler = [];
        _sarjIstasyonlari = [];
        _otoLastikler = [];
        _cilingirlar = [];
      });
    }
  }

  String _konumMetniniTemizle(String? deger) {
    if (deger == null) {
      return '';
    }

    return deger.replaceAll('Türkiye', '').replaceAll('Turkey', '').trim();
  }

  String _ilAdiEsle(String il) {
    final String temizIl = _aramaIcinDuzenle(il);

    if (temizIl.isEmpty) {
      return '';
    }

    for (final String kayitliIl in konumVerileri.keys) {
      if (_aramaIcinDuzenle(kayitliIl) == temizIl) {
        return kayitliIl;
      }
    }

    for (final String kayitliIl in konumVerileri.keys) {
      final String temizKayitliIl = _aramaIcinDuzenle(kayitliIl);

      if (temizIl.contains(temizKayitliIl) ||
          temizKayitliIl.contains(temizIl)) {
        return kayitliIl;
      }
    }

    return '';
  }

  String _ilceAdiEsle(String il, String ilce) {
    final List<String> ilceler = konumVerileri[il] ?? [];

    if (ilceler.isEmpty) {
      return '';
    }

    final String temizIlce = _aramaIcinDuzenle(ilce);

    if (temizIlce.isEmpty) {
      return '';
    }

    for (final String kayitliIlce in ilceler) {
      if (_aramaIcinDuzenle(kayitliIlce) == temizIlce) {
        return kayitliIlce;
      }
    }

    for (final String kayitliIlce in ilceler) {
      final String temizKayitliIlce = _aramaIcinDuzenle(kayitliIlce);

      if (temizIlce.contains(temizKayitliIlce) ||
          temizKayitliIlce.contains(temizIlce)) {
        return kayitliIlce;
      }
    }

    final String temizIl = _aramaIcinDuzenle(il);

    String ilcesizMetin = temizIlce;

    if (ilcesizMetin.startsWith('$temizIl ')) {
      ilcesizMetin = ilcesizMetin.substring(temizIl.length).trim();
    }

    if (ilcesizMetin.isNotEmpty) {
      for (final String kayitliIlce in ilceler) {
        final String temizKayitliIlce = _aramaIcinDuzenle(kayitliIlce);

        if (ilcesizMetin == temizKayitliIlce ||
            ilcesizMetin.contains(temizKayitliIlce) ||
            temizKayitliIlce.contains(ilcesizMetin)) {
          return kayitliIlce;
        }
      }
    }

    if (temizIlce.contains('merkez')) {
      for (final String kayitliIlce in ilceler) {
        if (_aramaIcinDuzenle(kayitliIlce).contains('merkez')) {
          return kayitliIlce;
        }
      }
    }

    return '';
  }

  String _aramaIcinDuzenle(String metin) {
    return metin
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  Future<void> _eczaneleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _eczanelerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _eczanelerYukleniyor = true;
      _eczaneHatasi = null;
    });

    try {
      List<Hizmet> data;

      if (_gpsModu && _mevcutKonum != null) {
        final konum = _mevcutKonum!;
        final List<String> iller = await _gpsEczaneIlleriniGetir();
        if (!active()) return;

        if (iller.isEmpty) {
          throw Exception('GPS çevresindeki il bilgisi belirlenemedi.');
        }

        data = await _eczaneServisi.nobetciEczaneleriGpsGetir(
          konum: konum,
          iller: iller,
          yaricapKm: _gpsYaricapKm,
        );
      } else {
        data = await _eczaneServisi.nobetciEczaneleriGetir(
          il: _seciliIl,
          ilce: _seciliIlce,
        );
      }

      if (!active()) return;

      setState(() {
        _eczaneler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _eczaneHatasi = 'Nöbetçi Eczane verisi alınamadı. İnternet bağlantısını kontrol edip yeniden deneyin.';
      });
    } finally {
      if (active()) {
        setState(() {
          _eczanelerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _hastaneleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _hastanelerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _hastanelerYukleniyor = true;
      _hastaneHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Hastane');

      if (!active()) return;

      setState(() {
        _hastaneler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _hastaneHatasi =
            'Hastane veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _hastanelerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _atmleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _atmlerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _atmlerYukleniyor = true;
      _atmHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('ATM');

      if (!active()) return;

      setState(() {
        _atmler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _atmHatasi = 'ATM veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _atmlerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _taksileriGetir() async {
    if (!mounted || !_konumKullanilabilir || _taksilerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _taksilerYukleniyor = true;
      _taksiHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Taksi');

      if (!active()) return;

      setState(() {
        _taksiler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _taksiHatasi = 'Taksi veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _taksilerYukleniyor = false;
        });
      }
    }
  }


  Future<void> _noterleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _noterlerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _noterlerYukleniyor = true;
      _noterHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Noter');

      if (!active()) return;

      final List<Hizmet> sirali = _mesafeleriHesapla(data);

      setState(() {
        _noterler = sirali;
        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _noterHatasi =
            'Noter veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _noterlerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _otelleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _otellerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _otellerYukleniyor = true;
      _otelHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Otel');

      if (!active()) return;

      setState(() {
        _oteller = _mesafeleriHesapla(data);
        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _otelHatasi = 'Otel veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _otellerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _veterinerleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _veterinerlerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _veterinerlerYukleniyor = true;
      _veterinerHatasi = null;
    });

    try {
      final List<Hizmet> yerelData =
          await _yerelKategoriVerisiniGetir('Veteriner');

      if (!active()) return;

      List<Hizmet> canliData = const <Hizmet>[];

      // Statik katalogda eksik kalan veterinerleri canlı Overpass verisiyle
      // tamamla. Canlı kaynak geçici olarak çalışmazsa statik veri korunur.
      if (_seciliIl.isNotEmpty && _seciliIlce.isNotEmpty) {
        try {
          canliData = await _veterinerServisi.veterinerleriGetir(
            il: _seciliIl,
            ilce: _seciliIlce,
          );
        } catch (_) {
          canliData = const <Hizmet>[];
        }
      }

      if (!active()) return;

      final Map<String, Hizmet> birlesik = <String, Hizmet>{};

      String anahtar(Hizmet h) {
        final String ad = _aramaIcinDuzenle(h.isim);
        final String lat = h.enlem.toStringAsFixed(4);
        final String lon = h.boylam.toStringAsFixed(4);
        return '$ad|$lat|$lon';
      }

      for (final Hizmet h in yerelData) {
        birlesik[anahtar(h)] = h;
      }

      for (final Hizmet h in canliData) {
        birlesik.putIfAbsent(anahtar(h), () => h);
      }

      List<Hizmet> sonuc = birlesik.values.toList();

      // GPS modunda canlı sonuçlara da Veteriner için mevcut 20 km sınırını
      // uygula; manuel il/ilçe seçiminde seçilen ilçenin tamamını göster.
      if (_gpsModu && _mevcutKonum != null) {
        final Position konum = _mevcutKonum!;
        final double maksimumMetre =
            _gpsKategoriYaricapiKm('Veteriner') * 1000;

        sonuc = sonuc.where((h) {
          if (!h.enlem.isFinite ||
              !h.boylam.isFinite ||
              h.enlem == 0 ||
              h.boylam == 0) {
            return false;
          }

          return Geolocator.distanceBetween(
                konum.latitude,
                konum.longitude,
                h.enlem,
                h.boylam,
              ) <=
              maksimumMetre;
        }).toList();
      }

      setState(() {
        _veterinerler = _mesafeleriHesapla(sonuc);
        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _veterinerHatasi =
            'Veteriner veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _veterinerlerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _sarjIstasyonlariniGetir() async {
    if (!mounted || !_konumKullanilabilir || _sarjIstasyonlariYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _sarjIstasyonlariYukleniyor = true;
      _sarjIstasyonuHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir(
        'Elektrikli Şarj İstasyonu',
      );

      if (!active()) return;

      setState(() {
        _sarjIstasyonlari = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _sarjIstasyonuHatasi = 'Elektrikli Şarj İstasyonu veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _sarjIstasyonlariYukleniyor = false;
        });
      }
    }
  }

  Future<void> _kargolariGetir() async {
    if (!mounted || !_konumKullanilabilir || _kargolarYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _kargolarYukleniyor = true;
      _kargoHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Kargo');

      if (!active()) return;

      setState(() {
        _kargolar = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _kargoHatasi = 'Kargo veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _kargolarYukleniyor = false;
        });
      }
    }
  }

  Future<void> _otogarlariGetir() async {
    if (!mounted || !_konumKullanilabilir || _otogarlarYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _otogarlarYukleniyor = true;
      _otogarHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Otogar');

      if (!active()) return;

      setState(() {
        _otogarlar = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _otogarHatasi =
            'Otogar veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _otogarlarYukleniyor = false;
        });
      }
    }
  }


  Future<void> _cekicileriGetir() async {
    if (!mounted || !_konumKullanilabilir || _cekicilerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _cekicilerYukleniyor = true;
      _cekiciHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Çekici');

      if (!active()) return;

      setState(() {
        _cekiciler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _cekiciHatasi =
            'Çekici veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _cekicilerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _otoLastikleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _otoLastiklerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _otoLastiklerYukleniyor = true;
      _otoLastikHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Oto Lastik');

      if (!active()) return;

      setState(() {
        _otoLastikler = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _otoLastikHatasi =
            'Oto Lastik veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _otoLastiklerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _cilingirlariGetir() async {
    if (!mounted || !_konumKullanilabilir || _cilingirlarYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;

    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _cilingirlarYukleniyor = true;
      _cilingirHatasi = null;
    });

    try {
      final data = await _yerelKategoriVerisiniGetir('Çilingir');

      if (!active()) return;

      setState(() {
        _cilingirlar = _mesafeleriHesapla(data);

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;

      setState(() {
        _cilingirHatasi =
            'Çilingir veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _cilingirlarYukleniyor = false;
        });
      }
    }
  }

  Future<void> _avmleriGetir() async {
    if (!mounted || !_konumKullanilabilir || _avmlerYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;
    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _avmlerYukleniyor = true;
      _avmHatasi = null;
    });

    try {
      final List<Hizmet> sonuc = await _avmServisi.getir(
        il: _seciliIl,
        ilce: _seciliIlce,
        gpsModu: _gpsModu,
        enlem: _mevcutKonum?.latitude,
        boylam: _mevcutKonum?.longitude,
        yaricapKm: _gpsYaricapKm,
      );

      if (!active()) return;

      final List<Hizmet> sirali = _mesafeleriHesapla(sonuc);

      setState(() {
        _avmler = sirali;

        // Türkiye aramasında, o oturumda çekilmiş AVM sonuçları da bulunabilsin.
        final Map<String, Hizmet> birlesik = <String, Hizmet>{
          for (final Hizmet h in _turkiyeHizmetleri)
            '${h.id}|${h.kategori}': h,
          for (final Hizmet h in sirali)
            '${h.id}|${h.kategori}': h,
        };
        _turkiyeHizmetleri = birlesik.values.toList();

        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;
      setState(() {
        _avmler = [];
        _avmHatasi =
            'AVM / Outlet verisi şu an alınamadı. İnternet bağlantınızı kontrol edip yeniden deneyin.';
      });
    } finally {
      if (active()) {
        setState(() {
          _avmlerYukleniyor = false;
        });
      }
    }
  }

  Future<void> _havaalanlariniGetir() async {
    if (!mounted || !_konumKullanilabilir || _havaalanlariYukleniyor) {
      return;
    }

    final int version = _bolgeSurumu;
    bool active() => mounted && version == _bolgeSurumu;

    setState(() {
      _havaalanlariYukleniyor = true;
      _havaalaniHatasi = null;
    });

    try {
      final List<Hizmet> tumKayitlar = await _yerelHizmetServisi.tumu();
      List<Hizmet> sonuc = tumKayitlar
          .where((h) => h.kategori == 'Havaalanı')
          .toList();

      if (!_gpsModu && _seciliIl.isNotEmpty) {
        final List<Hizmet> ilIci = sonuc
            .where((h) => aramaMetni(h.il) == aramaMetni(_seciliIl))
            .toList();

        // Seçilen ilde havaalanı varsa yalnızca o ilin havaalanlarını göster.
        // Yoksa en yakın seçenekleri sıralamak için Türkiye listesini koru.
        if (ilIci.isNotEmpty) {
          sonuc = ilIci;
        }
      }

      sonuc = _mesafeleriHesapla(sonuc);

      // GPS modunda veya seçilen ilde havaalanı bulunmadığında ekranı
      // gereksiz kalabalıklaştırmadan en yakın seçenekleri göster.
      if (_gpsModu ||
          (_seciliIl.isNotEmpty &&
              !sonuc.any(
                (h) => aramaMetni(h.il) == aramaMetni(_seciliIl),
              ))) {
        sonuc = sonuc.take(8).toList();
      }

      if (!active()) return;
      setState(() {
        _havaalanlari = sonuc;
        _veriSurumu++;
      });
    } catch (_) {
      if (!active()) return;
      setState(() {
        _havaalaniHatasi =
            'Havaalanı veri paketi açılamadı. Uygulamayı yeniden açın.';
      });
    } finally {
      if (active()) {
        setState(() {
          _havaalanlariYukleniyor = false;
        });
      }
    }
  }

  Future<void> _kategoriYerelVerisiniGetir(String kategori) async {
    switch (kategori) {
      case 'Nöbetçi Eczane':
        await _eczaneleriGetir();
        break;

      case 'Hastane':
        await _hastaneleriGetir();
        break;

      case 'ATM':
        await _atmleriGetir();
        break;

      case 'Taksi':
        await _taksileriGetir();
        break;

      case 'Noter':
        await _noterleriGetir();
        break;

      case 'Otel':
        await _otelleriGetir();
        break;

      case 'Veteriner':
        await _veterinerleriGetir();
        break;

      case 'Kargo':
        await _kargolariGetir();
        break;

      case 'Otogar':
        await _otogarlariGetir();
        break;

      case 'Havaalanı':
        await _havaalanlariniGetir();
        break;

      case 'AVM & Outlet':
        await _avmleriGetir();
        break;

      case 'Çekici':
        await _cekicileriGetir();
        break;

      case 'Oto Lastik':
        await _otoLastikleriGetir();
        break;

      case 'Çilingir':
        await _cilingirlariGetir();
        break;

      case 'Elektrikli Şarj İstasyonu':
        await _sarjIstasyonlariniGetir();
        break;
    }
  }

  Future<void> _tumHizmetleriGetir() async {
    if (!mounted || !_konumKullanilabilir) {
      return;
    }

    _bolgeSurumu++;

    setState(() {
      _eczaneler = [];
      _eczanelerYukleniyor = false;
      _eczaneHatasi = null;

      _hastaneler = [];
      _hastanelerYukleniyor = false;
      _hastaneHatasi = null;

      _atmler = [];
      _atmlerYukleniyor = false;
      _atmHatasi = null;

      _taksiler = [];
      _taksilerYukleniyor = false;
      _taksiHatasi = null;

      _noterler = [];
      _noterlerYukleniyor = false;
      _noterHatasi = null;

      _oteller = [];
      _otellerYukleniyor = false;
      _otelHatasi = null;

      _veterinerler = [];
      _veterinerlerYukleniyor = false;
      _veterinerHatasi = null;

      _sarjIstasyonlari = [];
      _sarjIstasyonlariYukleniyor = false;
      _sarjIstasyonuHatasi = null;

      _kargolar = [];
      _kargolarYukleniyor = false;
      _kargoHatasi = null;

      _otogarlar = [];
      _otogarlarYukleniyor = false;
      _otogarHatasi = null;

      _havaalanlari = [];
      _havaalanlariYukleniyor = false;
      _havaalaniHatasi = null;

      _avmler = [];
      _avmlerYukleniyor = false;
      _avmHatasi = null;

      _cekiciler = [];
      _cekicilerYukleniyor = false;
      _cekiciHatasi = null;

      _otoLastikler = [];
      _otoLastiklerYukleniyor = false;
      _otoLastikHatasi = null;

      _cilingirlar = [];
      _cilingirlarYukleniyor = false;
      _cilingirHatasi = null;

      _veriSurumu++;
    });

    await Future.wait([
      _eczaneleriGetir(),
      _hastaneleriGetir(),
      _atmleriGetir(),
      _taksileriGetir(),
      _noterleriGetir(),
      _otelleriGetir(),
      _veterinerleriGetir(),
      _sarjIstasyonlariniGetir(),
      _kargolariGetir(),
      _otogarlariGetir(),
    ]);
  }

  List<Hizmet> _mesafeleriHesapla(List<Hizmet> liste) =>
      mesafeyeGoreSirala(liste, _mevcutKonum);

  Object? _sonFiltreAnahtari;

  List<Hizmet> _sonFiltreSonucu = [];

  List<Hizmet> get _filtreliHizmetler {
    final bool searching = _aramaMetni.trim().isNotEmpty;

    final key = (
      _aramaMetni,
      _seciliKategori,
      _mevcutKonum,
      _manuelKonumSecildi,
      _turkiyeHizmetleri,
      _veriSurumu,
      _seciliIl,
      _seciliIlce,
    );

    if (_sonFiltreAnahtari == key) {
      return _sonFiltreSonucu;
    }

    _sonFiltreAnahtari = key;

    final Iterable<Hizmet> kaynak = searching
        ? _turkiyeHizmetleri.where((h) => hizmetEslesir(h, _aramaMetni))
        : _yerelKayitlar.where((h) {
            if (_seciliKategori == null) {
              return true;
            }

            return h.kategori == _seciliKategori;
          });

    return _sonFiltreSonucu = _mesafeleriHesapla(kaynak.toList());
  }

  bool get _herhangiHizmetYukleniyor {
    return _eczanelerYukleniyor ||
        _hastanelerYukleniyor ||
        _atmlerYukleniyor ||
        _taksilerYukleniyor ||
        _noterlerYukleniyor ||
        _otellerYukleniyor ||
        _veterinerlerYukleniyor ||
        _sarjIstasyonlariYukleniyor ||
        _kargolarYukleniyor ||
        _otogarlarYukleniyor ||
        _havaalanlariYukleniyor ||
        _avmlerYukleniyor ||
        _cekicilerYukleniyor ||
        _otoLastiklerYukleniyor ||
        _cilingirlarYukleniyor;
  }

  bool _kategoriYukleniyor(String? kategori) {
    switch (kategori) {
      case 'Nöbetçi Eczane':
        return _eczanelerYukleniyor;

      case 'Hastane':
        return _hastanelerYukleniyor;

      case 'ATM':
        return _atmlerYukleniyor;

      case 'Taksi':
        return _taksilerYukleniyor;

      case 'Noter':
        return _noterlerYukleniyor;

      case 'Otel':
        return _otellerYukleniyor;

      case 'Veteriner':
        return _veterinerlerYukleniyor;

      case 'Elektrikli Şarj İstasyonu':
        return _sarjIstasyonlariYukleniyor;

      case 'Kargo':
        return _kargolarYukleniyor;

      case 'Otogar':
        return _otogarlarYukleniyor;

      case 'Havaalanı':
        return _havaalanlariYukleniyor;

      case 'AVM & Outlet':
        return _avmlerYukleniyor;

      case 'Çekici':
        return _cekicilerYukleniyor;

      case 'Oto Lastik':
        return _otoLastiklerYukleniyor;

      case 'Çilingir':
        return _cilingirlarYukleniyor;

      default:
        return _aramaMetni.trim().isNotEmpty
            ? _turkiyeYukleniyor
            : _herhangiHizmetYukleniyor;
    }
  }

  List<String> get _bulunamayanHizmetler {
    if (_seciliKategori != null || _aramaMetni.trim().isNotEmpty) {
      return const <String>[];
    }

    final List<String> sonuc = <String>[];

    void ekle(
      String ad,
      List<Hizmet> hizmetler,
      bool yukleniyor,
      String? hata,
    ) {
      if (hata != null) {
        sonuc.add('$ad bilgisi şu an alınamadı.');
      } else if (!yukleniyor && hizmetler.isEmpty) {
        sonuc.add('$ad hizmeti bulunmamaktadır.');
      }
    }

    ekle('Nöbetçi eczane', _eczaneler, _eczanelerYukleniyor, _eczaneHatasi);

    ekle('Hastane', _hastaneler, _hastanelerYukleniyor, _hastaneHatasi);

    ekle('ATM', _atmler, _atmlerYukleniyor, _atmHatasi);

    ekle('Taksi', _taksiler, _taksilerYukleniyor, _taksiHatasi);

    ekle('Noter', _noterler, _noterlerYukleniyor, _noterHatasi);

    ekle('Otel', _oteller, _otellerYukleniyor, _otelHatasi);

    ekle('Veteriner', _veterinerler, _veterinerlerYukleniyor, _veterinerHatasi);

    ekle(
      'Şarj istasyonu',
      _sarjIstasyonlari,
      _sarjIstasyonlariYukleniyor,
      _sarjIstasyonuHatasi,
    );

    return sonuc;
  }

  String? get _seciliKategoriHatasi {
    switch (_seciliKategori) {
      case 'Nöbetçi Eczane':
        return _eczaneHatasi;

      case 'Hastane':
        return _hastaneHatasi;

      case 'ATM':
        return _atmHatasi;

      case 'Taksi':
        return _taksiHatasi;

      case 'Noter':
        return _noterHatasi;

      case 'Otel':
        return _otelHatasi;

      case 'Veteriner':
        return _veterinerHatasi;

      case 'Elektrikli Şarj İstasyonu':
        return _sarjIstasyonuHatasi;

      case 'Kargo':
        return _kargoHatasi;

      case 'Otogar':
        return _otogarHatasi;

      case 'Havaalanı':
        return _havaalaniHatasi;

      case 'AVM & Outlet':
        return _avmHatasi;

      case 'Çekici':
        return _cekiciHatasi;

      case 'Oto Lastik':
        return _otoLastikHatasi;

      case 'Çilingir':
        return _cilingirHatasi;

      default:
        return null;
    }
  }

  void _konumSec() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kartRengi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        String seciliIl = _seciliIl.isEmpty
            ? konumVerileri.keys.first
            : _seciliIl;

        String seciliIlce = _seciliIlce;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<String> ilceler = konumVerileri[seciliIl] ?? [];

            if (!ilceler.contains(seciliIlce)) {
              seciliIlce = ilceler.isNotEmpty ? ilceler.first : '';
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _anaYazi.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Konum Seç',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manuel seçim yaparsanız GPS 30 km modu kapanır ve seçtiğiniz ilçe gösterilir.',
                      style: TextStyle(
                        color: _anaYazi.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'İl',
                      style: TextStyle(
                        color: _anaYazi.withValues(alpha: 0.60),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      decoration: BoxDecoration(
                        color: _ikinciKartRengi,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _anaYazi.withValues(alpha: 0.07),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: seciliIl,
                        dropdownColor: _kartRengi,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 3,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _anaYazi.withValues(alpha: 0.70),
                        ),
                        items: konumVerileri.keys.map((il) {
                          return DropdownMenuItem<String>(
                            value: il,
                            child: Text(
                              il,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (deger) {
                          if (deger == null) {
                            return;
                          }

                          setModalState(() {
                            seciliIl = deger;

                            final List<String> yeniIlceler =
                                konumVerileri[deger] ?? [];

                            seciliIlce = yeniIlceler.isNotEmpty
                                ? yeniIlceler.first
                                : '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'İlçe',
                      style: TextStyle(
                        color: _anaYazi.withValues(alpha: 0.60),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      decoration: BoxDecoration(
                        color: _ikinciKartRengi,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _anaYazi.withValues(alpha: 0.07),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: seciliIlce.isEmpty ? null : seciliIlce,
                        dropdownColor: _kartRengi,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 3,
                          ),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _anaYazi.withValues(alpha: 0.70),
                        ),
                        items: ilceler.map((ilce) {
                          return DropdownMenuItem<String>(
                            value: ilce,
                            child: Text(
                              ilce,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (deger) {
                          if (deger == null) {
                            return;
                          }

                          setModalState(() {
                            seciliIlce = deger;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _konumSurumu++;
                            _bolgeSurumu++;

                            _manuelKonumSecildi = true;

                            _seciliIl = seciliIl;
                            _seciliIlce = seciliIlce;

                            _konumYukleniyor = false;
                            _konumHatasi = null;

                            _mevcutKonum = null;

                            _gpsOnbellegiTemizle();

                            _eczaneler = [];
                            _hastaneler = [];
                            _atmler = [];
                            _taksiler = [];
                            _kargolar = [];
                            _otogarlar = [];
                            _veterinerler = [];
                            _cekiciler = [];
                            _sarjIstasyonlari = [];
                            _otoLastikler = [];
                            _cilingirlar = [];
                          });

                          Navigator.pop(context);

                          final Position? seciliKonum =
                              await _seciliKonumKoordinatiniGetir();

                          if (!mounted ||
                              _seciliIl != seciliIl ||
                              _seciliIlce != seciliIlce ||
                              !_manuelKonumSecildi) {
                            return;
                          }

                          setState(() {
                            /// Bu koordinat yalnızca manuel seçimin
                            /// merkezinden mesafe sıralamak için.
                            /// GPS modu açılmaz çünkü
                            /// _manuelKonumSecildi = true.
                            _mevcutKonum = seciliKonum;
                          });

                          await _tumHizmetleriGetir();

                          if (_seciliKategori != null &&
                              const <String>{
                                'Kargo',
                                'Otogar',
                              }.contains(_seciliKategori)) {
                            await _kategoriYerelVerisiniGetir(_seciliKategori!);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE3262E),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Konumu Uygula',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

  void _acilHatlariAc() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AcilHatlar()),
    ).then((_) {
      if (!mounted) return;

      setState(() {
        _seciliMenu = 0;
      });
    });
  }


  void _akaryakitFiyatlariniAc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AkaryakitFiyatlariEkrani(
          baslangicIl: _seciliIl,
          baslangicIlce: _seciliIlce,
          gpsKonumu: _gpsModu,
        ),
      ),
    );
  }

  void _barkodQrAc({bool otomatikTara = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarkodSorgulamaEkrani(
          otomatikTara: otomatikTara,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Hizmet> filtreliHizmetler = _filtreliHizmetler;

    final List<String> bulunamayanHizmetler = _bulunamayanHizmetler;

    final bool seciliKategoriYukleniyor = _kategoriYukleniyor(_seciliKategori);

    final String? seciliKategoriHatasi = _seciliKategoriHatasi;

    final bool veriYok = filtreliHizmetler.isEmpty;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const ListTile(
                title: Text(
                  'Ek Hizmetler',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              for (final item in const <(String, IconData, Color)>[
                ('Noter', Icons.gavel_rounded, Color(0xFFB58B5B)),
                ('Kargo', Icons.local_shipping_rounded, Color(0xFF8E6CEF)),
                ('Otogar', Icons.directions_bus_rounded, Color(0xFF3A86FF)),
                ('Veteriner', Icons.pets_rounded, Color(0xFF21C064)),
                ('Elektrikli Şarj İstasyonu', Icons.ev_station_rounded, Color(0xFFFF8A00)),
                ('Taksi', Icons.local_taxi_rounded, Color(0xFFFFB020)),
              ])
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.$3.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$2, color: item.$3),
                  ),
                  title: Text(
                    item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: Icon(Icons.chevron_right, color: item.$3),
                  onTap: () {
                    Navigator.pop(context);

                    _aramaController.clear();

                    setState(() {
                      _aramaMetni = '';
                      _seciliKategori = item.$1;
                      _gorunenAdet = 50;
                    });

                    _kategoriYerelVerisiniGetir(item.$1);
                  },
                ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                title: const Text(
                  'Akaryakıt Fiyatları',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Benzin • Motorin • LPG',
                  style: TextStyle(fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFF59E0B),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _akaryakitFiyatlariniAc();
                },
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFFFFA000),
                  ),
                ),
                title: const Text(
                  'Barkod ve QR Sorgulama',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFFFA000),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _barkodQrAc();
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: _arkaPlan,
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE3262E),
          backgroundColor: _kartRengi,
          onRefresh: _konumuGetir,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ustBar(),
              const SizedBox(height: 14),
              _marka(),
              const SizedBox(height: 28),
              _arama(),
              const SizedBox(height: 28),
              _hizmetBasligi(),
              const SizedBox(height: 15),
              _hizmetler(),
              const SizedBox(height: 12),
              _bilgiAlani(),
              const SizedBox(height: 16),
              _yolAsistaniKarti(),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE3262E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.menu_rounded),
                  label: const Text(
                    'Ek Hizmetler',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _yakinBaslik(),
              if (_gpsModu)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Text(
                    'Gerçek konumunuza ${_gpsYaricapKm.toInt()} km yarıçap içindeki hizmetler gösteriliyor.',
                    style: TextStyle(
                      color: _ikincilYazi,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_mevcutKonum == null && !_konumYukleniyor)
                const Text(
                  'Yakından uzağa sıralama için konum izni verin. Mesafesi bilinmeyen kayıtlar sonda gösterilir.',
                ),
              if (_aramaMetni.trim().isNotEmpty && _turkiyeYukleniyor)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      Text('Kayıtlı hizmet listesi açılıyor…'),
                    ],
                  ),
                ),
              if (_aramaMetni.trim().isNotEmpty && _turkiyeHatasi != null)
                TextButton(
                  onPressed: _turkiyeGetir,
                  child: Text('$_turkiyeHatasi Yeniden dene'),
                ),
              if (_turkiyeHizmetleri.isNotEmpty)
                const Text(
                  'OpenStreetMap Katkıcıları ODbL.',
                  style: TextStyle(fontSize: 11),
                ),
              const SizedBox(height: 14),
              if (_konumYukleniyor) _konumBilgiAlani(),
              if (!_konumYukleniyor && _konumHatasi != null) _konumHataAlani(),
              if (!_konumYukleniyor &&
                  _konumHatasi == null &&
                  seciliKategoriYukleniyor &&
                  veriYok)
                _yukleniyorAlani(),
              if (!_konumYukleniyor &&
                  _konumHatasi == null &&
                  !seciliKategoriYukleniyor &&
                  seciliKategoriHatasi != null &&
                  veriYok)
                _hataAlani(hata: seciliKategoriHatasi),
              if (!_konumYukleniyor &&
                  _konumHatasi == null &&
                  !seciliKategoriYukleniyor &&
                  seciliKategoriHatasi == null &&
                  veriYok)
                _sonucYokAlani(),
              if (filtreliHizmetler.isNotEmpty)
                ...filtreliHizmetler
                    .take(_gorunenAdet)
                    .map(
                      (hizmet) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _nobetciKart(
                          hizmet: hizmet,
                          icon: hizmet.ikon,
                          renk: hizmet.renk,
                          baslik: hizmet.isim,
                          adres: hizmet.adres,
                          durum: '${hizmet.durum} • ${hizmet.calismaSaatleri}',
                          mesafe: hizmet.mesafe,
                        ),
                      ),
                    ),
              if (!_konumYukleniyor &&
                  _konumHatasi == null &&
                  !seciliKategoriYukleniyor &&
                  bulunamayanHizmetler.isNotEmpty)
                _bulunamayanHizmetlerAlani(bulunamayanHizmetler),
            ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _altMenu(),
    );
  }

  Widget _konumBilgiAlani() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 17),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE3262E)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Konumunuz alınıyor, mesafeler hesaplanıyor...',
              style: TextStyle(
                color: _anaYazi.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _konumHataAlani() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE3262E).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off_rounded,
            color: _anaYazi.withValues(alpha: 0.40),
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            'Konum alınamadı',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            _konumHatasi!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.50),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _konumuGetir,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3262E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Konumu Tekrar Dene',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yukleniyorAlani() {
    final String mesaj = switch (_seciliKategori) {
      'Nöbetçi Eczane' => 'Nöbetçi eczaneler aranıyor...',
      'Hastane' => 'Hastaneler listeleniyor...',
      'ATM' => 'ATM noktaları listeleniyor...',
      'Taksi' => 'Taksi durakları listeleniyor...',
      'Noter' => 'Noterler listeleniyor...',
      'Otel' => 'Oteller listeleniyor...',
      'Veteriner' => 'Veterinerler listeleniyor...',
      'Elektrikli Şarj İstasyonu' => 'Şarj istasyonları listeleniyor...',
      'Kargo' => 'Kargo noktaları listeleniyor...',
      'Otogar' => 'Otogarlar listeleniyor...',
      'Havaalanı' => 'Havaalanları listeleniyor...',
      'AVM & Outlet' => 'AVM ve outlet merkezleri aranıyor...',
      'Çekici' => 'Çekiciler listeleniyor...',
      'Oto Lastik' => 'Oto lastikçiler listeleniyor...',
      'Çilingir' => 'Çilingirler listeleniyor...',
      _ =>
        _aramaMetni.trim().isNotEmpty
            ? 'Kayıtlı hizmet listesi açılıyor...'
            : 'Hizmetler listeleniyor...',
    };

    final String altMetin;

    if (_aramaMetni.trim().isNotEmpty) {
      altMetin = 'Türkiye geneli';
    } else if (_gpsModu) {
      altMetin = '${_gpsYaricapKm.toInt()} km çevreniz';
    } else {
      altMetin = '$_seciliIl / $_seciliIlce';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE3262E)),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            mesaj,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            altMetin,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hataAlani({required String hata}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE3262E).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: _anaYazi.withValues(alpha: 0.40),
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            hata,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.70),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                if (_aramaMetni.trim().isNotEmpty) {
                  _turkiyeGetir();
                } else if (_seciliKategori != null) {
                  _kategoriYerelVerisiniGetir(_seciliKategori!);
                } else {
                  _tumHizmetleriGetir();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE3262E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Tekrar Dene',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sonucYokAlani() {
    String kapsam;

    if (_gpsModu) {
      kapsam = '${_gpsYaricapKm.toInt()} km çevrenizde';
    } else {
      kapsam = 'Bu ilçede';
    }

    final String mesaj = _aramaMetni.trim().isNotEmpty
        ? 'Aramanızla eşleşen hizmet bulunamadı'
        : switch (_seciliKategori) {
            'Nöbetçi Eczane' => '$kapsam nöbetçi eczane bulunamadı',
            'Hastane' => '$kapsam kayıtlı hastane bulunmuyor',
            'ATM' => '$kapsam kayıtlı ATM bulunmuyor',
            'Taksi' => '$kapsam kayıtlı taksi durağı bulunmuyor',
            'Noter' => '$kapsam kayıtlı noter bulunmuyor',
            'Otel' => '$kapsam kayıtlı otel bulunmuyor',
            'Veteriner' => '$kapsam kayıtlı veteriner bulunmuyor',
            'Elektrikli Şarj İstasyonu' =>
              '$kapsam kayıtlı şarj istasyonu bulunmuyor',
            'Kargo' => '$kapsam kayıtlı kargo noktası bulunmuyor',
            'Otogar' => '$kapsam kayıtlı otogar bulunmuyor',
            'Havaalanı' => 'Yakın veya seçili ilde havaalanı bulunamadı',
            'AVM & Outlet' => '$kapsam AVM veya outlet bulunamadı',
            'Çekici' => '$kapsam kayıtlı çekici bulunmuyor',
            'Oto Lastik' => '$kapsam kayıtlı oto lastik hizmeti bulunmuyor',
            'Çilingir' => '$kapsam kayıtlı çilingir bulunmuyor',
            _ => '$kapsam sonuç bulunamadı',
          };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _kartRengi,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: _anaYazi.withValues(alpha: 0.35),
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            mesaj,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.65),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Bu liste mevcut veri paketindeki kayıtları gösterir; eksik işletmeler olabilir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _anaYazi.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulunamayanHizmetlerAlani(List<String> hizmetler) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ikinciKartRengi,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _anaYazi.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _gpsModu
                ? '30 km çevrenizde bulunmayan hizmetler'
                : 'Bu bölgede bulunmayan hizmetler',
            style: TextStyle(
              color: _anaYazi,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          ...hizmetler.map(
            (mesaj) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $mesaj',
                style: TextStyle(
                  color: _ikincilYazi,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ustBar() {
    String ustKonum;
    String altKonum;

    if (_konumYukleniyor) {
      ustKonum = 'Konum alınıyor...';
      altKonum = 'Belirleniyor';
    } else if (_gpsModu) {
      ustKonum = _seciliIl.isNotEmpty ? _seciliIl : 'Konumunuz';

      altKonum = _seciliIlce.isNotEmpty
          ? '$_seciliIlce • 30 km çevre'
          : '30 km çevreniz';
    } else {
      ustKonum = _seciliIl.isEmpty ? 'Konum bulunamadı' : _seciliIl;

      altKonum = _seciliIlce.isEmpty ? 'Konum seç' : _seciliIlce;
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _konumSec,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3262E).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFE3262E),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ustKonum,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: _anaYazi.withValues(alpha: 0.65),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF20B879),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              altKonum,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _anaYazi.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          height: 60,
          child: ValueListenableBuilder<bool>(
            valueListenable: _yanipSonme,
            builder: (context, parlak, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _koyuTema
                    ? Colors.black
                    : _gumusTema
                        ? const Color(0xFFC8CBD0)
                        : Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: const Color(0xFFE3262E)
                      .withValues(alpha: parlak ? 1.0 : 0.30),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE3262E)
                        .withValues(alpha: parlak ? 0.85 : 0.08),
                    blurRadius: parlak ? 24 : 4,
                    spreadRadius: parlak ? 3 : 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE3262E)
                        .withValues(alpha: parlak ? 1.0 : 0.25),
                    shadows: [
                      Shadow(
                        color: const Color(0xFFE3262E)
                            .withValues(alpha: parlak ? 1.0 : 0.10),
                        blurRadius: parlak ? 22 : 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _marka() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'EN',
                style: TextStyle(
                  color: Color(0xFFE3262E),
                  fontSize: 43,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2.8,
                ),
              ),
              TextSpan(
                text: 'öbet',
                style: TextStyle(
                  color: _anaYazi,
                  fontSize: 43,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'İhtiyacın olan hizmete en hızlı şekilde ulaş.',
          style: TextStyle(
            color: _anaYazi.withValues(alpha: 0.72),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _arama() {
    return Container(
      key: _aramaAnahtari,
      height: 61,
      decoration: BoxDecoration(
        color: _tema.alan,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _anaYazi.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: _aramaController,
        focusNode: _aramaFocusNode,
        onChanged: (deger) {
          _aramaBekleme?.cancel();

          if (deger.trim().isNotEmpty) {
            _aramaBekleme = Timer(
              const Duration(milliseconds: 500),
              _turkiyeGetir,
            );
          }

          setState(() {
            _aramaMetni = deger;

            if (deger.trim().isNotEmpty) {
              _seciliKategori = null;
            }
          });
        },
        style: TextStyle(
          color: _anaYazi,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: _ikincilYazi, size: 26),
          suffixIcon: _aramaMetni.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: _aramaTemizle,
                  icon: Icon(
                    Icons.close_rounded,
                    color: _ikincilYazi,
                    size: 22,
                  ),
                ),
          hintText: 'Ne arıyorsunuz?',
          hintStyle: TextStyle(
            color: _ikincilYazi,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _hizmetBasligi() {
    return const Text(
      'Popüler Hizmetler',
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
    );
  }

  Widget _hizmetler() => Row(
    children: [
      Expanded(
        child: _kategori(
          'Nöbetçi Eczane',
          Icons.local_pharmacy_rounded,
          const Color(0xFFE3262E),
          eLogo: true,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'Hastane',
          Icons.local_hospital_rounded,
          const Color(0xFF2563EB),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'ATM',
          Icons.local_atm_rounded,
          const Color(0xFFF59E0B),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'Otel',
          Icons.hotel_rounded,
          const Color(0xFFEC4899),
        ),
      ),
    ],
  );

  Widget _kategori(
    String isim,
    IconData icon,
    Color renk, {
    bool eLogo = false,
    bool acilBlink = false,
    bool pasif = false,
    VoidCallback? ozelTiklama,
  }) {
    final bool secili = !pasif && _seciliKategori == isim;

    // Nöbetçi Eczane E logosunun iç zemini aktif temaya uyum sağlar.
    // Kırmızı E, kırmızı çerçeve ve yanıp sönme efekti değişmez.
    final Color eLogoIci = _koyuTema
        ? Colors.black
        : _gumusTema
            ? const Color(0xFFC8CBD0)
            : Colors.white;

    return GestureDetector(
      onTap: pasif
          ? null
          : ozelTiklama ?? () {
              _aramaBekleme?.cancel();
              _aramaController.clear();

              final bool kapatiliyor = _seciliKategori == isim;

              setState(() {
                _aramaMetni = '';

                _seciliKategori = kapatiliyor ? null : isim;

                _gorunenAdet = 50;
              });

              if (!kapatiliyor) {
                _kategoriYerelVerisiniGetir(isim);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 106,
        decoration: BoxDecoration(
          color: secili ? renk.withValues(alpha: 0.14) : _kartRengi,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: secili
                ? renk.withValues(alpha: 0.65)
                : renk.withValues(alpha: pasif ? 0.16 : 0.22),
            width: secili ? 1.5 : 1,
          ),
          boxShadow: secili
              ? [
                  BoxShadow(
                    color: renk.withValues(alpha: 0.16),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: secili ? 0.20 : 0.12),
                shape: BoxShape.circle,
              ),
              child: eLogo
                  ? ValueListenableBuilder<bool>(
                      valueListenable: _yanipSonme,
                      builder: (context, parlak, child) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        decoration: BoxDecoration(
                          color: eLogoIci,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE3262E)
                                .withValues(alpha: parlak ? 1.0 : 0.30),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE3262E)
                                  .withValues(alpha: parlak ? 0.75 : 0.06),
                              blurRadius: parlak ? 16 : 2,
                              spreadRadius: parlak ? 1 : 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'E',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFE3262E)
                                  .withValues(alpha: parlak ? 1.0 : 0.25),
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFE3262E)
                                      .withValues(alpha: parlak ? 1.0 : 0.08),
                                  blurRadius: parlak ? 14 : 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : acilBlink
                      ? ValueListenableBuilder<bool>(
                          valueListenable: _yanipSonme,
                          builder: (context, parlak, child) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE3262E).withValues(
                                    alpha: parlak ? 0.70 : 0.04,
                                  ),
                                  blurRadius: parlak ? 15 : 2,
                                  spreadRadius: parlak ? 1 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              color: const Color(0xFFE3262E).withValues(
                                alpha: parlak ? 1.0 : 0.28,
                              ),
                              size: 25,
                            ),
                          ),
                        )
                      : Icon(
                          icon,
                          color: pasif ? renk.withValues(alpha: 0.65) : renk,
                          size: 24,
                        ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                isim,
                textAlign: TextAlign.center,
                maxLines: isim == 'Elektrikli Şarj İstasyonu' ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isim == 'Elektrikli Şarj İstasyonu' ? 9.5 : 10.5,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  color: pasif ? _anaYazi.withValues(alpha: 0.65) : _anaYazi,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiAlani() => Row(
    children: [
      Expanded(
        child: _kategori(
          'Döviz Kurları',
          Icons.currency_exchange_rounded,
          const Color(0xFF22C55E),
          ozelTiklama: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DovizKurlariEkrani(),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'Hava Durumu',
          Icons.wb_cloudy_rounded,
          const Color(0xFF06B6D4),
          ozelTiklama: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HavaDurumuEkrani(
                  baslangicIl: _seciliIl,
                  baslangicIlce: _seciliIlce,
                  baslangicEnlem: _mevcutKonum?.latitude,
                  baslangicBoylam: _mevcutKonum?.longitude,
                  gpsKonumu: _gpsModu,
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'AVM & Outlet',
          Icons.local_mall_rounded,
          const Color(0xFFA855F7),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _kategori(
          'Havaalanı',
          Icons.local_airport_rounded,
          const Color(0xFFFF7A00),
        ),
      ),
    ],
  );

  void _yolAsistaniYakinda() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YolAsistaniEkrani(
          baslangicEnlem: _mevcutKonum?.latitude,
          baslangicBoylam: _mevcutKonum?.longitude,
        ),
      ),
    );
  }

  Widget _yolOzellikRozeti(
    IconData icon,
    Color renk,
    String yazi,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: renk.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: renk),
          const SizedBox(width: 6),
          Text(
            yazi,
            style: TextStyle(
              color: _anaYazi,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _yolAsistaniKarti() {
    final Color vurgu = const Color(0xFFE3262E);
    final bool koyu = _koyuTema;
    final bool gumus = _gumusTema;

    final List<Color> arkaPlanRenkleri = koyu
        ? [const Color(0xFF101317), const Color(0xFF171C22)]
        : gumus
            ? [const Color(0xFFF0F2F4), const Color(0xFFDDE1E5)]
            : [Colors.white, const Color(0xFFF6F8FA)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _yolAsistaniYakinda,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: arkaPlanRenkleri,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: vurgu.withValues(alpha: koyu ? 0.34 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: koyu ? 0.22 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: vurgu.withValues(alpha: 0.07),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: vurgu.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: vurgu.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.route_rounded,
                                color: Color(0xFFE3262E),
                                size: 15,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'YOL ASİSTANI',
                                style: TextStyle(
                                  color: Color(0xFFE3262E),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rotanı seç, önceden bil.',
                          style: TextStyle(
                            color: _anaYazi,
                            fontSize: 20,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Güzergâh üzerinde dinlenme tesisi, şarj, benzinlik ve yol durumunu tek ekranda gör.',
                          style: TextStyle(
                            color: _ikincilYazi,
                            fontSize: 12.2,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: vurgu.withValues(alpha: koyu ? 0.07 : 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: vurgu.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(96, 96),
                          painter: const _YolAsistaniMiniRotaPainter(),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: vurgu,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: vurgu.withValues(alpha: 0.28),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.north_east_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _yolOzellikRozeti(
                    Icons.local_gas_station_rounded,
                    const Color(0xFFF59E0B),
                    'Akaryakıt',
                  ),
                  _yolOzellikRozeti(
                    Icons.ev_station_rounded,
                    const Color(0xFF10B981),
                    'Şarj',
                  ),
                  _yolOzellikRozeti(
                    Icons.hotel_rounded,
                    const Color(0xFF06B6D4),
                    'Dinlenme',
                  ),
                  _yolOzellikRozeti(
                    Icons.construction_rounded,
                    const Color(0xFFE3262E),
                    'Yol Durumu',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Yeni nesil güzergâh yardımı yakında burada olacak.',
                      style: TextStyle(
                        color: _ikincilYazi,
                        fontSize: 11.7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: vurgu,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: vurgu.withValues(alpha: 0.24),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'YOLA ÇIK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.4,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.25,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yakinBaslik() {
    return Text(
      _aramaMetni.trim().isNotEmpty
          ? 'Türkiye Geneli Sonuçlar'
          : _seciliKategori ?? 'Yakınınızdaki Hizmetler',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
    );
  }

  Widget _nobetciKart({
    required IconData icon,
    required Color renk,
    required String baslik,
    required String adres,
    required String durum,
    required String mesafe,
    required Hizmet hizmet,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => HizmetDetay(hizmet: hizmet)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _kartRengi,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _anaYazi.withValues(alpha: 0.055)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: renk, size: 27),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    adres,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _anaYazi.withValues(alpha: 0.43),
                      fontSize: 11,
                    ),
                  ),
                  if (hizmet.kategori == 'Taksi') ...[
                    const SizedBox(height: 6),
                    Text(
                      aranacakTelefon(hizmet.telefon) != null
                          ? 'Telefon: ${hizmet.telefon}'
                          : 'Telefon bilgisi eksik',
                      style: TextStyle(
                        color: _anaYazi,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: renk,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          durum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: renk,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                Text(
                  mesafe,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _anaYazi.withValues(alpha: 0.38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _altMenu() {
    final Color menuZemini =
        _koyuTema ? const Color(0xFF11151B) : const Color(0xFFF1F3F7);

    final Color ayiriciRengi = _koyuTema
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.13);

    return Container(
      decoration: BoxDecoration(
        color: menuZemini,
        border: Border(
          top: BorderSide(
            color: _koyuTema
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _koyuTema ? 0.32 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _menuItem(
                  Icons.home_rounded,
                  'Ana Sayfa',
                  0,
                ),
              ),
              _altMenuAyirici(ayiriciRengi),
              Expanded(
                child: _menuItem(
                  Icons.location_on_rounded,
                  'Yakınımdaki',
                  1,
                ),
              ),
              _altMenuAyirici(ayiriciRengi),
              Expanded(
                child: _menuItem(
                  Icons.dashboard_customize_rounded,
                  'HERŞEY\nBURADA!',
                  2,
                  merkez: true,
                  ozelIkon: const HerseyBuradaIkon(
                    size: 62,
                  ),
                ),
              ),
              _altMenuAyirici(ayiriciRengi),
              Expanded(
                child: _menuItem(
                  Icons.auto_awesome_rounded,
                  'DADI',
                  3,
                  ozelIkon: const DadiAvatar(
                    size: 44,
                    golge: true,
                  ),
                ),
              ),
              _altMenuAyirici(ayiriciRengi),
              Expanded(
                child: _menuItem(
                  Icons.person_rounded,
                  'Profil',
                  4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _altMenuAyirici(Color renk) {
    return Center(
      child: Container(
        width: 1.2,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: renk,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String isim,
    int index, {
    bool merkez = false,
    Widget? ozelIkon,
  }) {
    final bool aktif = _seciliMenu == index;
    const Color markaKirmizi = Color(0xFFE3262E);

    final Color pasifIkon = _koyuTema
        ? Colors.white.withValues(alpha: 0.52)
        : Colors.black.withValues(alpha: 0.50);

    final Color pasifYazi = _koyuTema
        ? Colors.white.withValues(alpha: 0.56)
        : Colors.black.withValues(alpha: 0.56);

    void tikla() {
      if (index == 1) {
        _yakinHizmetlerHaritasiniAc();
        return;
      }

      if (index == 2) {
        _herseyBuradaAc();
        return;
      }

      if (index == 3) {
        _dadiAc();
        return;
      }

      if (index == 4) {
        _profilAc();
        return;
      }

      setState(() {
        _seciliMenu = 0;
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tikla,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.fromLTRB(
          merkez ? 1 : 3,
          5,
          merkez ? 1 : 3,
          5,
        ),
        decoration: BoxDecoration(
          color: aktif && !merkez
              ? markaKirmizi.withValues(alpha: 0.055)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: merkez ? -14 : 8,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: merkez ? 62 : 44,
                  height: merkez ? 62 : 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ozelIkon != null
                        ? Colors.transparent
                        : merkez
                        ? (_koyuTema
                              ? const Color(0xFF090B0F)
                              : Colors.white)
                        : aktif
                        ? markaKirmizi.withValues(alpha: 0.14)
                        : (_koyuTema
                              ? Colors.white.withValues(alpha: 0.055)
                              : Colors.black.withValues(alpha: 0.055)),
                    border: Border.all(
                      color: ozelIkon != null
                          ? Colors.transparent
                          : merkez
                          ? markaKirmizi.withValues(
                              alpha: aktif ? 1.0 : 0.84,
                            )
                          : aktif
                          ? markaKirmizi.withValues(alpha: 0.62)
                          : (_koyuTema
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08)),
                      width: ozelIkon != null ? 0 : (merkez ? 2.4 : 1),
                    ),
                    boxShadow: [
                      if (merkez)
                        BoxShadow(
                          color: markaKirmizi.withValues(
                            alpha: aktif ? 0.34 : 0.22,
                          ),
                          blurRadius: aktif ? 18 : 13,
                          spreadRadius: aktif ? 1.0 : 0,
                        ),
                      if (aktif && !merkez)
                        BoxShadow(
                          color: markaKirmizi.withValues(alpha: 0.13),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: ozelIkon ??
                      Icon(
                        icon,
                        color: merkez
                            ? markaKirmizi
                            : aktif
                            ? markaKirmizi
                            : pasifIkon,
                        size: merkez ? 30 : 22,
                      ),
                ),
              ),
            ),
            Positioned(
              left: 2,
              right: 2,
              bottom: merkez ? 6 : 8,
              child: Text(
                isim,
                textAlign: TextAlign.center,
                maxLines: isim.contains('\n') ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: merkez
                      ? (aktif
                            ? markaKirmizi
                            : _anaYazi.withValues(alpha: 0.80))
                      : aktif
                      ? markaKirmizi
                      : pasifYazi,
                  fontSize: merkez
                      ? 8.7
                      : isim == 'Yakınımdaki'
                      ? 8.9
                      : 9.6,
                  height: merkez ? 0.98 : 1,
                  fontWeight: merkez
                      ? FontWeight.w900
                      : aktif
                      ? FontWeight.w900
                      : FontWeight.w700,
                  letterSpacing: merkez ? 0.15 : 0,
                ),
              ),
            ),
            if (aktif)
              Positioned(
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: merkez ? 26 : 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: markaKirmizi,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: markaKirmizi.withValues(alpha: 0.36),
                        blurRadius: 6,
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

}


class _YolAsistaniMiniRotaPainter extends CustomPainter {
  const _YolAsistaniMiniRotaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const Color vurgu = Color(0xFFE3262E);

    final Paint zemin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = vurgu.withValues(alpha: 0.14);

    final Paint parlak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = vurgu.withValues(alpha: 0.92);

    final Path yol = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.54,
        size.width * 0.42,
        size.height * 0.60,
        size.width * 0.48,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.26,
        size.width * 0.72,
        size.height * 0.26,
        size.width * 0.80,
        size.height * 0.16,
      );

    canvas.drawPath(yol, zemin);
    canvas.drawPath(yol, parlak);

    final Paint nokta = Paint()..color = vurgu;
    final Paint acikNokta = Paint()..color = const Color(0xFFF59E0B);
    final Paint yesilNokta = Paint()..color = const Color(0xFF10B981);

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.78), 5.5, nokta);
    canvas.drawCircle(Offset(size.width * 0.49, size.height * 0.43), 4.3, acikNokta);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.16), 6.3, yesilNokta);

    final Paint ince = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.58);

    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.78), 8.2, ince);
    canvas.drawCircle(Offset(size.width * 0.80, size.height * 0.16), 9.0, ince);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

