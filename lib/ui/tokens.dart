import 'package:flutter/material.dart';

/// Tokens du design system (`design/glyphe-tokens.css`) : couleurs des thèmes
/// clair et sombre, espacements, rayons, tailles et styles de texte (REQ-035).
@immutable
class GlypheTokens extends ThemeExtension<GlypheTokens> {
  const GlypheTokens({
    required this.surface000,
    required this.surface100,
    required this.surface200,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.danger,
    required this.onDanger,
    required this.focus,
    required this.catPersonBg,
    required this.catPersonEdge,
    required this.catActionBg,
    required this.catActionEdge,
    required this.catObjectBg,
    required this.catObjectEdge,
    required this.catDescribeBg,
    required this.catDescribeEdge,
    required this.catSocialBg,
    required this.catSocialEdge,
    required this.catQuestionBg,
    required this.catQuestionEdge,
    required this.catLittleBg,
    required this.catLittleEdge,
    required this.ombreBarre,
  });

  final Color surface000;
  final Color surface100;
  final Color surface200;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color danger;
  final Color onDanger;
  final Color focus;
  final Color catPersonBg;
  final Color catPersonEdge;
  final Color catActionBg;
  final Color catActionEdge;
  final Color catObjectBg;
  final Color catObjectEdge;
  final Color catDescribeBg;
  final Color catDescribeEdge;
  final Color catSocialBg;
  final Color catSocialEdge;
  final Color catQuestionBg;
  final Color catQuestionEdge;
  final Color catLittleBg;
  final Color catLittleEdge;
  final List<BoxShadow> ombreBarre;

  static const GlypheTokens clair = GlypheTokens(
    surface000: Color(0xFFFFFFFF),
    surface100: Color(0xFFF6F4EF),
    surface200: Color(0xFFEBE7DF),
    ink: Color(0xFF1C1B19),
    inkMuted: Color(0xFF5A564E),
    border: Color(0xFF7D776B),
    primary: Color(0xFF1D5C87),
    onPrimary: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    focus: Color(0xFFB45309),
    catPersonBg: Color(0xFFFFF3B0),
    catPersonEdge: Color(0xFFA07800),
    catActionBg: Color(0xFFD6F0D2),
    catActionEdge: Color(0xFF2E7D32),
    catObjectBg: Color(0xFFFFE0C2),
    catObjectEdge: Color(0xFFB85C00),
    catDescribeBg: Color(0xFFD3E6FB),
    catDescribeEdge: Color(0xFF1D5FA8),
    catSocialBg: Color(0xFFFBD9EA),
    catSocialEdge: Color(0xFFA8306B),
    catQuestionBg: Color(0xFFE6DCF7),
    catQuestionEdge: Color(0xFF6A3FA0),
    catLittleBg: Color(0xFFFFFFFF),
    catLittleEdge: Color(0xFF8A8478),
    ombreBarre: [
      BoxShadow(color: Color(0x2E1C1B19), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  static const GlypheTokens sombre = GlypheTokens(
    surface000: Color(0xFF24221F),
    surface100: Color(0xFF171614),
    surface200: Color(0xFF2E2B27),
    ink: Color(0xFFF3EFE7),
    inkMuted: Color(0xFFB8B1A4),
    border: Color(0xFF8F887B),
    primary: Color(0xFF7CB8E6),
    onPrimary: Color(0xFF0B1D2B),
    danger: Color(0xFFF2A49C),
    onDanger: Color(0xFF3A0B07),
    focus: Color(0xFFF5B544),
    catPersonBg: Color(0xFF4A3D00),
    catPersonEdge: Color(0xFFF0CF45),
    catActionBg: Color(0xFF1F3D22),
    catActionEdge: Color(0xFF7FD18A),
    catObjectBg: Color(0xFF4A2A0A),
    catObjectEdge: Color(0xFFFFAA5C),
    catDescribeBg: Color(0xFF142F4F),
    catDescribeEdge: Color(0xFF7FB6F0),
    catSocialBg: Color(0xFF4A1830),
    catSocialEdge: Color(0xFFF29BC4),
    catQuestionBg: Color(0xFF2F1F4A),
    catQuestionEdge: Color(0xFFC3A6F0),
    catLittleBg: Color(0xFF24221F),
    catLittleEdge: Color(0xFFA59E90),
    ombreBarre: [
      BoxShadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 3),
    ],
  );

  /// Couleurs indexées par leur nom dans `glyphe-tokens.css` (sans `--`).
  Map<String, Color> get parNomCss => {
    'surface-000': surface000,
    'surface-100': surface100,
    'surface-200': surface200,
    'ink': ink,
    'ink-muted': inkMuted,
    'border': border,
    'primary': primary,
    'on-primary': onPrimary,
    'danger': danger,
    'on-danger': onDanger,
    'focus': focus,
    'cat-person-bg': catPersonBg,
    'cat-person-edge': catPersonEdge,
    'cat-action-bg': catActionBg,
    'cat-action-edge': catActionEdge,
    'cat-object-bg': catObjectBg,
    'cat-object-edge': catObjectEdge,
    'cat-describe-bg': catDescribeBg,
    'cat-describe-edge': catDescribeEdge,
    'cat-social-bg': catSocialBg,
    'cat-social-edge': catSocialEdge,
    'cat-question-bg': catQuestionBg,
    'cat-question-edge': catQuestionEdge,
    'cat-little-bg': catLittleBg,
    'cat-little-edge': catLittleEdge,
  };

  // Espacements.
  static const double espace1 = 4;
  static const double espace2 = 8;
  static const double espace3 = 12;
  static const double espace4 = 16;
  static const double espace5 = 24;
  static const double espace6 = 32;

  // Rayons.
  static const double rayonSm = 8;
  static const double rayonMd = 14;
  static const double rayonLg = 20;
  static const double rayonPilule = 999;

  // Tailles.
  static const double toucheMin = 48;
  static const double caseMin = 64;
  static const double caseDefaut = 88;
  static const double barrePhrase = 72;
  static const double barreAppli = 56;
  static const double anneauFocus = 3;
  static const double contourCase = 3;

  static const String famille = 'AtkinsonHyperlegible';

  // Styles de texte (la couleur vient du thème).
  static const TextStyle display = TextStyle(
    fontFamily: famille,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle title = TextStyle(
    fontFamily: famille,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(
    fontFamily: famille,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: famille,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle sentence = TextStyle(
    fontFamily: famille,
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle cellLabel = TextStyle(
    fontFamily: famille,
    fontSize: 17,
    height: 20 / 17,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle cellLabelSmall = TextStyle(
    fontFamily: famille,
    fontSize: 15,
    height: 18 / 15,
    fontWeight: FontWeight.w700,
  );

  static GlypheTokens of(BuildContext context) =>
      Theme.of(context).extension<GlypheTokens>() ?? clair;

  @override
  GlypheTokens copyWith() => this;

  @override
  GlypheTokens lerp(ThemeExtension<GlypheTokens>? other, double t) =>
      t < 0.5 || other is! GlypheTokens ? this : other;
}
