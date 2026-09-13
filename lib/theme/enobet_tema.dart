import 'package:flutter/material.dart';

const String temaTercihiAnahtari = 'tema_modu';
const String eskiKoyuTemaAnahtari = 'koyu_tema';

const String temaKoyu = 'koyu';
const String temaGumus = 'gumus';
const String temaAcik = 'acik';

bool gecerliTema(String? tema) =>
    tema == temaKoyu || tema == temaGumus || tema == temaAcik;

@immutable
class EnobetTemaRenkleri extends ThemeExtension<EnobetTemaRenkleri> {
  final String mod;
  final Color arkaPlan;
  final Color kart;
  final Color ikinciKart;
  final Color alan;
  final Color anaYazi;
  final Color ikincilYazi;
  final Color sinir;
  final Color appBar;
  final Color altMenu;

  const EnobetTemaRenkleri({
    required this.mod,
    required this.arkaPlan,
    required this.kart,
    required this.ikinciKart,
    required this.alan,
    required this.anaYazi,
    required this.ikincilYazi,
    required this.sinir,
    required this.appBar,
    required this.altMenu,
  });

  bool get koyu => mod == temaKoyu;
  bool get gumus => mod == temaGumus;
  bool get acik => mod == temaAcik;

  static const koyuRenkler = EnobetTemaRenkleri(
    mod: temaKoyu,
    arkaPlan: Color(0xFF070707),
    kart: Color(0xFF111111),
    ikinciKart: Color(0xFF1A1A1A),
    alan: Color(0xFF202022),
    anaYazi: Color(0xFFFFFFFF),
    ikincilYazi: Color(0xFFAAAAAE),
    sinir: Color(0xFF2A2A2E),
    appBar: Color(0xFF070707),
    altMenu: Color(0xFF111113),
  );

  static const gumusRenkler = EnobetTemaRenkleri(
    mod: temaGumus,
    arkaPlan: Color(0xFFB9BDC5),
    kart: Color(0xFFD8DBE0),
    ikinciKart: Color(0xFFC9CDD4),
    alan: Color(0xFFE5E7EA),
    anaYazi: Color(0xFF202126),
    ikincilYazi: Color(0xFF565A62),
    sinir: Color(0xFFA7ACB4),
    appBar: Color(0xFFB9BDC5),
    altMenu: Color(0xFFD1D4D9),
  );

  static const acikRenkler = EnobetTemaRenkleri(
    mod: temaAcik,
    arkaPlan: Color(0xFFFFFFFF),
    kart: Color(0xFFFFFFFF),
    ikinciKart: Color(0xFFF4F4F6),
    alan: Color(0xFFF7F7F9),
    anaYazi: Color(0xFF17171A),
    ikincilYazi: Color(0xFF64646F),
    sinir: Color(0xFFE1E1E6),
    appBar: Color(0xFFFFFFFF),
    altMenu: Color(0xFFF7F7F9),
  );

  static EnobetTemaRenkleri temaIcin(String mod) {
    switch (mod) {
      case temaGumus:
        return gumusRenkler;
      case temaAcik:
        return acikRenkler;
      case temaKoyu:
      default:
        return koyuRenkler;
    }
  }

  @override
  EnobetTemaRenkleri copyWith({
    String? mod,
    Color? arkaPlan,
    Color? kart,
    Color? ikinciKart,
    Color? alan,
    Color? anaYazi,
    Color? ikincilYazi,
    Color? sinir,
    Color? appBar,
    Color? altMenu,
  }) {
    return EnobetTemaRenkleri(
      mod: mod ?? this.mod,
      arkaPlan: arkaPlan ?? this.arkaPlan,
      kart: kart ?? this.kart,
      ikinciKart: ikinciKart ?? this.ikinciKart,
      alan: alan ?? this.alan,
      anaYazi: anaYazi ?? this.anaYazi,
      ikincilYazi: ikincilYazi ?? this.ikincilYazi,
      sinir: sinir ?? this.sinir,
      appBar: appBar ?? this.appBar,
      altMenu: altMenu ?? this.altMenu,
    );
  }

