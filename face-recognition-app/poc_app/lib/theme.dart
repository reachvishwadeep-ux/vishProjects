import 'package:flutter/material.dart';

import 'models.dart';

const _seed = Color(0xFF6557E8);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF7F7FC)
        : const Color(0xFF111119),
    cardTheme: CardThemeData(
      elevation: 0,
      color: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1C1B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

Color decisionColor(BuildContext context, Decision decision) {
  return switch (decision) {
    Decision.match => const Color(0xFF16865B),
    Decision.review => const Color(0xFFD38714),
    Decision.noMatch => Theme.of(context).colorScheme.outline,
  };
}

String decisionTitle(Decision decision) {
  return switch (decision) {
    Decision.match => 'Match found',
    Decision.review => 'Possible match',
    Decision.noMatch => 'No match',
  };
}

String decisionMessage(Decision decision) {
  return switch (decision) {
    Decision.match => 'This photo closely matches an image in your repository.',
    Decision.review =>
      'A similar image was found. Review the comparison before deciding.',
    Decision.noMatch => 'No stored image passed the similarity threshold.',
  };
}
