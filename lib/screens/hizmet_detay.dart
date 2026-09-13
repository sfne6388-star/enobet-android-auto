import '../services/telefon_bilgisi.dart';
import '../services/taksi_telefon_servisi.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hizmet.dart';
import '../services/favori_servisi.dart';
import '../services/hizli_yerel_hizmet_servisi.dart';
import '../theme/enobet_tema.dart';

import 'avm_magazalari.dart';

class HizmetDetay extends StatefulWidget {
  final Hizmet hizmet;

  const HizmetDetay({super.key, required this.hizmet});

  @override
  State<HizmetDetay> createState() => _HizmetDetayState();
}

class _HizmetDetayState extends State<HizmetDetay> {
  final FavoriServisi _favoriServisi = FavoriServisi();

  bool _favori = false;
  bool _favoriYukleniyor = true;
  bool _taksiTelefonAraniyor = false;

  Hizmet? _guncelHizmet;
  Hizmet get hizmet => _guncelHizmet ?? widget.hizmet;

  @override
  void initState() {
    super.initState();
    _favoriDurumunuGetir();
    _kayitliTelefonuTamamla();
  }

  Future<void> _kayitliTelefonuTamamla() async {
    if (aranacakTelefon(hizmet.telefon) != null) return;
    final ilk = widget.hizmet;

    try {
      final kayitlar = await YerelHizmetServisi.ortak.tumu();
      for (final kayit in kayitlar) {
        if (kayit.id == ilk.id &&
            kayit.kategori == ilk.kategori &&
            aranacakTelefon(kayit.telefon) != null) {
          if (!mounted || widget.hizmet.id != ilk.id) return;
          setState(() {
            _guncelHizmet = ilk.copyWith(telefon: kayit.telefon);
          });
          return;
        }
      }
    } catch (_) {
      // Yerel paket okunamazsa çevrimiçi açık veri kontrolüne devam et.
    }

    if (ilk.kategori == 'Taksi') {
      await _taksiTelefonunuBul(ilk, sessiz: true);
    }
  }

