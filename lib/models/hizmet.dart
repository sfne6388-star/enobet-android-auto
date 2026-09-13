import 'package:flutter/material.dart';

class Hizmet {
  final String id;
  final String isim;
  final String kategori;
  final String adres;
  final String telefon;
  final String durum;
  final String mesafe;
  final String calismaSaatleri;
  final IconData ikon;
  final Color renk;
  final double enlem;
  final double boylam;

  // Konum bilgileri
  final String il;
  final String ilce;

  Hizmet({
    required this.id,
    required this.isim,
    required this.kategori,
    required this.adres,
    required this.telefon,
    required this.durum,
    required this.mesafe,
    required this.calismaSaatleri,
    required this.ikon,
    required this.renk,
    required this.enlem,
    required this.boylam,
    required this.il,
    required this.ilce,
  });

  Hizmet copyWith({
    String? id,
    String? isim,
    String? kategori,
    String? adres,
    String? telefon,
    String? durum,
    String? mesafe,
    String? calismaSaatleri,
    IconData? ikon,
    Color? renk,
    double? enlem,
    double? boylam,
    String? il,
    String? ilce,
  }) {
    return Hizmet(
      id: id ?? this.id,
      isim: isim ?? this.isim,
      kategori: kategori ?? this.kategori,
      adres: adres ?? this.adres,
      telefon: telefon ?? this.telefon,
      durum: durum ?? this.durum,
      mesafe: mesafe ?? this.mesafe,
      calismaSaatleri:
          calismaSaatleri ?? this.calismaSaatleri,
      ikon: ikon ?? this.ikon,
      renk: renk ?? this.renk,
      enlem: enlem ?? this.enlem,
      boylam: boylam ?? this.boylam,
      il: il ?? this.il,
      ilce: ilce ?? this.ilce,
    );
  }
}