  @override
  EnobetTemaRenkleri lerp(
    covariant EnobetTemaRenkleri? other,
    double t,
  ) {
    if (other is! EnobetTemaRenkleri) return this;
    return EnobetTemaRenkleri(
      mod: t < 0.5 ? mod : other.mod,
      arkaPlan: Color.lerp(arkaPlan, other.arkaPlan, t)!,
      kart: Color.lerp(kart, other.kart, t)!,
      ikinciKart: Color.lerp(ikinciKart, other.ikinciKart, t)!,
      alan: Color.lerp(alan, other.alan, t)!,
      anaYazi: Color.lerp(anaYazi, other.anaYazi, t)!,
      ikincilYazi: Color.lerp(ikincilYazi, other.ikincilYazi, t)!,
      sinir: Color.lerp(sinir, other.sinir, t)!,
      appBar: Color.lerp(appBar, other.appBar, t)!,
      altMenu: Color.lerp(altMenu, other.altMenu, t)!,
    );
  }
}

extension EnobetTemaContext on BuildContext {
  EnobetTemaRenkleri get enobetTema {
    return Theme.of(this).extension<EnobetTemaRenkleri>() ??
        (Theme.of(this).brightness == Brightness.dark
            ? EnobetTemaRenkleri.koyuRenkler
            : EnobetTemaRenkleri.acikRenkler);
  }
}

ThemeData enobetTemaOlustur(String mod) {
  final renkler = EnobetTemaRenkleri.temaIcin(mod);
  final brightness = renkler.koyu ? Brightness.dark : Brightness.light;

  final ColorScheme renkSemasi = ColorScheme.fromSeed(
    seedColor: const Color(0xFFE3262E),
    brightness: brightness,
  ).copyWith(
    surface: renkler.kart,
    onSurface: renkler.anaYazi,
    surfaceContainerLowest: renkler.arkaPlan,
    surfaceContainerLow: renkler.alan,
    surfaceContainer: renkler.kart,
    surfaceContainerHigh: renkler.ikinciKart,
    surfaceContainerHighest: renkler.ikinciKart,
    outline: renkler.sinir,
    outlineVariant: renkler.sinir,
  );

  final ThemeData temel = ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: renkler.arkaPlan,
    canvasColor: renkler.kart,
    cardColor: renkler.kart,
    fontFamily: 'Arial',
    useMaterial3: true,
    colorScheme: renkSemasi,
    extensions: <ThemeExtension<dynamic>>[renkler],
  );

  return temel.copyWith(
    textTheme: temel.textTheme.apply(
      bodyColor: renkler.anaYazi,
      displayColor: renkler.anaYazi,
    ),
    primaryTextTheme: temel.primaryTextTheme.apply(
      bodyColor: renkler.anaYazi,
      displayColor: renkler.anaYazi,
    ),
    iconTheme: IconThemeData(color: renkler.anaYazi),
    appBarTheme: AppBarTheme(
      backgroundColor: renkler.appBar,
      foregroundColor: renkler.anaYazi,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: renkler.kart,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: renkler.kart,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: renkler.kart,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: temel.textTheme.titleLarge?.copyWith(
        color: renkler.anaYazi,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: temel.textTheme.bodyMedium?.copyWith(
        color: renkler.anaYazi,
      ),
    ),
    dividerTheme: DividerThemeData(color: renkler.sinir),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: renkler.alan,
      labelStyle: TextStyle(color: renkler.ikincilYazi),
      hintStyle: TextStyle(color: renkler.ikincilYazi),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: renkler.sinir),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3262E), width: 1.4),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: renkler.anaYazi,
      iconColor: renkler.anaYazi,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: renkler.altMenu,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: renkler.anaYazi),
      ),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: renkler.anaYazi),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: renkler.koyu
          ? const Color(0xFF29292D)
          : const Color(0xFF303137),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
  );
}
