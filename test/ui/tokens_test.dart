import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/theme.dart';
import 'package:glyphe/ui/tokens.dart';

Map<String, String> _bloc(String css, RegExp debut) {
  final m = debut.firstMatch(css);
  if (m == null) throw StateError('bloc CSS introuvable : ${debut.pattern}');
  final fin = css.indexOf('}', m.end);
  final corps = css.substring(m.end, fin);
  return {
    for (final x in RegExp(
      r'--([a-z0-9-]+):\s*(#[0-9a-fA-F]{6})',
    ).allMatches(corps))
      x.group(1)!: x.group(2)!.toLowerCase(),
  };
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contraste(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  final css = File('design/glyphe-tokens.css').readAsStringSync();
  final clairCss = _bloc(css, RegExp(r':root, \[data-theme="light"\]\s*\{'));
  final sombreCss = _bloc(
    css,
    RegExp(r'^\[data-theme="dark"\]\s*\{', multiLine: true),
  );

  for (final (nom, tokens, attendu) in [
    ('clair', GlypheTokens.clair, clairCss),
    ('sombre', GlypheTokens.sombre, sombreCss),
  ]) {
    test('REQ035_AC1 couleurs du thème $nom = glyphe-tokens.css', () {
      expect(attendu, isNotEmpty);
      final dart = tokens.parNomCss;
      expect(dart.keys.toSet(), attendu.keys.toSet());
      for (final e in attendu.entries) {
        expect(_hex(dart[e.key]!), e.value, reason: e.key);
      }
    });

    test('REQ028_AC2 contrastes du thème $nom', () {
      final c = tokens.parNomCss;
      final surfaces = ['surface-000', 'surface-100', 'surface-200'];
      final fonds = [
        ...surfaces,
        for (final n in c.keys.where((k) => k.endsWith('-bg'))) n,
      ];
      for (final f in fonds) {
        expect(
          _contraste(c['ink']!, c[f]!),
          greaterThanOrEqualTo(4.5),
          reason: 'ink sur $f',
        );
      }
      for (final s in surfaces) {
        expect(
          _contraste(c['ink-muted']!, c[s]!),
          greaterThanOrEqualTo(4.5),
          reason: 'ink-muted sur $s',
        );
      }
      expect(_contraste(c['on-primary']!, c['primary']!), greaterThan(4.5));
      expect(_contraste(c['on-danger']!, c['danger']!), greaterThan(4.5));
      for (final n in ['border', 'focus']) {
        for (final s in ['surface-000', 'surface-100']) {
          expect(
            _contraste(c[n]!, c[s]!),
            greaterThanOrEqualTo(3),
            reason: '$n sur $s',
          );
        }
      }
    });
  }

  test('REQ035_AC1 constantes de dimension et styles de texte', () {
    expect(GlypheTokens.toucheMin, 48);
    expect(GlypheTokens.caseMin, 64);
    expect(GlypheTokens.caseDefaut, 88);
    expect(GlypheTokens.barrePhrase, 72);
    expect(GlypheTokens.barreAppli, 56);
    expect(GlypheTokens.anneauFocus, 3);
    expect(GlypheTokens.contourCase, 3);
    expect(GlypheTokens.rayonMd, 14);
    expect(GlypheTokens.cellLabel.fontSize, 17);
    expect(GlypheTokens.cellLabel.fontFamily, 'AtkinsonHyperlegible');
    expect(GlypheTokens.cellLabel.fontWeight, FontWeight.w700);
  });

  test('REQ035_AC7 marges internes de case et cell-label-small', () {
    expect(GlypheTokens.caseMargeX, 4);
    expect(GlypheTokens.caseMargeHaut, 2);
    expect(GlypheTokens.caseMargeBas, 1);
    expect(GlypheTokens.caseEcartPicto, 0);
    const s = GlypheTokens.cellLabelSmall;
    expect(s.fontSize, 15);
    expect(s.height, 18 / 15);
    expect(s.fontWeight, FontWeight.w700);
    expect(s.fontFamily, 'AtkinsonHyperlegible');
  });

  test('REQ035_AC7 REQ035_AC8 case-libelle et écarts de case', () {
    const s = GlypheTokens.caseLibelle;
    expect(s.fontFamily, 'AtkinsonHyperlegible');
    expect(s.fontWeight, FontWeight.w700);
    expect(s.fontSize, 13);
    expect(s.height, 16 / 13);
    expect(s.fontSize! * s.height!, closeTo(16, 1e-9));
    expect(s.leadingDistribution, TextLeadingDistribution.even);
    expect(GlypheTokens.caseEcartLibelle, 2);
    expect(GlypheTokens.caseLibelleMin, 32);
  });

  test('REQ035_AC2 themeGlyphe porte les tokens du thème', () {
    final clair = themeGlyphe(Brightness.light);
    final sombre = themeGlyphe(Brightness.dark);
    expect(clair.extension<GlypheTokens>(), same(GlypheTokens.clair));
    expect(sombre.extension<GlypheTokens>(), same(GlypheTokens.sombre));
    expect(sombre.brightness, Brightness.dark);
    expect(clair.scaffoldBackgroundColor, GlypheTokens.clair.surface100);
    expect(sombre.colorScheme.error, GlypheTokens.sombre.danger);
  });

  testWidgets('REQ035_AC2 MaterialApp suit le système', (tester) async {
    await tester.pumpWidget(const GlypheApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme!.brightness, Brightness.light);
    expect(app.darkTheme!.brightness, Brightness.dark);
  });

  test('REQ035_AC3 police embarquée, licence OFL présente', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: AtkinsonHyperlegible'));
    for (final f in [
      'AtkinsonHyperlegible-Regular.ttf',
      'AtkinsonHyperlegible-Bold.ttf',
      'OFL.txt',
    ]) {
      expect(File('assets/fonts/$f').existsSync(), isTrue, reason: f);
      if (f != 'OFL.txt') expect(pubspec, contains('assets/fonts/$f'));
    }
    expect(
      themeGlyphe(Brightness.light).textTheme.bodyLarge!.fontFamily,
      'AtkinsonHyperlegible',
    );
  });

  test('REQ035_AC5 pas d\'ondulation', () {
    expect(
      themeGlyphe(Brightness.light).splashFactory,
      same(NoSplash.splashFactory),
    );
  });
}
