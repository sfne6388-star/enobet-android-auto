import 'package:flutter/material.dart';

import '../models/hizmet.dart';
import '../services/avm_magaza_servisi.dart';
import '../theme/enobet_tema.dart';

class AvmMagazalariEkrani extends StatefulWidget {
  final Hizmet avm;

  const AvmMagazalariEkrani({
    super.key,
    required this.avm,
  });

  @override
  State<AvmMagazalariEkrani> createState() => _AvmMagazalariEkraniState();
}

class _AvmMagazalariEkraniState extends State<AvmMagazalariEkrani> {
  final TextEditingController _aramaController = TextEditingController();

  bool _yukleniyor = true;
  String? _hata;
  String _arama = '';
  String _kategori = 'Tümü';
  AvmMagazaSonucu? _sonuc;

  static const List<String> _kategoriSirasi = <String>[
    'Tümü',
    'Giyim',
    'Ayakkabı',
    'Teknoloji',
    'Yeme İçme',
    'Kozmetik',
    'Market',
    'Eğlence',
    'Sağlık',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });

    try {
      final AvmMagazaSonucu sonuc =
          await AvmMagazaServisi.ortak.getir(widget.avm);

      if (!mounted) return;

      setState(() {
        _sonuc = sonuc;
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _hata =
            'Mağaza rehberi APK veri paketinden okunamadı. Uygulamayı yeniden açıp tekrar deneyin.';
        _yukleniyor = false;
      });
    }
  }

  List<AvmMagaza> get _filtreli {
    final List<AvmMagaza> kaynak =
        _sonuc?.magazalar ?? const <AvmMagaza>[];

    final String arama = _arama.trim().toLowerCase();

    return kaynak.where((AvmMagaza magaza) {
      if (_kategori != 'Tümü' && magaza.kategori != _kategori) {
        return false;
      }

      if (arama.isEmpty) return true;

      return magaza.isim.toLowerCase().contains(arama) ||
          magaza.tur.toLowerCase().contains(arama) ||
          magaza.kategori.toLowerCase().contains(arama) ||
          magaza.kat.toLowerCase().contains(arama);
    }).toList();
  }

  List<String> get _gorunenKategoriler {
    final Set<String> mevcut =
        (_sonuc?.magazalar ?? const <AvmMagaza>[])
            .map((AvmMagaza m) => m.kategori)
            .toSet();

    return _kategoriSirasi.where((String item) {
      return item == 'Tümü' || mevcut.contains(item);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.enobetTema;
    final List<AvmMagaza> magazalar = _filtreli;

    return Scaffold(
      backgroundColor: tema.arkaPlan,
      appBar: AppBar(
        backgroundColor: tema.appBar,
        foregroundColor: tema.anaYazi,
        elevation: 0,
        title: const Text(
          'Mağazalar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _avmBasligi(tema),
            const SizedBox(height: 14),
            _aramaKutusu(tema),
            if (!_yukleniyor && _sonuc != null) ...[
              const SizedBox(height: 12),
              _kategoriFiltreleri(tema),
            ],
            const SizedBox(height: 16),
            if (_yukleniyor)
              _yukleniyorAlani(tema)
            else if (_hata != null)
              _hataAlani(tema)
            else if ((_sonuc?.magazalar ?? const <AvmMagaza>[]).isEmpty)
              _bosAlani(tema)
            else if (magazalar.isEmpty)
              _filtreBosAlani(tema)
            else ...[
              _sonucBasligi(tema, magazalar.length),
              const SizedBox(height: 10),
              for (final AvmMagaza magaza in magazalar) ...[
                _magazaKarti(tema, magaza),
                const SizedBox(height: 9),
              ],
              const SizedBox(height: 4),
              _kaynakNotu(tema),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avmBasligi(EnobetTemaRenkleri tema) {
    final int toplam = _sonuc?.magazalar.length ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tema.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tema.sinir),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFB565F2).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_mall_rounded,
              color: Color(0xFFB565F2),
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.avm.isim,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tema.anaYazi,
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _yukleniyor
                      ? 'Mağaza rehberi hazırlanıyor...'
                      : '$toplam kayıt bulundu',
                  style: TextStyle(
                    color: tema.ikincilYazi,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aramaKutusu(EnobetTemaRenkleri tema) {
    return TextField(
      controller: _aramaController,
      onChanged: (String value) {
        setState(() => _arama = value);
      },
      style: TextStyle(
        color: tema.anaYazi,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Mağaza ara...',
        hintStyle: TextStyle(color: tema.ikincilYazi),
        prefixIcon: Icon(Icons.search_rounded, color: tema.ikincilYazi),
        suffixIcon: _arama.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _aramaController.clear();
                  setState(() => _arama = '');
                },
                icon: Icon(Icons.close_rounded, color: tema.ikincilYazi),
              ),
        filled: true,
        fillColor: tema.kart,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: tema.sinir),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: tema.sinir),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(
            color: Color(0xFFB565F2),
            width: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _kategoriFiltreleri(EnobetTemaRenkleri tema) {
    final List<String> kategoriler = _gorunenKategoriler;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final String kategori in kategoriler) ...[
            ChoiceChip(
              label: Text(kategori),
              selected: _kategori == kategori,
              onSelected: (_) {
                setState(() => _kategori = kategori);
              },
              selectedColor:
                  const Color(0xFFB565F2).withValues(alpha: 0.18),
              backgroundColor: tema.kart,
              side: BorderSide(
                color: _kategori == kategori
                    ? const Color(0xFFB565F2).withValues(alpha: 0.55)
                    : tema.sinir,
              ),
              labelStyle: TextStyle(
                color: _kategori == kategori
                    ? const Color(0xFFB565F2)
                    : tema.anaYazi,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              showCheckmark: false,
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _sonucBasligi(EnobetTemaRenkleri tema, int adet) {
    return Row(
      children: [
        Text(
          _kategori == 'Tümü' ? 'Mağazalar' : _kategori,
          style: TextStyle(
            color: tema.anaYazi,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          '$adet sonuç',
          style: TextStyle(
            color: tema.ikincilYazi,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _magazaKarti(
    EnobetTemaRenkleri tema,
    AvmMagaza magaza,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tema.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tema.sinir),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kategoriRengi(magaza.kategori).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _kategoriIkonu(magaza.kategori),
              color: _kategoriRengi(magaza.kategori),
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  magaza.isim,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tema.anaYazi,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _miniEtiket(
                      tema,
                      magaza.tur,
                      _kategoriRengi(magaza.kategori),
                    ),
                    if (magaza.kat.isNotEmpty)
                      _miniEtiket(
                        tema,
                        magaza.kat,
                        const Color(0xFF5C9DFF),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniEtiket(
    EnobetTemaRenkleri tema,
    String text,
    Color renk,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: renk,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _yukleniyorAlani(EnobetTemaRenkleri tema) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFB565F2),
            strokeWidth: 2.6,
          ),
          const SizedBox(height: 14),
          Text(
            'AVM içi mağaza rehberi hazırlanıyor...',
            style: TextStyle(
              color: tema.ikincilYazi,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hataAlani(EnobetTemaRenkleri tema) {
    return _mesajKarti(
      tema,
      icon: Icons.cloud_off_rounded,
      baslik: 'Mağaza listesi alınamadı',
      aciklama: _hata!,
      buton: 'Tekrar Dene',
      onTap: _yukle,
    );
  }

  Widget _bosAlani(EnobetTemaRenkleri tema) {
    return _mesajKarti(
      tema,
      icon: Icons.store_mall_directory_outlined,
      baslik: 'Mağaza kaydı bulunamadı',
      aciklama:
          'Bu AVM için açık kaynakta iç mağaza verisi bulunmuyor. '
          'AVM hizmet vermiyor anlamına gelmez; mağaza rehberi kaynağı eksik olabilir.',
    );
  }

  Widget _filtreBosAlani(EnobetTemaRenkleri tema) {
    return _mesajKarti(
      tema,
      icon: Icons.search_off_rounded,
      baslik: 'Eşleşen mağaza yok',
      aciklama: 'Arama veya kategori filtresini değiştirin.',
    );
  }

  Widget _mesajKarti(
    EnobetTemaRenkleri tema, {
    required IconData icon,
    required String baslik,
    required String aciklama,
    String? buton,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tema.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tema.sinir),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: const Color(0xFFB565F2),
          ),
          const SizedBox(height: 12),
          Text(
            baslik,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tema.anaYazi,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            aciklama,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tema.ikincilYazi,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (buton != null && onTap != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(buton),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB565F2),
                side: const BorderSide(color: Color(0xFFB565F2)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kaynakNotu(EnobetTemaRenkleri tema) {
    final bool sinirIci = _sonuc?.avmSiniriKullanildi ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tema.kart,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: tema.sinir),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: tema.ikincilYazi,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              sinirIci
                  ? 'Mağaza listesi APK hazırlanırken AVM sınırı içindeki güncel OpenStreetMap kayıtlarından oluşturuldu. '
                      'Mağazalar değişebildiği için bazı kayıtlar eksik veya eski olabilir.'
                  : 'Bu AVM için kesin sınır eşleştirmesi yapılamadığından yakın OpenStreetMap kayıtları kullanıldı. '
                      'Çevredeki bazı işletmeler listeye karışabilir.',
              style: TextStyle(
                color: tema.ikincilYazi,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _kategoriRengi(String kategori) {
    return switch (kategori) {
      'Giyim' => const Color(0xFFE56AB3),
      'Ayakkabı' => const Color(0xFFF59E0B),
      'Teknoloji' => const Color(0xFF5C9DFF),
      'Yeme İçme' => const Color(0xFFFF8A3D),
      'Kozmetik' => const Color(0xFFEC6FC8),
      'Market' => const Color(0xFF20B879),
      'Eğlence' => const Color(0xFF8B7CFF),
      'Sağlık' => const Color(0xFFE3262E),
      _ => const Color(0xFFB565F2),
    };
  }

  IconData _kategoriIkonu(String kategori) {
    return switch (kategori) {
      'Giyim' => Icons.checkroom_rounded,
      'Ayakkabı' => Icons.shopping_bag_rounded,
      'Teknoloji' => Icons.devices_rounded,
      'Yeme İçme' => Icons.restaurant_rounded,
      'Kozmetik' => Icons.spa_rounded,
      'Market' => Icons.shopping_cart_rounded,
      'Eğlence' => Icons.movie_rounded,
      'Sağlık' => Icons.local_pharmacy_rounded,
      _ => Icons.storefront_rounded,
    };
  }
}
