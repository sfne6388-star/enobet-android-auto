import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/hizmet.dart';
import '../services/favori_servisi.dart';
import '../services/hizmet_siralama.dart';
import '../theme/enobet_tema.dart';
import 'hizmet_detay.dart';

class Favoriler extends StatefulWidget {
  final List<Hizmet> hizmetler;
  final Position? konum;

  const Favoriler({
    super.key,
    this.konum,
    required this.hizmetler,
  });

  @override
  State<Favoriler> createState() => _FavorilerState();
}

class _FavorilerState extends State<Favoriler> {
  final FavoriServisi _favoriServisi = FavoriServisi();

  List<Hizmet> _favoriler = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _favorileriYukle();
  }

  Future<void> _favorileriYukle() async {
    try {
      final List<Hizmet> favoriler =
          await _favoriServisi.favorileriGetir();

      Position? konum = widget.konum;
      try {
        konum = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _favoriler = mesafeyeGoreSirala(favoriler, konum);
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _favoriler = [];
        _yukleniyor = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favoriler yüklenirken bir hata oluştu.'),
        ),
      );
    }
  }

  Future<void> _favoridenCikar(Hizmet hizmet) async {
    try {
      await _favoriServisi.favoridenCikar(hizmet.id);

      if (!mounted) return;

      setState(() {
        _favoriler.removeWhere((item) => item.id == hizmet.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(milliseconds: 1200),
          content: Text('Favorilerden çıkarıldı.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Favoriden çıkarma işlemi başarısız.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final EnobetTemaRenkleri tema = context.enobetTema;

    return Scaffold(
      backgroundColor: tema.arkaPlan,
      appBar: AppBar(
        backgroundColor: tema.appBar,
        foregroundColor: tema.anaYazi,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Favoriler',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _yukleniyor
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFE3262E),
                ),
              ),
            )
          : _favoriler.isEmpty
              ? _bosAlan(tema)
              : RefreshIndicator(
                  color: const Color(0xFFE3262E),
                  backgroundColor: tema.kart,
                  onRefresh: _favorileriYukle,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
                    itemCount: _favoriler.length,
                    itemBuilder: (context, index) {
                      final Hizmet hizmet = _favoriler[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _favoriKarti(hizmet, tema),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _bosAlan(EnobetTemaRenkleri tema) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFE3262E).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xFFE3262E),
                size: 42,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Henüz favoriniz yok',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tema.anaYazi,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Beğendiğiniz hizmetleri favorilere '
              'ekleyerek buradan kolayca ulaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tema.ikincilYazi,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriKarti(
    Hizmet hizmet,
    EnobetTemaRenkleri tema,
  ) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HizmetDetay(hizmet: hizmet),
          ),
        );

        await _favorileriYukle();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
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
                color: hizmet.renk.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                hizmet.ikon,
                color: hizmet.renk,
                size: 27,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hizmet.isim,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tema.anaYazi,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hizmet.kategori,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hizmet.renk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${hizmet.mesafe} • ${hizmet.adres}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tema.ikincilYazi,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                _favoridenCikar(hizmet);
              },
              tooltip: 'Favorilerden çıkar',
              icon: const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE3262E),
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
