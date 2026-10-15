import 'package:flutter/material.dart';

import 'tokens.dart';

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
      labelLarge: s(GlypheTokens.body.copyWith(fontWeight: FontWeight.w700)),
      labelMedium: s(
        GlypheTokens.caption.copyWith(fontWeight: FontWeight.w700),
      ),
      labelSmall: s(GlypheTokens.caption),
    ),
    extensions: [t],
  );
}
