import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class BarkodSorgulamaEkrani extends StatefulWidget {
  final bool otomatikTara;

  const BarkodSorgulamaEkrani({
    super.key,
    this.otomatikTara = false,
  });

  @override
  State<BarkodSorgulamaEkrani> createState() => _BarkodSorgulamaEkraniState();
}

class _BarkodSorgulamaEkraniState extends State<BarkodSorgulamaEkrani> {
  static const Color _accent = Color(0xFFFFA000);
  static const Color _arkaPlan = Color(0xFF070707);
  static const Color _kart = Color(0xFF121212);

  final TextEditingController _barkodController = TextEditingController();

  late bool _tarayiciAcik;
  bool _sorgulaniyor = false;
  bool _taramaKilidi = false;
  String? _hata;
  Map<String, dynamic>? _urun;
  _QrSonucu? _qrSonucu;

  @override
  void initState() {
    super.initState();
    _tarayiciAcik = widget.otomatikTara;
  }

  @override
  void dispose() {
    _barkodController.dispose();
    super.dispose();
  }

  String _temizBarkod(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '').trim();

  bool _barkodUzunluguGecerli(String barkod) =>
      barkod.length == 8 ||
      barkod.length == 12 ||
      barkod.length == 13 ||
      barkod.length == 14;

  Future<void> _sorgula([String? gelenBarkod]) async {
    final String barkod = _temizBarkod(gelenBarkod ?? _barkodController.text);

    FocusScope.of(context).unfocus();

    if (!_barkodUzunluguGecerli(barkod)) {
      setState(() {
        _urun = null;
        _qrSonucu = null;
        _hata = 'Geçerli bir EAN / UPC / GTIN barkod numarası girin.';
      });
      return;
    }

    _barkodController.text = barkod;

    setState(() {
      _sorgulaniyor = true;
      _hata = null;
      _urun = null;
      _qrSonucu = null;
      _tarayiciAcik = false;
    });

    try {
      final Uri uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v2/product/$barkod.json',
        {
          'fields':
              'code,product_name,product_name_tr,brands,categories,quantity,image_front_url,image_url,nutriscore_grade,nova_group,ingredients_text,ingredients_text_tr,countries',
        },
      );

      final http.Response response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'ENobet/1.0 (Barkod ve QR Sorgulama)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Geçersiz yanıt');
      }

      final int status = (decoded['status'] as num?)?.toInt() ?? 0;
      final dynamic product = decoded['product'];

      if (status != 1 || product is! Map) {
        if (!mounted) return;
        setState(() {
          _hata =
              'Bu barkoda ait ürün Open Food Facts veritabanında bulunamadı.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _urun = Map<String, dynamic>.from(product);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hata =
            'Ürün bilgisi alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sorgulaniyor = false;
          _taramaKilidi = false;
        });
      }
    }
  }

  void _kodAlgilandi(BarcodeCapture capture) {
    if (_taramaKilidi || capture.barcodes.isEmpty) return;

    Barcode? algilanan;
    for (final Barcode barkod in capture.barcodes) {
      final String? raw = barkod.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        algilanan = barkod;
        break;
      }
    }

    if (algilanan == null) return;

    final String raw = algilanan.rawValue!.trim();
    _taramaKilidi = true;

    if (algilanan.format == BarcodeFormat.qrCode) {
      final _QrSonucu sonuc = _qrCoz(raw);

      setState(() {
        _tarayiciAcik = false;
        _sorgulaniyor = false;
        _hata = null;
        _urun = null;
        _qrSonucu = sonuc;
      });
      return;
    }

    final String barkod = _temizBarkod(raw);
    if (_barkodUzunluguGecerli(barkod)) {
      _sorgula(barkod);
      return;
    }

    setState(() {
      _tarayiciAcik = false;
      _urun = null;
      _qrSonucu = null;
      _hata =
          'Kod okundu ancak geçerli bir ürün barkodu olarak tanınmadı. EAN / UPC / GTIN barkodu veya QR kod okutun.';
    });
  }

  void _kamerayiDegistir() {
    if (_sorgulaniyor) return;

    setState(() {
      _tarayiciAcik = !_tarayiciAcik;
      _taramaKilidi = false;
      if (_tarayiciAcik) {
        _hata = null;
        _urun = null;
        _qrSonucu = null;
      }
    });
  }

  _QrSonucu _qrCoz(String raw) {
    final String metin = raw.trim();
    final String lower = metin.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _QrSonucu(
        tur: 'Web bağlantısı',
        baslik: 'İnternet bağlantısı',
        icerik: metin,
        ikon: Icons.language_rounded,
        eylem: Uri.tryParse(metin),
        eylemMetni: 'Siteyi Aç',
      );
    }

    if (lower.startsWith('www.')) {
      final Uri uri = Uri.parse('https://$metin');
      return _QrSonucu(
        tur: 'Web bağlantısı',
        baslik: 'İnternet bağlantısı',
        icerik: metin,
        ikon: Icons.language_rounded,
        eylem: uri,
        eylemMetni: 'Siteyi Aç',
      );
    }

    if (lower.startsWith('tel:')) {
      final String numara = metin.substring(4).trim();
      return _QrSonucu(
        tur: 'Telefon',
        baslik: 'Telefon numarası',
        icerik: numara.isEmpty ? metin : numara,
        ikon: Icons.phone_rounded,
        eylem: Uri.tryParse(metin),
        eylemMetni: 'Ara',
      );
    }

    if (lower.startsWith('mailto:')) {
      final Uri? uri = Uri.tryParse(metin);
      final String adres = uri?.path.trim() ?? '';
      return _QrSonucu(
        tur: 'E-posta',
        baslik: 'E-posta adresi',
        icerik: adres.isEmpty ? metin : adres,
        ikon: Icons.email_rounded,
        eylem: uri,
        eylemMetni: 'E-posta Gönder',
      );
    }

    if (lower.startsWith('matmsg:')) {
      final String to = _etiketDegeri(metin, 'TO');
      final String subject = _etiketDegeri(metin, 'SUB');
      final String body = _etiketDegeri(metin, 'BODY');
      final Map<String, String> detaylar = <String, String>{};
      if (subject.isNotEmpty) detaylar['Konu'] = subject;
      if (body.isNotEmpty) detaylar['Mesaj'] = body;

      final Uri? uri = to.isEmpty
          ? null
          : Uri(
              scheme: 'mailto',
              path: to,
              queryParameters: <String, String>{
                if (subject.isNotEmpty) 'subject': subject,
                if (body.isNotEmpty) 'body': body,
              },
            );

      return _QrSonucu(
        tur: 'E-posta',
        baslik: 'E-posta',
        icerik: to.isEmpty ? metin : to,
        ikon: Icons.email_rounded,
        detaylar: detaylar,
        eylem: uri,
        eylemMetni: uri == null ? null : 'E-posta Gönder',
      );
    }

    if (lower.startsWith('sms:') || lower.startsWith('smsto:')) {
      String numara = '';
      String mesaj = '';

      if (lower.startsWith('smsto:')) {
        final String govde = metin.substring(6);
        final int ayrac = govde.indexOf(':');
        if (ayrac >= 0) {
          numara = govde.substring(0, ayrac).trim();
          mesaj = govde.substring(ayrac + 1).trim();
        } else {
          numara = govde.trim();
        }
      } else {
        final Uri? smsUri = Uri.tryParse(metin);
        numara = smsUri?.path.trim() ?? '';
        mesaj = smsUri?.queryParameters['body']?.trim() ?? '';
      }

      final Uri? uri = numara.isEmpty
          ? Uri.tryParse(metin)
          : Uri(
              scheme: 'sms',
              path: numara,
              queryParameters: mesaj.isEmpty ? null : {'body': mesaj},
            );

      return _QrSonucu(
        tur: 'SMS',
        baslik: 'SMS bilgisi',
        icerik: numara.isEmpty ? metin : numara,
        ikon: Icons.sms_rounded,
        detaylar: <String, String>{
          if (mesaj.isNotEmpty) 'Mesaj': mesaj,
        },
        eylem: uri,
        eylemMetni: 'SMS Gönder',
      );
    }

    if (lower.startsWith('geo:')) {
      final String govde = metin.substring(4);
      final String koordinat = govde.split('?').first.trim();
      final Uri haritaUri = Uri.https(
        'www.google.com',
        '/maps/search/',
        <String, String>{
          'api': '1',
          'query': koordinat,
        },
      );

      return _QrSonucu(
        tur: 'Konum',
        baslik: 'Harita konumu',
        icerik: koordinat.isEmpty ? metin : koordinat,
        ikon: Icons.location_on_rounded,
        eylem: haritaUri,
        eylemMetni: 'Haritada Aç',
      );
    }

    if (lower.startsWith('wifi:')) {
      final Map<String, String> wifi = _wifiAlanlari(metin);
      final String agAdi = wifi['S']?.trim() ?? '';
      final String guvenlik = wifi['T']?.trim() ?? '';
      final String sifre = wifi['P'] ?? '';
      final String gizli = wifi['H']?.toLowerCase() == 'true' ? 'Evet' : 'Hayır';

      return _QrSonucu(
        tur: 'Wi-Fi',
        baslik: 'Wi-Fi ağı',
        icerik: agAdi.isEmpty ? 'Ağ adı belirtilmemiş' : agAdi,
        ikon: Icons.wifi_rounded,
        detaylar: <String, String>{
          if (guvenlik.isNotEmpty) 'Güvenlik': guvenlik,
          if (sifre.isNotEmpty) 'Şifre': sifre,
          'Gizli ağ': gizli,
        },
      );
    }

    if (lower.startsWith('begin:vcard')) {
      final Map<String, String> detaylar = <String, String>{};
      String ad = '';

      for (final String satir in metin.split(RegExp(r'\r?\n'))) {
        final String trim = satir.trim();
        final String ust = trim.toUpperCase();
        if (ust.startsWith('FN:')) {
          ad = trim.substring(3).trim();
        } else if (ust.startsWith('TEL') && trim.contains(':')) {
          final String tel = trim.substring(trim.indexOf(':') + 1).trim();
          if (tel.isNotEmpty) detaylar['Telefon'] = tel;
        } else if (ust.startsWith('EMAIL') && trim.contains(':')) {
          final String mail = trim.substring(trim.indexOf(':') + 1).trim();
          if (mail.isNotEmpty) detaylar['E-posta'] = mail;
        } else if (ust.startsWith('ORG:')) {
          final String kurum = trim.substring(4).trim();
          if (kurum.isNotEmpty) detaylar['Kurum'] = kurum;
        }
      }

      return _QrSonucu(
        tur: 'Kişi',
        baslik: 'Kişi bilgisi',
        icerik: ad.isEmpty ? 'Kartvizit bilgisi' : ad,
        ikon: Icons.contact_page_rounded,
        detaylar: detaylar,
      );
    }

    return _QrSonucu(
      tur: 'Metin',
      baslik: 'QR kod içeriği',
      icerik: metin,
      ikon: Icons.text_snippet_rounded,
    );
  }

  String _etiketDegeri(String metin, String etiket) {
    final RegExp regex = RegExp(
      '(?:^|;)$etiket:([^;]*)',
      caseSensitive: false,
    );
    return regex.firstMatch(metin)?.group(1)?.trim() ?? '';
  }

  Map<String, String> _wifiAlanlari(String metin) {
    String govde = metin.substring(5);
    if (govde.endsWith(';;')) {
      govde = govde.substring(0, govde.length - 2);
    }

    final List<String> parcalar = <String>[];
    final StringBuffer aktif = StringBuffer();
    bool kacis = false;

    for (int i = 0; i < govde.length; i++) {
      final String karakter = govde[i];
      if (kacis) {
        aktif.write(karakter);
        kacis = false;
      } else if (karakter == r'\') {
        kacis = true;
      } else if (karakter == ';') {
        parcalar.add(aktif.toString());
        aktif.clear();
      } else {
        aktif.write(karakter);
      }
    }
    parcalar.add(aktif.toString());

    final Map<String, String> sonuc = <String, String>{};
    for (final String parca in parcalar) {
      final int ayrac = parca.indexOf(':');
      if (ayrac <= 0) continue;
      final String anahtar = parca.substring(0, ayrac).trim().toUpperCase();
      final String deger = parca.substring(ayrac + 1);
      if (anahtar.isNotEmpty) sonuc[anahtar] = deger;
    }
    return sonuc;
  }

  String _metin(dynamic value, {String fallback = 'Bilgi yok'}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _urunAdi(Map<String, dynamic> urun) {
    final String tr = _metin(urun['product_name_tr'], fallback: '');
    if (tr.isNotEmpty) return tr;
    return _metin(urun['product_name'], fallback: 'Ürün adı belirtilmemiş');
  }

  String _nutriScore(dynamic value) {
    final String score = _metin(value, fallback: '').toUpperCase();
    return score.isEmpty ? '—' : score;
  }

  Future<void> _qrKopyala(_QrSonucu sonuc) async {
    await Clipboard.setData(ClipboardData(text: sonuc.hamMetin ?? sonuc.icerik));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR içeriği kopyalandı.')),
    );
  }

  Future<void> _qrEyleminiAc(_QrSonucu sonuc) async {
    final Uri? uri = sonuc.eylem;
    if (uri == null) return;

    final bool acildi = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!acildi && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu işlem cihazda açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaPlan,
      appBar: AppBar(
        backgroundColor: _arkaPlan,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Barkod ve QR Sorgulama',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const Text(
              'Kamera barkod ve QR kodu otomatik ayırt eder. Barkod okunursa ürün bilgisi, QR okunursa kodun içeriği gösterilir.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            if (_tarayiciAcik) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 300,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(onDetect: _kodAlgilandi),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 250,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: _accent, width: 2.5),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.16),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white.withValues(alpha: 0.22),
                                size: 54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 13,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Barkod veya QR kodu çerçeveye getirin',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _sorgulaniyor ? null : _kamerayiDegistir,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _tarayiciAcik
                      ? Icons.close_rounded
                      : Icons.qr_code_scanner_rounded,
                ),
                label: Text(
                  _tarayiciAcik ? 'Kamerayı Kapat' : 'Barkod / QR Tara',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider(color: Colors.white12)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'veya barkod numarası girin',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white12)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _barkodController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _sorgula(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Barkod numarası',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(
                  Icons.numbers_rounded,
                  color: Colors.white54,
                ),
                filled: true,
                fillColor: _kart,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _sorgulaniyor ? null : () => _sorgula(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Barkodu Sorgula',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (_sorgulaniyor) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: _accent)),
            ],
            if (_hata != null && !_sorgulaniyor) ...[
              const SizedBox(height: 22),
              _bilgiKarti(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: _accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hata!,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_urun != null && !_sorgulaniyor) ...[
              const SizedBox(height: 22),
              _urunKarti(_urun!),
            ],
            if (_qrSonucu != null && !_sorgulaniyor) ...[
              const SizedBox(height: 22),
              _qrKarti(_qrSonucu!),
            ],
            const SizedBox(height: 22),
            Center(
              child: Text(
                'Barkod ürün verisi: Open Food Facts • QR içerikleri cihazda çözümlenir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _urunKarti(Map<String, dynamic> urun) {
    final String image =
        _metin(urun['image_front_url'] ?? urun['image_url'], fallback: '');
    final String icerik = _metin(
      urun['ingredients_text_tr'] ?? urun['ingredients_text'],
      fallback: '',
    );

    return _bilgiKarti(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sonucEtiketi(
            icon: Icons.barcode_reader,
            yazi: 'BARKOD',
            renk: _accent,
          ),
          const SizedBox(height: 16),
          if (image.isNotEmpty) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  image,
                  height: 190,
                  width: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            _urunAdi(urun),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _satir('Marka', _metin(urun['brands'])),
          _satir('Barkod', _metin(urun['code'])),
          _satir('Kategori', _metin(urun['categories'])),
          _satir('Miktar', _metin(urun['quantity'])),
          _satir('Nutri-Score', _nutriScore(urun['nutriscore_grade'])),
          if (icerik.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 26),
            const Text(
              'İçindekiler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              icerik,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qrKarti(_QrSonucu sonuc) {
    return _bilgiKarti(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sonucEtiketi(
                icon: Icons.qr_code_2_rounded,
                yazi: 'QR KOD',
                renk: const Color(0xFF29B6F6),
              ),
              const Spacer(),
              Text(
                sonuc.tur,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  sonuc.ikon,
                  color: const Color(0xFF29B6F6),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sonuc.baslik,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SelectableText(
                      sonuc.icerik,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sonuc.detaylar.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 28),
            for (final MapEntry<String, String> detay in sonuc.detaylar.entries)
              _satir(detay.key, detay.value),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _qrKopyala(sonuc),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 19),
                  label: const Text(
                    'Kopyala',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (sonuc.eylem != null && sonuc.eylemMetni != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _qrEyleminiAc(sonuc),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF29B6F6),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                    label: Text(
                      sonuc.eylemMetni!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sonucEtiketi({
    required IconData icon,
    required String yazi,
    required Color renk,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: renk, size: 16),
          const SizedBox(width: 6),
          Text(
            yazi,
            style: TextStyle(
              color: renk,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _satir(String baslik, String deger) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                baslik,
                style: const TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                deger,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bilgiKarti({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
}

class _QrSonucu {
  final String tur;
  final String baslik;
  final String icerik;
  final IconData ikon;
  final Map<String, String> detaylar;
  final Uri? eylem;
  final String? eylemMetni;
  final String? hamMetin;

  const _QrSonucu({
    required this.tur,
    required this.baslik,
    required this.icerik,
    required this.ikon,
    this.detaylar = const <String, String>{},
    this.eylem,
    this.eylemMetni,
    this.hamMetin,
  });
}
