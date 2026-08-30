import 'package:flutter/material.dart';

import 'models.dart';

const brandPurple = Color(0xFF715CF6);
const brandPurpleDark = Color(0xFF5B46DE);
const brandLavender = Color(0xFFF1EFFF);
const brandInk = Color(0xFF1C2033);
const brandMuted = Color(0xFF73798C);
const brandBorder = Color(0xFFE4E6EE);
const brandGreen = Color(0xFF3DBD83);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandPurple,
    brightness: Brightness.light,
    surface: const Color(0xFFF9FAFC),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF9FAFC),
    fontFamily: 'sans-serif',
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: brandInk,
          displayColor: brandInk,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF9FAFC),
      foregroundColor: brandInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: brandInk,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: brandBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 74,
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: brandLavender,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? brandPurple
              : const Color(0xFFA3A8B7),
          size: 23,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? brandPurple
              : const Color(0xFFA3A8B7),
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: brandInk,
        side: const BorderSide(color: brandBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: brandBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: brandBorder),
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
