import 'package:flutter/material.dart';

import 'tokens.dart';

/// Palette fixe de couleurs de cases : toutes claires, contraste >= 4,5:1
/// avec le texte noir (REQ-028, AC-028-2).
class PaletteCases {
  const PaletteCases._();

  static const List<Color> couleurs = [
    Color(0xFFFFF9C4),
    Color(0xFFC8E6C9),
    Color(0xFFBBDEFB),
    Color(0xFFFFCCBC),
    Color(0xFFE1BEE7),
    Color(0xFFB2EBF2),
    Color(0xFFF8BBD0),
    Color(0xFFD7CCC8),
  ];

  static const Color parDefaut = Color(0xFFFFFFFF);
}

/// Thème Glyphe dérivé des tokens du design system (REQ-035).
ThemeData themeGlyphe(Brightness luminosite) {
  final t = luminosite == Brightness.dark
      ? GlypheTokens.sombre
      : GlypheTokens.clair;
  final scheme = ColorScheme(
    brightness: luminosite,
    primary: t.primary,
    onPrimary: t.onPrimary,
    secondary: t.primary,
    onSecondary: t.onPrimary,
    error: t.danger,
    onError: t.onDanger,
    surface: t.surface100,
    onSurface: t.ink,
    onSurfaceVariant: t.inkMuted,
    outline: t.border,
    outlineVariant: t.border,
    surfaceContainerLowest: t.surface000,
    surfaceContainerLow: t.surface000,
    surfaceContainer: t.surface000,
    surfaceContainerHigh: t.surface200,
    surfaceContainerHighest: t.surface200,
  );
  TextStyle s(TextStyle base) => base.copyWith(color: t.ink);
  return ThemeData(
    useMaterial3: true,
    brightness: luminosite,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.surface100,
    fontFamily: GlypheTokens.famille,
    splashFactory: NoSplash.splashFactory,
    focusColor: t.focus,
    textTheme: TextTheme(
      displayLarge: s(GlypheTokens.display),
      displayMedium: s(GlypheTokens.display),
      displaySmall: s(GlypheTokens.display),
      headlineLarge: s(GlypheTokens.title),
      headlineMedium: s(GlypheTokens.title),
      headlineSmall: s(GlypheTokens.title),
      titleLarge: s(GlypheTokens.title),
      titleMedium: s(GlypheTokens.body.copyWith(fontWeight: FontWeight.w700)),
      titleSmall: s(GlypheTokens.body.copyWith(fontWeight: FontWeight.w700)),
      bodyLarge: s(GlypheTokens.body),
      bodyMedium: s(GlypheTokens.body),
      bodySmall: s(GlypheTokens.caption),
      labelLarge: s(GlypheTokens.caption.copyWith(fontWeight: FontWeight.w700)),
      labelMedium: s(
        GlypheTokens.caption.copyWith(fontWeight: FontWeight.w700),
      ),
      labelSmall: s(GlypheTokens.caption),
    ),
    extensions: [t],
  );
}
