import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/barre_navigation.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

Donnees exemples() => donneesDepuisJson(
  jsonDecode(File('assets/exemples/grilles_exemple.json').readAsStringSync()),
);

Future<EtatAppli> lance(
  WidgetTester tester, {
  Size taille = const Size(360, 640),
  Donnees? d,
  Brightness luminosite = Brightness.light,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.platformBrightnessTestValue = luminosite;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final etat = EtatAppli(
    stockage: FauxStockage(d ?? exemples()),
    voix: FauxVoix(),
    horloge: FausseHorloge(),
    jsonExemples: '{}',
  );
  await etat.init();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return etat;
}

Finder onglet(String id) => find.byKey(Key('onglet-$id'));
Finder barre() => find.byType(BarreNavigation);

Color contour(WidgetTester tester, String id) =>
    ((tester.widget<Material>(onglet(id)).shape!) as OutlinedBorder).side.color;

bool entier(WidgetTester tester, String id) {
  final zone = tester.getRect(find.byKey(const Key('onglets')));
  final r = tester.getRect(onglet(id));
  return r.left >= zone.left && r.right <= zone.right;
}

Donnees avecLibelleLong() => Donnees(
  accueilId: 'a',
  grilles: [
    Grille(
      id: 'a',
      nom: 'Accueil',
      lignes: 2,
      colonnes: 2,
      cases: [
        Case(
          id: 'd',
          ligne: 0,
          colonne: 0,
          type: TypeCase.dossier,
          libelle: 'Activités du week-end',
          cibleId: 'w',
        ),
      ],
    ),
    Grille(id: 'w', nom: 'Week-end', lignes: 2, colonnes: 2, cases: const []),
  ],
);

void main() {
  for (final lum in Brightness.values) {
    final t = lum == Brightness.light
        ? GlypheTokens.clair
        : GlypheTokens.sombre;
    group('Barre de navigation en icônes, thème ${lum.name}', () {
      testWidgets('REQ031_AC2 images et icône maison, aucun texte', (
        tester,
      ) async {
        await lance(tester, luminosite: lum);
        expect(
          find.descendant(
            of: onglet('accueil'),
            matching: find.byIcon(Icons.home_outlined),
          ),
          findsOneWidget,
        );
        for (final id in ['besoins', 'emotions', 'manger']) {
          expect(
            find.descendant(of: onglet(id), matching: find.byType(Image)),
            findsOneWidget,
            reason: id,
          );
        }
        expect(
          find.descendant(of: barre(), matching: find.byType(Text)),
          findsNothing,
        );
      });

      testWidgets('REQ031_AC4/AC9 actif : contour primary, une barre', (
        tester,
      ) async {
        final e = await lance(tester, luminosite: lum);
        expect(contour(tester, 'accueil'), t.primary);
        expect(contour(tester, 'besoins'), t.border);
        final indic = find.byKey(const Key('indicateur-onglet'));
        expect(indic, findsOneWidget);
        expect(tester.getSize(indic), const Size(20, 3));
        final r = tester.getRect(indic);
        final b = tester.getRect(barre());
        expect(b.contains(r.topLeft) && b.contains(r.bottomRight), isTrue);
        final d = tester.getRect(onglet('accueil'));
        expect(r.top - d.bottom, 2);
        expect(r.center.dx, closeTo(d.center.dx, 0.01));
        final deco = tester.widget<DecoratedBox>(indic).decoration;
        expect((deco as BoxDecoration).color, t.primary);
        // Sans onglet actif : aucune barre indicatrice.
        e.session.ouvrirGrille('fruits');
        await tester.pumpAndSettle();
        expect(indic, findsNothing);
        for (final id in ['accueil', 'besoins', 'emotions', 'manger']) {
          expect(contour(tester, id), t.border, reason: id);
        }
      });

      testWidgets('REQ031_AC10 repli texte : pilule, 128 max, sémantique', (
        tester,
      ) async {
        final h = tester.ensureSemantics();
        await lance(tester, d: avecLibelleLong(), luminosite: lum);
        final texte = find.descendant(
          of: onglet('w'),
          matching: find.byType(Text),
        );
        expect(texte, findsOneWidget);
        expect(tester.widget<Text>(texte).data, 'Activités du week-end');
        expect(tester.widget<Text>(texte).overflow, TextOverflow.ellipsis);
        final s = tester.getSize(onglet('w'));
        expect(s.height, 48);
        expect(s.width, lessThanOrEqualTo(128));
        expect(s.width, greaterThan(48));
        expect(
          tester.getSemantics(onglet('w')),
          isSemantics(
            label: 'Activités du week-end',
            isButton: true,
            isSelected: false,
          ),
        );
        h.dispose();
      });

      testWidgets('REQ031_AC12 ni info-bulle ni ondulation', (tester) async {
        final e = await lance(tester, luminosite: lum);
        expect(
          find.descendant(of: barre(), matching: find.byType(Tooltip)),
          findsNothing,
        );
        final ink = tester.widget<InkWell>(
          find.descendant(
            of: onglet('besoins'),
            matching: find.byType(InkWell),
          ),
        );
        expect(ink.splashFactory, NoSplash.splashFactory);
        expect(ink.highlightColor, t.ink.withValues(alpha: 0.12));
        // L'action se déclenche au relâcher, pas à l'appui.
        final avant = e.session.grilleCourante.id;
        final g = await tester.startGesture(
          tester.getCenter(onglet('besoins')),
        );
        await tester.pump();
        expect(e.session.grilleCourante.id, avant);
        await g.up();
        await tester.pumpAndSettle();
        expect(e.session.grilleCourante.id, 'besoins');
      });
    });
  }

  testWidgets('REQ031_AC7 360x640 : 4 onglets entiers, le 5e coupé', (
    tester,
  ) async {
    await lance(tester);
    for (final id in ['accueil', 'besoins', 'emotions', 'manger']) {
      expect(entier(tester, id), isTrue, reason: id);
    }
    final zone = tester.getRect(find.byKey(const Key('onglets')));
    final r = tester.getRect(onglet('jouer'));
    expect(r.left, lessThan(zone.right));
    expect(r.right, greaterThan(zone.right));
    expect(zone.right - r.left, closeTo(11, 1));
  });

  testWidgets('REQ031_AC7 412x915 : 5 onglets entiers', (tester) async {
    await lance(tester, taille: const Size(412, 915));
    for (final id in ['accueil', 'besoins', 'emotions', 'manger', 'jouer']) {
      expect(entier(tester, id), isTrue, reason: id);
    }
  });

  testWidgets('REQ031_AC11 appui sur la case Jouer : onglet Jouer entier', (
    tester,
  ) async {
    final e = await lance(tester);
    expect(entier(tester, 'jouer'), isFalse);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('grille')),
        matching: find.text('Jouer'),
      ),
    );
    // Sans animation : visible dès l'image suivante.
    await tester.pump();
    await tester.pump();
    expect(e.session.grilleCourante.id, 'jouer');
    expect(entier(tester, 'jouer'), isTrue);
    expect(contour(tester, 'jouer'), GlypheTokens.clair.primary);
    final indic = tester.getRect(find.byKey(const Key('indicateur-onglet')));
    final zone = tester.getRect(find.byKey(const Key('onglets')));
    expect(indic.right, lessThanOrEqualTo(zone.right));
    // Retour à l'accueil : l'onglet Accueil est de nouveau entier.
    expect(entier(tester, 'accueil'), isFalse);
    e.session.accueil();
    await tester.pump();
    await tester.pump();
    expect(entier(tester, 'accueil'), isTrue);
  });

  testWidgets('REQ036_AC7 Retour : flèche 28, sans info-bulle', (tester) async {
    await lance(tester);
    final icone = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('bouton-retour')),
        matching: find.byIcon(Icons.arrow_back),
      ),
    );
    expect(icone.size, 28);
    expect(find.byTooltip('Retour'), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('bouton-retour'))),
      const Size(48, 48),
    );
  });

  testWidgets('REQ031_AC8 Retour, disques et cadenas sur la même bande', (
    tester,
  ) async {
    await lance(tester);
    final tops = {
      tester.getRect(find.byKey(const Key('bouton-retour'))).top,
      tester.getRect(onglet('accueil')).top,
      tester.getRect(onglet('besoins')).top,
      tester.getRect(find.byKey(const Key('cadenas'))).top,
    };
    expect(tops.length, 1);
    final b = tester.getRect(barre());
    final haut = tops.first - b.top;
    expect(haut, closeTo((56 - 53) / 2, 0.01));
    expect(
      tester.getRect(onglet('besoins')).left -
          tester.getRect(onglet('accueil')).right,
      4,
    );
    final ic = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('cadenas')),
        matching: find.byIcon(Icons.lock_outline),
      ),
    );
    expect(ic.size, 24);
  });

  testWidgets('REQ031_AC12 anneau de focus entier dans la zone visible', (
    tester,
  ) async {
    await lance(tester);
    final anneau = find.descendant(
      of: barre(),
      matching: find.byKey(const Key('anneau-focus')),
    );
    var essais = 0;
    while (anneau.evaluate().isEmpty && essais++ < 10) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(anneau, findsOneWidget);
    final zone = tester.getRect(find.byKey(const Key('onglets')));
    final r = tester.getRect(anneau);
    final d = tester.getRect(onglet('accueil'));
    expect(r.left, d.left - 5);
    expect(r.size, const Size(58, 58));
    expect(zone.contains(r.topLeft), isTrue);
    expect(zone.contains(r.bottomRight), isTrue);
  });
}
