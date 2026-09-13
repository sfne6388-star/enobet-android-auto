import 'package:flutter/material.dart';

import '../models/hizmet.dart';
import 'hizmet_detay.dart';

class Arama extends StatefulWidget {
  final List<Hizmet> hizmetler;

  const Arama({
    super.key,
    required this.hizmetler,
  });

  @override
  State<Arama> createState() => _AramaState();
}

class _AramaState extends State<Arama> {
  final TextEditingController _aramaController =
      TextEditingController();

  String _aramaMetni = '';

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  String _aramaIcinDuzenle(String metin) {
    return metin
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll('Ğ', 'g')
        .replaceAll('Ü', 'u')
        .replaceAll('Ş', 's')
        .replaceAll('Ö', 'o')
        .replaceAll('Ç', 'c')
        .trim();
  }

  List<String> _aramaKelimeAlternatifleri(String arama) {
    final List<String> alternatifler = [arama];

    switch (arama) {
      case 'eczane':
      case 'eczaneler':
        alternatifler.addAll([
          'eczane',
          'eczaneler',
          'nobetci eczane',
        ]);
        break;

      case 'veteriner':
      case 'veterinerler':
        alternatifler.addAll([
          'veteriner',
          'veterinerler',
        ]);
        break;

      case 'cekici':
      case 'cekiciler':
      case 'oto cekici':
      case 'yol yardim':
        alternatifler.addAll([
          'cekici',
          'cekiciler',
          'yol yardim',
          'towing',
        ]);
        break;

      case 'sarj':
      case 'elektrikli':
      case 'elektrikli sarj':
      case 'sarj istasyonu':
      case 'sarj istasyonlari':
        alternatifler.addAll([
          'sarj',
          'elektrikli',
          'elektrikli sarj istasyonu',
          'sarj istasyonu',
          'sarj istasyonlari',
        ]);
        break;

      case 'lastik':
      case 'oto lastik':
      case 'lastikci':
      case 'lastikciler':
        alternatifler.addAll([
          'lastik',
          'oto lastik',
          'lastikci',
          'lastikciler',
          'tyres',
        ]);
        break;

      case 'cilingir':
      case 'cilingirci':
      case 'anahtarci':
      case 'anahtar':
        alternatifler.addAll([
          'cilingir',
          'cilingirci',
          'anahtarci',
          'anahtar',
          'locksmith',
        ]);
        break;
    }

    return alternatifler;
  }

  List<Hizmet> get _sonuclar {
    final String arama =
        _aramaIcinDuzenle(_aramaMetni);

    if (arama.isEmpty) {
      return [];
    }

    final List<String> aranacaklar =
        _aramaKelimeAlternatifleri(arama);

    final List<Hizmet> sonuc =
        widget.hizmetler.where((hizmet) {
      final String isim =
          _aramaIcinDuzenle(hizmet.isim);

      final String kategori =
          _aramaIcinDuzenle(hizmet.kategori);

      final String adres =
          _aramaIcinDuzenle(hizmet.adres);

      final String telefon =
          _aramaIcinDuzenle(hizmet.telefon);

      final String durum =
          _aramaIcinDuzenle(hizmet.durum);

      final String calismaSaatleri =
          _aramaIcinDuzenle(
        hizmet.calismaSaatleri,
      );

      final String il =
          _aramaIcinDuzenle(hizmet.il);

      final String ilce =
          _aramaIcinDuzenle(hizmet.ilce);

      final String tumBilgiler = [
        isim,
        kategori,
        adres,
        telefon,
        durum,
        calismaSaatleri,
        il,
        ilce,
      ].join(' ');

      return aranacaklar.any(
        (kelime) => tumBilgiler.contains(kelime),
      );
    }).toList();

    sonuc.sort((a, b) {
      final double aMesafe =
          _mesafeSayiyaCevir(a.mesafe);

      final double bMesafe =
          _mesafeSayiyaCevir(b.mesafe);

      return aMesafe.compareTo(bMesafe);
    });

    return sonuc;
  }

  double _mesafeSayiyaCevir(String mesafe) {
    final String temiz = mesafe
        .replaceAll('km', '')
        .replaceAll('KM', '')
        .replaceAll('m', '')
        .replaceAll('M', '')
        .replaceAll(',', '.')
        .trim();

    final double? sayi =
        double.tryParse(temiz);

    if (sayi == null) {
      return double.infinity;
    }

    if (mesafe.toLowerCase().contains('km')) {
      return sayi * 1000;
    }

    return sayi;
  }