  Future<String?> _taksiTelefonunuBul(
    Hizmet ilk, {
    bool sessiz = false,
  }) async {
    if (_taksiTelefonAraniyor) return aranacakTelefon(hizmet.telefon);
    if (aranacakTelefon(hizmet.telefon) != null) return hizmet.telefon;

    if (mounted) {
      setState(() => _taksiTelefonAraniyor = true);
    }

    try {
      final bulunan = await TaksiTelefonServisi.ortak.telefonBul(ilk);
      if (!mounted || widget.hizmet.id != ilk.id) return bulunan;
      if (aranacakTelefon(bulunan ?? '') != null) {
        setState(() {
          _guncelHizmet = ilk.copyWith(telefon: bulunan);
        });
        return bulunan;
      }
      if (!sessiz) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu taksi durağının telefon numarası açık kaynakta bulunamadı.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _taksiTelefonAraniyor = false);
      }
    }
    return null;
  }

  Future<void> _favoriDurumunuGetir() async {
    final bool favori = await _favoriServisi.favoriMi(hizmet.id);

    if (!mounted) return;

    setState(() {
      _favori = favori;
      _favoriYukleniyor = false;
    });
  }

  Future<void> _favoriyiDegistir() async {
    if (_favoriYukleniyor) return;

    final bool eskiDurum = _favori;

    setState(() {
      _favori = !_favori;
    });

    try {
      if (_favori) {
        await _favoriServisi.favoriyeEkle(hizmet);
      } else {
        await _favoriServisi.favoridenCikar(hizmet.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          content: Text(
            _favori ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _favori = eskiDurum;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Favori işlemi gerçekleştirilemedi.')),
      );
    }
  }

  Future<void> _yolTarifiAc(BuildContext context) async {
    if (hizmet.enlem == 0 || hizmet.boylam == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu hizmet için konum bilgisi bulunamadı.'),
          ),
        );
      }
      return;
    }

    final Uri haritaUrl = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${hizmet.enlem},${hizmet.boylam}',
    });

    try {
      final bool acildi = await launchUrl(
        haritaUrl,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!acildi && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Harita açılamadı.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yol tarifi açılırken bir hata oluştu.'),
          ),
        );
      }
    }
  }

  Future<void> _telefonAra(BuildContext context) async {
    String? temizTelefon = aranacakTelefon(hizmet.telefon);

    if (temizTelefon == null && hizmet.kategori == 'Taksi') {
      final bulunan = await _taksiTelefonunuBul(widget.hizmet);
      temizTelefon = aranacakTelefon(bulunan ?? hizmet.telefon);
    }

    if (temizTelefon == null) {
      if (context.mounted && hizmet.kategori != 'Taksi') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu hizmet için telefon numarası bulunamadı.'),
          ),
        );
      }
      return;
    }

    final Uri telefonUrl = Uri.parse('tel:$temizTelefon');

    try {
      final bool acildi = await launchUrl(
        telefonUrl,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );

      if (!acildi && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon uygulaması açılamadı.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama başlatılırken bir hata oluştu.')),
        );
      }
    }
  }

  Future<void> _avmMagazalariniAc() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvmMagazalariEkrani(avm: hizmet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.enobetTema;
    final String durum = hizmet.durum.toLowerCase().trim();

    final bool acikMi =
        durum == 'açık' || durum == 'müsait' || durum == '7/24 açık';

    final bool kapaliMi = durum == 'kapalı';

    final Color durumRengi = acikMi
        ? const Color(0xFF20C978)
        : kapaliMi
        ? const Color(0xFFE3262E)
        : hizmet.renk;

    return Scaffold(
      backgroundColor: tema.arkaPlan,
      appBar: AppBar(
        backgroundColor: tema.appBar,
        foregroundColor: tema.anaYazi,
        elevation: 0,
        title: const Text(
          'Hizmet Detayı',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _favoriyiDegistir,
            tooltip: _favori ? 'Favorilerden çıkar' : 'Favorilere ekle',
            icon: _favoriYukleniyor
                ? SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(tema.ikincilYazi),
                    ),
                  )
                : Icon(
                    _favori
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _favori ? const Color(0xFFE3262E) : tema.anaYazi,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: hizmet.renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(hizmet.ikon, color: hizmet.renk, size: 42),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                hizmet.isim,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                hizmet.kategori,
                style: TextStyle(
                  color: hizmet.renk,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (hizmet.kategori == 'Taksi') ...[
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _taksiTelefonAraniyor
                      ? null
                      : () => _telefonAra(context),
                  icon: _taksiTelefonAraniyor
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.local_taxi_rounded, size: 26),
                  label: Text(
                    _taksiTelefonAraniyor ? 'TELEFON ARANIYOR...' : 'ÇAĞIR',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB020),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _bilgiKutusu(Icons.location_on_rounded, 'Adres', hizmet.adres),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: aranacakTelefon(hizmet.telefon) == null
                  ? null
                  : () => _telefonAra(context),
              child: _bilgiKutusu(
                Icons.phone_rounded,
                'Telefon',
                aranacakTelefon(hizmet.telefon) == null
                    ? 'Telefon numarası kaynakta bulunmuyor'
                    : hizmet.telefon.trim(),
                tiklanabilir: true,
              ),
            ),
            const SizedBox(height: 12),
            _bilgiKutusu(
              Icons.access_time_rounded,
              'Çalışma Saatleri',
              hizmet.calismaSaatleri,
            ),
            const SizedBox(height: 12),
            _bilgiKutusu(Icons.near_me_rounded, 'Mesafe', hizmet.mesafe),
            const SizedBox(height: 24),
            if (hizmet.kategori == 'AVM & Outlet') ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _avmMagazalariniAc,
                  icon: const Icon(Icons.storefront_rounded, size: 25),
                  label: const Text(
                    'Mağazalar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB565F2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _yolTarifiAc(context),
                icon: const Icon(Icons.directions_rounded, size: 25),
                label: const Text(
                  'Yol Tarifi Al',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hizmet.renk,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: durumRengi.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: durumRengi.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: durumRengi, size: 12),
                  const SizedBox(width: 9),
                  Text(
                    hizmet.durum,
                    style: TextStyle(
                      color: durumRengi,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (hizmet.kategori == 'Eczane')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: tema.kart,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: tema.sinir,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: hizmet.renk,
                      size: 23,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Veri: Eczane Adresi\n'
                        'Nöbetçi eczane bilgileri internet '
                        'üzerinden güncel olarak alınmaktadır.',
                        style: TextStyle(
                          color: tema.ikincilYazi,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiKutusu(
    IconData icon,
    String baslik,
    String deger, {
    bool tiklanabilir = false,
  }) {
    final tema = context.enobetTema;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: tema.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tiklanabilir
              ? hizmet.renk.withValues(alpha: 0.20)
              : tema.sinir,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: hizmet.renk, size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baslik,
                  style: TextStyle(
                    color: tema.ikincilYazi,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deger,
                  style: TextStyle(
                    color: tema.anaYazi,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: tiklanabilir
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (tiklanabilir)
            Icon(Icons.call_rounded, color: hizmet.renk, size: 20),
        ],
      ),
    );
  }
}
