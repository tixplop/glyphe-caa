import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/ui/ecran_a_propos.dart';

/// Littéraux de texte d'interface hors `Textes` (AC-029-1).
/// Exception documentée : un littéral sans aucune lettre une fois les
/// interpolations retirées (séparateurs, ponctuation) n'est pas un texte.
List<String> litterauxInterdits(String source, String fichier) {
  final sansCommentaires = source.replaceAll(RegExp(r'//[^\n]*'), '');
  final motif = RegExp(
    r'''(?:\bText\(\s*(?:const\s+)?|\b(?:label|tooltip|hintText|labelText|helperText|errorText|semanticLabel|semanticsLabel)\s*:\s*(?:const\s+)?)(r?)('[^'\n]*'|"[^"\n]*")''',
  );
  final res = <String>[];
  for (final m in motif.allMatches(sansCommentaires)) {
    final lit = m
        .group(2)!
        .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
        .replaceAll(RegExp(r'\$\w+'), '');
    if (RegExp(r'\p{L}', unicode: true).hasMatch(lit)) {
      res.add('$fichier : ${m.group(0)}');
    }
  }
  return res;
}

void main() {
  test('REQ029_AC1 aucun littéral de texte d\'UI hors Textes', () {
    final fautes = <String>[];
    for (final f in Directory('lib/ui').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('textes.dart')) continue;
      fautes.addAll(litterauxInterdits(f.readAsStringSync(), f.path));
    }
    expect(fautes, isEmpty);
  });

  test('REQ029_AC1 le détecteur repère un littéral fautif', () {
    expect(litterauxInterdits("child: Text('Bonjour')", 'x'), isNotEmpty);
    expect(litterauxInterdits("Text(\n  'Salut')", 'x'), isNotEmpty);
    expect(litterauxInterdits("tooltip: 'Aide'", 'x'), isNotEmpty);
    expect(litterauxInterdits(r"Text('$nom : ${f(v)}')", 'x'), isEmpty);
  });

  for (final taille in const [
    Size(360, 640),
    Size(640, 360),
    Size(800, 1280),
    Size(1280, 800),
  ]) {
    testWidgets('REQ028_AC1/AC2/AC3/AC4 écran À propos $taille', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: EcranAPropos()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  }
}
