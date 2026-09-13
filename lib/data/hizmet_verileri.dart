import 'package:flutter/material.dart';
import '../models/hizmet.dart';

final List<Hizmet> hizmetler = [
  // =========================
  // VETERİNERLER
  // =========================

  Hizmet(
    id: 'veteriner_1',
    isim: 'Kadıköy Veteriner',
    kategori: 'Veteriner',
    adres: 'Bağdat Cd. No:120 Kadıköy / İstanbul',
    telefon: '0212 000 00 02',
    durum: 'Açık',
    mesafe: '800 m',
    calismaSaatleri: '00:00 - 23:59',
    ikon: Icons.pets_rounded,
    renk: Color(0xFF20C978),
    enlem: 40.9820,
    boylam: 29.0340,
    il: 'İstanbul',
    ilce: 'Kadıköy',
  ),

  Hizmet(
    id: 'veteriner_2',
    isim: 'Dostlar Veteriner',
    kategori: 'Veteriner',
    adres: 'Moda Cd. No:65 Kadıköy / İstanbul',
    telefon: '0212 000 00 05',
    durum: 'Açık',
    mesafe: '2.1 km',
    calismaSaatleri: '7/24',
    ikon: Icons.pets_rounded,
    renk: Color(0xFF20C978),
    enlem: 40.9790,
    boylam: 29.0300,
    il: 'İstanbul',
    ilce: 'Kadıköy',
  ),

  // =========================
  // ÇEKİCİLER
  // =========================

  Hizmet(
    id: 'cekici_1',
    isim: 'Hızlı Çekici',
    kategori: 'Çekici',
    adres: 'Kadıköy / İstanbul',
    telefon: '0212 000 00 03',
    durum: 'Müsait',
    mesafe: '1.2 km',
    calismaSaatleri: '7/24',
    ikon: Icons.car_repair_rounded,
    renk: Color(0xFF287BFF),
    enlem: 40.9900,
    boylam: 29.0200,
    il: 'İstanbul',
    ilce: 'Kadıköy',
  ),

  Hizmet(
    id: 'cekici_2',
    isim: '7/24 Oto Çekici',
    kategori: 'Çekici',
    adres: 'Fener Yolu / Kadıköy / İstanbul',
    telefon: '0212 000 00 06',
    durum: 'Müsait',
    mesafe: '2.8 km',
    calismaSaatleri: '7/24',
    ikon: Icons.car_repair_rounded,
    renk: Color(0xFF287BFF),
    enlem: 40.9750,
    boylam: 29.0400,
    il: 'İstanbul',
    ilce: 'Kadıköy',
  ),
];