import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/edition.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/ecran_a_propos.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/widgets/case_widget.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

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
    Size(640, 360),
    Size(915, 412),
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

  // AC-028-3 : grille entière visible, sans défilement ni débordement, cases
  // d'au moins 48 ; en 4×3, au moins 80 en 640×360 et 88 en 915×412.
  const minimaux43 = {640: 80.0, 915: 88.0, 1280: 88.0};
  for (final lignes in const [3, 4]) {
    for (final taille in const [
      Size(640, 360),
      Size(915, 412),
      Size(1280, 800),
    ]) {
      testWidgets('REQ028_AC3 grille 4×$lignes entière, cases lisibles '
          '$taille', (tester) async {
        tester.view.physicalSize = taille;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        var d = donneesDepuisJson(
          jsonDecode(
            File('assets/exemples/grilles_exemple.json').readAsStringSync(),
          ),
        );
        for (final g in d.grilles) {
          if (lignes == 4) d = redimensionnerGrille(d, g.id, 4, 4);
        }
        final etat = EtatAppli(
          stockage: FauxStockage(d),
          voix: FauxVoix(),
          horloge: FausseHorloge(),
          jsonExemples: '{}',
        );
        await etat.init();
        await tester.pumpWidget(GlypheApp(etat: etat));
        await tester.pumpAndSettle();
        for (final g in d.grilles) {
          etat.session.ouvrirGrille(g.id);
          await tester.pumpAndSettle();
          final ecran = '${g.id} ${g.lignes}x${g.colonnes} $taille';
          expect(tester.takeException(), isNull, reason: ecran);
          final zone = tester.getRect(find.byKey(const Key('grille')));
          expect(zone.left, greaterThanOrEqualTo(0), reason: ecran);
          expect(zone.top, greaterThanOrEqualTo(0), reason: ecran);
          expect(zone.right, lessThanOrEqualTo(taille.width), reason: ecran);
          expect(zone.bottom, lessThanOrEqualTo(taille.height), reason: ecran);
          expect(
            find.descendant(
              of: find.byKey(const Key('grille')),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
            reason: ecran,
          );
          final mini = g.lignes == 3 && g.colonnes == 4
              ? minimaux43[taille.width.toInt()]!
              : 48.0;
          final cases = find.descendant(
            of: find.byKey(const Key('grille')),
            matching: find.byType(CaseWidget),
          );
          expect(cases, findsWidgets, reason: ecran);
          for (final c in cases.evaluate()) {
            final r = tester
                .getRect(find.byElementPredicate((x) => x == c))
                .deflate(3);
            expect(r.width, greaterThanOrEqualTo(mini), reason: ecran);
            expect(r.height, greaterThanOrEqualTo(mini), reason: ecran);
          }
        }
      });
    }
  }
}
