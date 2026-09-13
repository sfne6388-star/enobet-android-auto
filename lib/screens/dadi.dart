import 'package:flutter/material.dart';

import '../widgets/dadi_avatar.dart';

class DadiEkrani extends StatefulWidget {
  final String il;
  final String ilce;

  const DadiEkrani({
    super.key,
    this.il = '',
    this.ilce = '',
  });

  @override
  State<DadiEkrani> createState() => _DadiEkraniState();
}

class _DadiEkraniState extends State<DadiEkrani> {
  static const Color _yesil = Color(0xFF2F8F32);
  static const Color _yesilKoyu = Color(0xFF124E22);
  static const Color _kirmizi = Color(0xFFE3262E);
  static const Color _arkaPlan = Color(0xFF070907);
  static const Color _kart = Color(0xFF101610);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_DadiMesaj> _mesajlar = <_DadiMesaj>[
    const _DadiMesaj(
      metin:
          'Merhaba, ben DADI. Ne aradığını normal bir cümleyle yaz; seni doğru ENöbet bölümüne götüreyim.',
      dadi: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _konumHazir => widget.il.trim().isNotEmpty;

  String get _konumBaslik {
    final String il = widget.il.trim();
    final String ilce = widget.ilce.trim();
    if (il.isEmpty) return 'Konum bekleniyor';
    if (ilce.isEmpty) return il;
    return '$il / $ilce';
  }

  String get _konumMetni {
    if (!_konumHazir) {
      return 'Konum hazır olduğunda yakındaki hizmetleri de hızlıca açabilirim.';
    }
    return 'Konumun hazır. Yakındaki hizmetleri bu bölgeye göre açabilirim.';
  }

  void _gonder([String? hazirMetin]) {
    final String metin = (hazirMetin ?? _controller.text).trim();
    if (metin.isEmpty) return;

    _controller.clear();

    setState(() {
      _mesajlar.add(_DadiMesaj(metin: metin, dadi: false));
    });

    final _DadiCevap cevap = _cevapla(metin);

    Future<void>.delayed(
      const Duration(milliseconds: 230),
      () {
        if (!mounted) return;
        setState(() {
          _mesajlar.add(
            _DadiMesaj(
              metin: cevap.metin,
              dadi: true,
              eylem: cevap.eylem,
              eylemMetni: cevap.eylemMetni,
            ),
          );
        });
        _sonaKaydir();
      },
    );

    _sonaKaydir();
  }

  _DadiCevap _cevapla(String metin) {
    final String q = _normalize(metin);

    bool varMi(Iterable<String> kelimeler) =>
        kelimeler.any((String k) => q.contains(_normalize(k)));

    if (varMi(<String>['tesekkur', 'sağ ol', 'sag ol', 'eyvallah'])) {
      return const _DadiCevap(
        metin: 'Her zaman. İhtiyacın olduğunda buradayım.',
      );
    }

    if (varMi(<String>['merhaba', 'selam', 'gunaydin', 'iyi aksamlar'])) {
      return _DadiCevap(
        metin:
            'Merhaba. Şu an ${_konumHazir ? _konumBaslik : 'ENöbet'} için hazırım. Eczane, hastane, yol yardımı, şarj, noter, hava durumu ve daha fazlasını sorabilirsin.',
      );
    }

    if (varMi(<String>[
      'ne yapabilirsin',
      'neler yapabilirsin',
      'yardim',
      'yardım',
      'komutlar',
      'neleri biliyorsun',
    ])) {
      return const _DadiCevap(
        metin:
            'Nöbetçi eczane, hastane, veteriner, çekici, elektrikli şarj, oto lastik, çilingir, noter, otel, kargo, otogar, havaalanı, ATM, taksi, AVM & Outlet, hava durumu, döviz, akaryakıt fiyatları, yakındaki hizmetler ve Yol Asistanı bölümlerini açabilirim.',
      );
    }

    if (varMi(<String>['konumum', 'neredeyim', 'konum'])) {
      return _DadiCevap(
        metin: _konumHazir
            ? 'Şu an seçili konumun $_konumBaslik. Yakındaki hizmetleri buna göre açabilirim.'
            : 'Konum henüz hazır değil. ENöbet konumu belirlediğinde burada da kullanabilirim.',
        eylem: _konumHazir ? 'yakinimdaki' : null,
        eylemMetni: _konumHazir ? 'Yakınımdakileri Aç' : null,
      );
    }

    if (varMi(<String>['acil', '112', 'ambulans', 'itfaiye', 'polis'])) {
      return const _DadiCevap(
        metin:
            'Acil yardım bölümünü açabilirim. Hayati tehlike varsa doğrudan 112’yi ara.',
        eylem: 'acil',
        eylemMetni: 'Acil Hatları Aç',
      );
    }

    if (varMi(<String>[
      'yol asistani',
      'yol asistanı',
      'rota',
      'yolculuk',
      'gidecegim yer',
      'gideceğim yer',
    ])) {
      return const _DadiCevap(
        metin:
            'Yol Asistanı’nı açabilirim. Hedefini seçip güzergâh üzerindeki akaryakıt, şarj ve dinlenme noktalarını görebilirsin.',
        eylem: 'yol_asistani',
        eylemMetni: 'Yol Asistanını Aç',
      );
    }

    if (varMi(<String>[
      'şarj',
      'sarj',
      'elektrikli araç',
      'elektrikli arac',
      'ev şarj',
      'ev sarj',
    ])) {
      return const _DadiCevap(
        metin: 'Yakındaki elektrikli şarj istasyonlarını açabilirim.',
        eylem: 'Elektrikli Şarj İstasyonu',
        eylemMetni: 'Şarj İstasyonlarını Göster',
      );
    }

    if (varMi(<String>['çekici', 'cekici', 'yolda kaldim', 'yolda kaldım'])) {
      return const _DadiCevap(
        metin: 'Yakındaki çekici hizmetlerini gösterebilirim.',
        eylem: 'Çekici',
        eylemMetni: 'Çekicileri Göster',
      );
    }

    if (varMi(<String>['lastik', 'oto lastik', 'patlak'])) {
      return const _DadiCevap(
        metin: 'Yakındaki oto lastik hizmetlerini gösterebilirim.',
        eylem: 'Oto Lastik',
        eylemMetni: 'Oto Lastikleri Göster',
      );
    }

    if (varMi(<String>['çilingir', 'cilingir', 'anahtar', 'kilit'])) {
      return const _DadiCevap(
        metin: 'Yakındaki çilingirleri gösterebilirim.',
        eylem: 'Çilingir',
        eylemMetni: 'Çilingirleri Göster',
      );
    }

    if (varMi(<String>['eczane', 'nobetci eczane', 'nöbetçi eczane', 'ilaç', 'ilac'])) {
      return const _DadiCevap(
        metin: 'Nöbetçi eczaneleri gösterebilirim.',
        eylem: 'Nöbetçi Eczane',
        eylemMetni: 'Nöbetçi Eczaneleri Göster',
      );
    }

    if (varMi(<String>['hastane', 'acil servis', 'sağlık', 'saglik'])) {
      return const _DadiCevap(
        metin: 'Yakındaki hastaneleri gösterebilirim.',
        eylem: 'Hastane',
        eylemMetni: 'Hastaneleri Göster',
      );
    }

    if (varMi(<String>['veteriner', 'hayvan', 'pet'])) {
      return const _DadiCevap(
        metin: 'Veteriner sonuçlarını gösterebilirim.',
        eylem: 'Veteriner',
        eylemMetni: 'Veterinerleri Göster',
      );
    }

    if (varMi(<String>['noter', 'noterlik'])) {
      return const _DadiCevap(
        metin: 'Yakındaki noterleri gösterebilirim.',
        eylem: 'Noter',
        eylemMetni: 'Noterleri Göster',
      );
    }

    if (varMi(<String>['kargo', 'kurye'])) {
      return const _DadiCevap(
        metin: 'Yakındaki kargo noktalarını gösterebilirim.',
        eylem: 'Kargo',
        eylemMetni: 'Kargoları Göster',
      );
    }

    if (varMi(<String>['otogar', 'terminal', 'otobus terminali'])) {
      return const _DadiCevap(
        metin: 'Otogar sonuçlarını gösterebilirim.',
        eylem: 'Otogar',
        eylemMetni: 'Otogarları Göster',
      );
    }

    if (varMi(<String>['havaalani', 'havaalanı', 'havalimani', 'havalimanı', 'ucak', 'uçak'])) {
      return const _DadiCevap(
        metin: 'Yakındaki veya seçili ildeki havaalanlarını gösterebilirim.',
        eylem: 'Havaalanı',
        eylemMetni: 'Havaalanlarını Göster',
      );
    }

    if (varMi(<String>['atm', 'bankamatik', 'para cek', 'para çek'])) {
      return const _DadiCevap(
        metin: 'Yakındaki ATM’leri gösterebilirim.',
        eylem: 'ATM',
        eylemMetni: 'ATM’leri Göster',
      );
    }

    if (varMi(<String>['taksi', 'taxi'])) {
      return const _DadiCevap(
        metin: 'Yakındaki taksi noktalarını gösterebilirim.',
        eylem: 'Taksi',
        eylemMetni: 'Taksileri Göster',
      );
    }

    if (varMi(<String>['avm', 'outlet', 'alışveriş', 'alisveris', 'mağaza', 'magaza'])) {
      return const _DadiCevap(
        metin:
            'AVM ve Outlet sonuçlarını açabilirim. AVM detayından içerideki mağazalara da ulaşabilirsin.',
        eylem: 'AVM & Outlet',
        eylemMetni: 'AVM & Outlet Göster',
      );
    }

    if (varMi(<String>['otel', 'konaklama', 'kalacak yer'])) {
      return const _DadiCevap(
        metin: 'Bölgedeki otel sonuçlarını gösterebilirim.',
        eylem: 'Otel',
        eylemMetni: 'Otelleri Göster',
      );
    }

    if (varMi(<String>['hava', 'yağmur', 'yagmur', 'sıcaklık', 'sicaklik', 'derece'])) {
      return const _DadiCevap(
        metin: 'Hava durumunu açayım. Konumuna veya seçtiğin il / ilçeye göre bakabilirsin.',
        eylem: 'hava',
        eylemMetni: 'Hava Durumunu Aç',
      );
    }

    if (varMi(<String>['döviz', 'doviz', 'dolar', 'euro', 'sterlin', 'altın', 'altin', 'gümüş', 'gumus'])) {
      return const _DadiCevap(
        metin: 'Güncel döviz ve metal kurlarını açabilirim.',
        eylem: 'doviz',
        eylemMetni: 'Döviz Kurlarını Aç',
      );
    }

    if (varMi(<String>['benzin', 'mazot', 'motorin', 'akaryakıt', 'akaryakit', 'yakıt', 'yakit'])) {
      return const _DadiCevap(
        metin: 'Akaryakıt fiyatları bölümünü açabilirim.',
        eylem: 'akaryakit',
        eylemMetni: 'Akaryakıt Fiyatlarını Aç',
      );
    }

    if (varMi(<String>['yakınımda', 'yakinimda', 'yakındaki', 'yakindaki', 'çevremde', 'cevremde', 'harita'])) {
      return const _DadiCevap(
        metin: 'Yakınındaki hizmetleri harita üzerinde gösterebilirim.',
        eylem: 'yakinimdaki',
        eylemMetni: 'Yakınımdakileri Aç',
      );
    }

    return const _DadiCevap(
      metin:
          'Bunu doğrudan eşleştiremedim. “Ne yapabilirsin?” yazabilir veya aşağıdaki hızlı işlemlerden birini seçebilirsin.',
    );
  }

  void _eylem(String eylem) {
    Navigator.pop(context, eylem);
  }

  void _sonaKaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _arkaPlan,
      appBar: AppBar(
        backgroundColor: _arkaPlan,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DadiAvatar(size: 30, aktif: true, golge: false),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DADI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'ENöbet akıllı rehberi',
                  style: TextStyle(
                    color: Color(0xFF88B88C),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                children: <Widget>[
                  _hero(),
                  const SizedBox(height: 14),
                  _bolumBasligi('Hızlı işlemler', 'Tek dokunuşla aç'),
                  const SizedBox(height: 9),
                  _hizliIslemler(),
                  const SizedBox(height: 15),
                  _bolumBasligi('DADI’ye sor', 'Normal bir cümle yazabilirsin'),
                  const SizedBox(height: 9),
                  _ornekSorular(),
                  const SizedBox(height: 14),
                  ..._mesajlar.map(_mesajBalonu),
                ],
              ),
            ),
            _mesajKutusu(),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _yesil.withValues(alpha: 0.18),
            _kart,
            _yesilKoyu.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _yesil.withValues(alpha: 0.34)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _yesil.withValues(alpha: 0.10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const DadiAvatar(size: 76, aktif: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Text(
                      'Hazırım',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    _CanliNokta(),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Ne aradığını söyle, doğru bölümü ben açayım.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12.3,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _konumHazir ? Icons.my_location_rounded : Icons.location_searching_rounded,
                        color: _konumHazir ? _yesil : Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _konumBaslik,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 10.7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _bolumBasligi(String baslik, String altBaslik) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          altBaslik,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.36),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _hizliIslemler() {
    final List<_DadiHizliIslem> islemler = <_DadiHizliIslem>[
      const _DadiHizliIslem('Nöbetçi Eczane', Icons.local_pharmacy_rounded, _yesil),
      const _DadiHizliIslem('Yol Asistanı', Icons.alt_route_rounded, Color(0xFF4EA1FF)),
      const _DadiHizliIslem('Hastane', Icons.local_hospital_rounded, _kirmizi),
      const _DadiHizliIslem('Elektrikli Şarj', Icons.ev_station_rounded, Color(0xFF46C6A6)),
      const _DadiHizliIslem('Çekici', Icons.car_repair_rounded, Color(0xFFFFA726)),
      const _DadiHizliIslem('AVM & Outlet', Icons.local_mall_rounded, Color(0xFFA855F7)),
      const _DadiHizliIslem('Hava Durumu', Icons.cloud_rounded, Color(0xFF69A7FF)),
      const _DadiHizliIslem('Yakınımdakiler', Icons.near_me_rounded, Color(0xFF4DD0E1)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: islemler.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.55,
      ),
      itemBuilder: (context, index) {
        final _DadiHizliIslem item = islemler[index];
        return InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _gonder(item.metin),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: item.renk.withValues(alpha: 0.075),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: item.renk.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: item.renk.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.renk, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.metin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.8,
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

  Widget _ornekSorular() {
    const List<String> sorular = <String>[
      'Yolda kaldım, çekici bul',
      'En yakın noter nerede?',
      'Şarj istasyonu göster',
      'Bugün hava nasıl?',
      'Ne yapabilirsin?',
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _gonder(sorular[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Text(
                sorular[index],
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 10.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mesajBalonu(_DadiMesaj mesaj) {
    return Align(
      alignment: mesaj.dadi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 334),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: mesaj.dadi
              ? const Color(0xFF121A13)
              : _kirmizi.withValues(alpha: 0.15),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mesaj.dadi ? 5 : 17),
            bottomRight: Radius.circular(mesaj.dadi ? 17 : 5),
          ),
          border: Border.all(
            color: mesaj.dadi
                ? _yesil.withValues(alpha: 0.16)
                : _kirmizi.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (mesaj.dadi) ...<Widget>[
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DadiAvatar(size: 24, golge: false),
                  SizedBox(width: 7),
                  Text(
                    'DADI',
                    style: TextStyle(
                      color: _yesil,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
            ],
            Text(
              mesaj.metin,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 13.2,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (mesaj.eylem != null && mesaj.eylemMetni != null) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _eylem(mesaj.eylem!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _yesil,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: Text(
                    mesaj.eylemMetni!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mesajKutusu() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F0C),
        border: Border(top: BorderSide(color: _yesil.withValues(alpha: 0.12))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _gonder(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Örn. “Yolda kaldım, çekici lazım”',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.32)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Material(
            color: _yesil,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _gonder(),
              child: const Padding(
                padding: EdgeInsets.all(13),
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DadiMesaj {
  final String metin;
  final bool dadi;
  final String? eylem;
  final String? eylemMetni;

  const _DadiMesaj({
    required this.metin,
    required this.dadi,
    this.eylem,
    this.eylemMetni,
  });
}

class _DadiCevap {
  final String metin;
  final String? eylem;
  final String? eylemMetni;

  const _DadiCevap({
    required this.metin,
    this.eylem,
    this.eylemMetni,
  });
}

class _DadiHizliIslem {
  final String metin;
  final IconData icon;
  final Color renk;

  const _DadiHizliIslem(this.metin, this.icon, this.renk);
}

class _CanliNokta extends StatelessWidget {
  const _CanliNokta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _DadiEkraniState._yesil,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _DadiEkraniState._yesil.withValues(alpha: 0.55),
            blurRadius: 7,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
