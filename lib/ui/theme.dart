import 'package:flutter/material.dart';

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

ThemeData themeGlyphe() => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.indigo,
  textTheme: Typography.blackMountainView,
);
