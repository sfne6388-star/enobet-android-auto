import 'package:flutter/material.dart';

class EnobetAsistan extends StatefulWidget {
  const EnobetAsistan({super.key});

  @override
  State<EnobetAsistan> createState() => _EnobetAsistanState();
}

class _EnobetAsistanState extends State<EnobetAsistan> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _uyari;
  String? _onerilenHedef;

  static const Color _kirmizi = Color(0xFFE3262E);
  static const Color _arkaPlan = Color(0xFF070707);
  static const Color _kart = Color(0xFF111111);
  static const Color _ikincilKart = Color(0xFF171717);

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _duzenle(String metin) {
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

  void _hedefeGit(String hedef) {
    Navigator.pop(context, hedef);
  }

  void _ara() {
    final String giris = _duzenle(_controller.text);

    if (giris.isEmpty) {
      setState(() {
        _onerilenHedef = null;
        _uyari = 'Neye ihtiyacın olduğunu kısa bir cümleyle yazabilirsin.';
      });
      _focusNode.requestFocus();
      return;
    }

    String? hedef;

    bool varMi(List<String> kelimeler) =>
        kelimeler.any((kelime) => giris.contains(_duzenle(kelime)));

    if (varMi([
      'acil',
      '112',
      'polis',
      'itfaiye',
      'ambulans',
      'jandarma',
      'zehir',
      'sosyal destek',
    ])) {
      hedef = 'Acil';
    } else if (varMi([
      'eczane',
      'ilaç',
      'ilac',
      'nöbetçi eczane',
      'nobetci eczane',
      'reçete',
      'recete',
    ])) {
      hedef = 'Nöbetçi Eczane';
    } else if (varMi([
      'hastane',
      'doktor',
      'sağlık',
      'saglik',
      'acil servis',
      'yaralandım',
      'yaralandim',
    ])) {
      hedef = 'Hastane';
    } else if (varMi([
      'veteriner',
      'kedi',
      'köpek',
      'kopek',
      'hayvan',
      'pet',
    ])) {
      hedef = 'Veteriner';
    } else if (varMi([
      'taksi',
      'taxi',
      'araç lazım',
      'arac lazim',
      'ulaşım',
      'ulasim',
    ])) {
      hedef = 'Taksi';
    } else if (varMi([
      'atm',
      'para çek',
      'para cek',
      'nakit',
      'banka',
    ])) {
      hedef = 'ATM';
    } else if (varMi([
      'otel',
      'konaklama',
      'kalacak yer',
      'pansiyon',
      'gece kal',
    ])) {
      hedef = 'Otel';
    } else if (varMi([
      'şarj',
      'sarj',
      'elektrikli araç',
      'elektrikli arac',
      'ev şarj',
      'ev sarj',
    ])) {
      hedef = 'Elektrikli Şarj İstasyonu';
    } else if (varMi([
      'kargo',
      'paket',
      'gönderi',
      'gonderi',
      'kurye',
    ])) {
      hedef = 'Kargo';
    } else if (varMi([
      'otogar',
      'terminal',
      'otobüs',
      'otobus',
      'şehirlerarası',
      'sehirlerarasi',
    ])) {
      hedef = 'Otogar';
    } else if (varMi([
      'akaryakıt',
      'akaryakit',
      'yakıt fiyat',
      'yakit fiyat',
      'benzin fiyat',
      'motorin fiyat',
      'mazot fiyat',
      'dizel fiyat',
      'lpg fiyat',
      'otogaz fiyat',
    ])) {
      hedef = 'Akaryakıt Fiyatları';
    } else if (varMi([
      'hava',
      'yağmur',
      'yagmur',
      'sıcaklık',
      'sicaklik',
      'derece',
      'hava durumu',
    ])) {
      hedef = 'Hava Durumu';
    } else if (varMi([
      'barkod',
      'ürün',
      'urun',
      'qr',
      'gıda',
      'gida',
      'içindekiler',
      'icindekiler',
    ])) {
      hedef = 'Barkod ve QR Sorgulama';
    }

    setState(() {
      _onerilenHedef = hedef;
      _uyari = hedef == null
          ? 'Bunu henüz otomatik eşleştiremedim. Aşağıdaki hızlı seçeneklerden birini seçebilirsin.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaPlan,
      body: SafeArea(
        child: Column(
          children: [
            _ustBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _hero(),
                  const SizedBox(height: 16),
                  _aramaAlani(),
                  if (_uyari != null) ...[
                    const SizedBox(height: 10),
                    _uyariAlani(),
                  ],
                  if (_onerilenHedef != null) ...[
                    const SizedBox(height: 12),
                    _sonucKarti(_onerilenHedef!),
                  ],
                  const SizedBox(height: 24),
                  _bolumBaslik(
                    'Hızlı Yardım',
                    'Durumunu seç, ENöbet seni doğru hizmete götürsün.',
                  ),
                  const SizedBox(height: 12),
                  _hizliGrid(),
                  const SizedBox(height: 24),
                  _bolumBaslik(
                    'Diğer İhtiyaçlar',
                    'Tek dokunuşla ilgili bölüme geç.',
                  ),
                  const SizedBox(height: 12),
                  _digerHizmetler(),
                  const SizedBox(height: 18),
                  _altBilgi(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ustBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              'ENöbet Asistan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF152019),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF36C275).withValues(alpha: 0.28),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF36C275),
                  size: 15,
                ),
                SizedBox(width: 4),
                Text(
                  'Hazır',
                  style: TextStyle(
                    color: Color(0xFF8CE5B3),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A090B),
            Color(0xFF15090A),
            Color(0xFF101010),
          ],
        ),
        border: Border.all(
          color: _kirmizi.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: _kirmizi.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kirmizi.withValues(alpha: 0.12),
              border: Border.all(
                color: _kirmizi.withValues(alpha: 0.42),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _kirmizi,
              size: 31,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nasıl yardımcı olabilirim?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'İhtiyacını yaz veya aşağıdan seç. Seni en doğru ENöbet hizmetine yönlendireyim.',
                  style: TextStyle(
                    color: Color(0xFFA8A8A8),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aramaAlani() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFF777777),
            size: 21,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: _kirmizi,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _ara(),
              decoration: const InputDecoration(
                hintText: 'Örn: Gece ilaç lazım...',
                hintStyle: TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: _kirmizi,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _ara,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uyariAlani() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF17130B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFB020).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFFFB020),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _uyari!,
              style: const TextStyle(
                color: Color(0xFFD4C49B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sonucKarti(String hedef) {
    final _HizmetGorunumu gorunum = _gorunum(hedef);

    return GestureDetector(
      onTap: () => _hedefeGit(hedef),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: gorunum.renk.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: gorunum.renk.withValues(alpha: 0.38),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gorunum.renk.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                gorunum.ikon,
                color: gorunum.renk,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bunu arıyor olabilirsin',
                    style: TextStyle(
                      color: Color(0xFF8C8C8C),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hedef,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: gorunum.renk,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bolumBaslik(String baslik, String altBaslik) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          altBaslik,
          style: const TextStyle(
            color: Color(0xFF777777),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  Widget _hizliGrid() {
    final List<_AsistanKart> kartlar = [
      const _AsistanKart(
        'İlaç lazım',
        'Nöbetçi Eczane',
        Icons.medication_rounded,
        Color(0xFFE3262E),
      ),
      const _AsistanKart(
        'Sağlık sorunu',
        'Hastane',
        Icons.local_hospital_rounded,
        Color(0xFF3185E8),
      ),
      const _AsistanKart(
        'Hayvanım rahatsız',
        'Veteriner',
        Icons.pets_rounded,
        Color(0xFF21C064),
      ),
      const _AsistanKart(
        'Taksi lazım',
        'Taksi',
        Icons.local_taxi_rounded,
        Color(0xFFFFB020),
      ),
      const _AsistanKart(
        'Nakit lazım',
        'ATM',
        Icons.local_atm_rounded,
        Color(0xFF7A5AF8),
      ),
      const _AsistanKart(
        'Kalacak yer',
        'Otel',
        Icons.hotel_rounded,
        Color(0xFF00A6A6),
      ),
      const _AsistanKart(
        'Aracımı şarj edeceğim',
        'Elektrikli Şarj İstasyonu',
        Icons.ev_station_rounded,
        Color(0xFFFF8A00),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kartlar.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final _AsistanKart kart = kartlar[index];

        return GestureDetector(
          onTap: () => _hedefeGit(kart.hedef),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _kart,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: kart.renk.withValues(alpha: 0.17),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: kart.renk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    kart.ikon,
                    color: kart.renk,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kart.baslik,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _digerHizmetler() {
    final List<_AsistanKart> kartlar = [
      const _AsistanKart(
        'Kargo',
        'Kargo',
        Icons.local_shipping_rounded,
        Color(0xFF8E6CEF),
      ),
      const _AsistanKart(
        'Otogar',
        'Otogar',
        Icons.directions_bus_rounded,
        Color(0xFF3A86FF),
      ),
      const _AsistanKart(
        'Akaryakıt Fiyatları',
        'Akaryakıt Fiyatları',
        Icons.local_gas_station_rounded,
        Color(0xFFF59E0B),
      ),
      const _AsistanKart(
        'Hava Durumu',
        'Hava Durumu',
        Icons.wb_cloudy_rounded,
        Color(0xFF42A5F5),
      ),
      const _AsistanKart(
        'Barkod ve QR Sorgulama',
        'Barkod ve QR Sorgulama',
        Icons.qr_code_scanner_rounded,
        Color(0xFFFFA000),
      ),
      const _AsistanKart(
        'Acil Numaralar',
        'Acil',
        Icons.emergency_rounded,
        Color(0xFFE3262E),
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < kartlar.length; i++) ...[
          _listeKarti(kartlar[i]),
          if (i != kartlar.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _listeKarti(_AsistanKart kart) {
    return GestureDetector(
      onTap: () => _hedefeGit(kart.hedef),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _ikincilKart,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kart.renk.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(kart.ikon, color: kart.renk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                kart.baslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF666666),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _altBilgi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF666666),
            size: 18,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Asistan ilk sürümde yazdığın ihtiyacı ENöbet hizmetleriyle eşleştirir. Acil durumlarda doğrudan Acil bölümünü kullan.',
              style: TextStyle(
                color: Color(0xFF707070),
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _HizmetGorunumu _gorunum(String hedef) {
    return switch (hedef) {
      'Acil' => const _HizmetGorunumu(
          Icons.emergency_rounded,
          Color(0xFFE3262E),
        ),
      'Nöbetçi Eczane' => const _HizmetGorunumu(
          Icons.medication_rounded,
          Color(0xFFE3262E),
        ),
      'Hastane' => const _HizmetGorunumu(
          Icons.local_hospital_rounded,
          Color(0xFF3185E8),
        ),
      'Veteriner' => const _HizmetGorunumu(
          Icons.pets_rounded,
          Color(0xFF21C064),
        ),
      'Taksi' => const _HizmetGorunumu(
          Icons.local_taxi_rounded,
          Color(0xFFFFB020),
        ),
      'ATM' => const _HizmetGorunumu(
          Icons.local_atm_rounded,
          Color(0xFF7A5AF8),
        ),
      'Otel' => const _HizmetGorunumu(
          Icons.hotel_rounded,
          Color(0xFF00A6A6),
        ),
      'Elektrikli Şarj İstasyonu' => const _HizmetGorunumu(
          Icons.ev_station_rounded,
          Color(0xFFFF8A00),
        ),
      'Kargo' => const _HizmetGorunumu(
          Icons.local_shipping_rounded,
          Color(0xFF8E6CEF),
        ),
      'Otogar' => const _HizmetGorunumu(
          Icons.directions_bus_rounded,
          Color(0xFF3A86FF),
        ),
      'Akaryakıt Fiyatları' => const _HizmetGorunumu(
          Icons.local_gas_station_rounded,
          Color(0xFFF59E0B),
        ),
      'Hava Durumu' => const _HizmetGorunumu(
          Icons.wb_cloudy_rounded,
          Color(0xFF42A5F5),
        ),
      'Barkod ve QR Sorgulama' => const _HizmetGorunumu(
          Icons.qr_code_scanner_rounded,
          Color(0xFFFFA000),
        ),
      _ => const _HizmetGorunumu(
          Icons.auto_awesome_rounded,
          Color(0xFFE3262E),
        ),
    };
  }
}

class _AsistanKart {
  final String baslik;
  final String hedef;
  final IconData ikon;
  final Color renk;

  const _AsistanKart(this.baslik, this.hedef, this.ikon, this.renk);
}

class _HizmetGorunumu {
  final IconData ikon;
  final Color renk;

  const _HizmetGorunumu(this.ikon, this.renk);
}