  void _aramaTemizle() {
    _aramaController.clear();

    setState(() {
      _aramaMetni = '';
    });
  }

  void _hizmetAc(Hizmet hizmet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HizmetDetay(hizmet: hizmet),
      ),
    );
  }

  void _hizliAramaYap(String metin) {
    _aramaController.text = metin;

    _aramaController.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset: _aramaController.text.length,
      ),
    );

    setState(() {
      _aramaMetni = metin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Hizmet> sonuclar = _sonuclar;

    final bool aramaYapiliyor =
        _aramaMetni.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070707),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Arama',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              12,
            ),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.30,
                    ),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: _aramaController,
                autofocus: true,
                onChanged: (deger) {
                  setState(() {
                    _aramaMetni = deger;
                  });
                },
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF555555),
                    size: 25,
                  ),
                  suffixIcon:
                      _aramaMetni.isNotEmpty
                          ? IconButton(
                              onPressed:
                                  _aramaTemizle,
                              icon: const Icon(
                                Icons.close_rounded,
                                color:
                                    Color(0xFF666666),
                              ),
                            )
                          : null,
                  hintText:
                      'Hizmet, kategori veya adres ara...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(
                    vertical: 17,
                  ),
                ),
              ),
            ),
          ),
          if (aramaYapiliyor)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                10,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${sonuclar.length} sonuç bulundu',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.45,
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Expanded(
            child: !aramaYapiliyor
                ? _aramaBaslangicAlani()
                : sonuclar.isEmpty
                    ? _sonucYokAlani()
                    : ListView.builder(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
                          20,
                          5,
                          20,
                          25,
                        ),
                        itemCount: sonuclar.length,
                        itemBuilder:
                            (context, index) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: _sonucKarti(
                              sonuclar[index],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _aramaBaslangicAlani() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          10,
          24,
          30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFE3262E)
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Color(0xFFE3262E),
                size: 44,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Ne arıyorsunuz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Hizmet adı, kategori veya adres '
              'yazarak arama yapabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.45,
                ),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HIZLI ARAMA',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.35,
                  ),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _aramaOrnek(
                  'Eczane',
                  Icons.local_pharmacy_rounded,
                  const Color(0xFFE3262E),
                ),
                _aramaOrnek(
                  'Veteriner',
                  Icons.pets_rounded,
                  const Color(0xFF20C978),
                ),
                _aramaOrnek(
                  'Çekici',
                  Icons.car_repair_rounded,
                  const Color(0xFFFFB020),
                ),
                _aramaOrnek(
                  'Şarj',
                  Icons.ev_station_rounded,
                  const Color(0xFF20D9C2),
                  aramaDegeri:
                      'Elektrikli Şarj İstasyonu',
                ),
                _aramaOrnek(
                  'Oto Lastik',
                  Icons.tire_repair_rounded,
                  const Color(0xFFFFB020),
                ),
                _aramaOrnek(
                  'Çilingir',
                  Icons.key_rounded,
                  const Color(0xFFA970FF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aramaOrnek(
    String gorunenMetin,
    IconData ikon,
    Color renk, {
    String? aramaDegeri,
  }) {
    return GestureDetector(
      onTap: () {
        _hizliAramaYap(
          aramaDegeri ?? gorunenMetin,
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: renk.withValues(
            alpha: 0.09,
          ),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: renk.withValues(
              alpha: 0.18,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ikon,
              color: renk,
              size: 15,
            ),
            const SizedBox(width: 7),
            Text(
              gorunenMetin,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.72,
                ),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sonucYokAlani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.white.withValues(
                alpha: 0.30,
              ),
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sonuç bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Farklı bir hizmet adı, kategori '
              'veya adres deneyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: 0.40,
                ),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _aramaTemizle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3262E)
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE3262E)
                        .withValues(alpha: 0.20),
                  ),
                ),
                child: const Text(
                  'Aramayı Temizle',
                  style: TextStyle(
                    color: Color(0xFFE3262E),
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

  Widget _sonucKarti(Hizmet hizmet) {
    return GestureDetector(
      onTap: () {
        _hizmetAc(hizmet);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius:
              BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.055,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: hizmet.renk.withValues(
                  alpha: 0.11,
                ),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Icon(
                hizmet.ikon,
                color: hizmet.renk,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    hizmet.isim,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hizmet.kategori,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hizmet.renk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hizmet.adres,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.43,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  hizmet.mesafe,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(
                    alpha: 0.35,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}