import 'package:flutter/material.dart';

import 'models.dart';

const brandPurple = Color(0xFF7057F5);
const brandPurpleDark = Color(0xFF5238D6);
const brandPurpleLight = Color(0xFFA96AF7);
const brandLavender = Color(0xFFF0EDFF);
const brandSurface = Color(0xFFF8F7FC);
const brandSurfaceStrong = Color(0xFFF2F0F9);
const brandInk = Color(0xFF19172B);
const brandMuted = Color(0xFF77758A);
const brandBorder = Color(0xFFE9E6F1);
const brandGreen = Color(0xFF2FB77C);

const brandGradient = LinearGradient(
  colors: [brandPurpleDark, brandPurple, brandPurpleLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const brandSoftGradient = LinearGradient(
  colors: [Color(0xFFFFFFFF), Color(0xFFF2EFFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandPurple,
    brightness: Brightness.light,
    surface: brandSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: brandSurface,
    fontFamily: 'sans-serif',
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: brandInk,
          displayColor: brandInk,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: brandSurface,
      foregroundColor: brandInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(
        color: brandInk,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: const Color(0x1F362A70),
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF0EDF5)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: brandLavender,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? brandPurple
              : const Color(0xFFAAA7B8),
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? brandPurple
              : const Color(0xFF9996A8),
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        foregroundColor: brandInk,
        side: const BorderSide(color: brandBorder, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: brandBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: brandBorder),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: brandInk,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

Color decisionColor(BuildContext context, Decision decision) {
  return switch (decision) {
    Decision.match => brandGreen,
    Decision.review => const Color(0xFFE09A32),
    Decision.noMatch => brandMuted,
  };
}

String decisionTitle(Decision decision) {
  return switch (decision) {
    Decision.match => 'It’s an identical snap!',
    Decision.review => 'Possible match',
    Decision.noMatch => 'No match found',
  };
}

String decisionMessage(Decision decision) {
  return switch (decision) {
    Decision.match => 'Your photo matched another snap.',
    Decision.review =>
      'A similar image was found. Review the comparison before deciding.',
    Decision.noMatch =>
      'App will continue matching images as people upload and alert if any match is found.',
  };
}
