import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/widgets/barre_edition.dart';
import 'package:glyphe/ui/widgets/barre_navigation.dart';
import 'package:glyphe/ui/widgets/barre_phrase.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

Case mot(
  String id,
  String lib,
  int l,
  int c, {
  String texte = '',
  Categorie categorie = Categorie.petitMot,
}) => Case(
  id: id,
  ligne: l,
  colonne: c,
  type: TypeCase.mot,
  libelle: lib,
  textePrononce: texte,
  image: ImageArasaac(2617),
  categorie: categorie,
);

Case dossier(String id, String lib, int l, int c, String? cible) => Case(
  id: id,
  ligne: l,
  colonne: c,
  type: TypeCase.dossier,
  libelle: lib,
  cibleId: cible,
);

Donnees donnees() => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 4,
      colonnes: 4,
      cases: [
        mot('je', 'je', 0, 0),
        mot('veux', 'veux', 0, 1),
        mot('manger', 'manger', 0, 2),
        mot('eau', 'eau', 0, 3, categorie: Categorie.description),
        mot('wc', 'WC', 1, 0, texte: 'je veux aller aux toilettes'),
        dossier('d-manger', 'Manger', 1, 1, 'manger-g'),
        dossier('d-orph', 'Perdu', 1, 2, 'inexistante'),
        mot('a', 'alpha', 2, 0),
        mot('b', 'bravo', 2, 1),
        mot('c', 'charlie', 2, 2),
        mot('d', 'delta', 2, 3),
        mot('e', 'echo', 3, 0),
        mot('f', 'foxtrot', 3, 1),
        mot('g', 'golf', 3, 2),
        mot('h', 'hotel', 3, 3),
      ],
    ),
    Grille(
      id: 'manger-g',
      nom: 'Manger',
      lignes: 4,
      colonnes: 4,
      cases: [
        mot('pomme', 'pomme', 0, 0),
        dossier('d-fruits', 'Fruits', 0, 1, 'fruits-g'),
      ],
    ),
    Grille(
      id: 'fruits-g',
      nom: 'Fruits',
      lignes: 4,
      colonnes: 4,
      cases: [mot('poire', 'poire', 0, 0)],
    ),
  ],
);

class Env {
  Env(this.stockage, this.voix, this.etat);
  final FauxStockage stockage;
  final FauxVoix voix;
  final EtatAppli etat;
}

Future<Env> lance(
  WidgetTester tester, {
  Size taille = const Size(360, 640),
  Donnees? d,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final stockage = FauxStockage(d ?? donnees());
  final voix = FauxVoix();
  final etat = EtatAppli(
    stockage: stockage,
    voix: voix,
    horloge: FausseHorloge(),
    jsonExemples: '{}',
  );
  await etat.init();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return Env(stockage, voix, etat);
}

Finder dansBarre(Finder f) =>
    find.descendant(of: find.byType(BarrePhrase), matching: f);

Finder grille(String libelle) => find.descendant(
  of: find.byKey(const Key('grille')),
  matching: find.text(libelle),
);

void main() {
  group('EtatAppli', () {
    test('REQ025_AC3 démarre à l\'accueil, barre vide, verrouillé', () async {
      final etat = EtatAppli(
        stockage: FauxStockage(donnees()),
        voix: FauxVoix(),
        horloge: FausseHorloge(),
        jsonExemples: '{}',
      );
      await etat.init();
      expect(etat.session.grilleCourante.id, 'acc');
      expect(etat.session.barre, isEmpty);
      expect(etat.verrouille, isTrue);
    });

    test('REQ025_AC3 sans donnée : exemples créés et enregistrés', () async {
      final st = FauxStockage();
      final etat = EtatAppli(
        stockage: st,
        voix: FauxVoix(),
        horloge: FausseHorloge(),
        jsonExemples:
            '{"versionFormat":1,"accueilId":"x","grilles":[{"id":"x",'
            '"nom":"X","lignes":2,"colonnes":2,"cases":[]}],'
            '"reglages":{"voixId":null,"debit":1.0,"hauteur":1.0,"volume":1.0,'
            '"delaiAntiRepetitionMs":0,"retourAccueilApresMot":false}}',
      );
      await etat.init();
      expect(etat.session.grilleCourante.id, 'x');
      expect(st.ecritures, 1);
    });

    test(
      'REQ025_AC1 modifierDonnees persiste et met la session à jour',
      () async {
        final st = FauxStockage(donnees());
        final etat = EtatAppli(
          stockage: st,
          voix: FauxVoix(),
          horloge: FausseHorloge(),
          jsonExemples: '{}',
        );
        await etat.init();
        final d = etat.session.donnees;
        final nouveau = d.copyWith(
          reglages: d.reglages.copyWith(retourAccueilApresMot: true),
        );
        await etat.modifierDonnees(nouveau);
        expect(st.donnees, same(nouveau));
        expect(etat.session.donnees, same(nouveau));
      },
    );

    test('REQ025_AC1 modifierDonnees refuse un accueil introuvable', () async {
      final st = FauxStockage(donnees());
      final etat = EtatAppli(
        stockage: st,
        voix: FauxVoix(),
        horloge: FausseHorloge(),
        jsonExemples: '{}',
      );
      await etat.init();
      final avant = st.ecritures;
      expect(
        () => etat.modifierDonnees(Donnees(accueilId: 'nulle part')),
        throwsArgumentError,
      );
      expect(st.ecritures, avant);
      expect(etat.session.grilleCourante.id, 'acc');
    });
  });

  group('Écran de communication', () {
    testWidgets('REQ032_AC2 le fond d\'une case est celui de sa catégorie', (
      tester,
    ) async {
      await lance(tester);
      Color fond(String id) => tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(Key('case-$id')),
              matching: find.byType(Material),
            ),
          )
          .color!;
      expect(fond('eau'), GlypheTokens.clair.catDescribeBg);
      expect(fond('je'), GlypheTokens.clair.catLittleBg);
    });

    testWidgets('REQ002_AC1 appui sur eau : parlé et ajouté à la barre', (
      tester,
    ) async {
      final e = await lance(tester);
      await tester.tap(grille('eau'));
      await tester.pumpAndSettle();
      expect(e.voix.textesPrononces, ['eau']);
      expect(dansBarre(find.text('eau')), findsOneWidget);
    });

    testWidgets('REQ002_AC3 WC : dit la phrase, affiche WC', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('WC'));
      await tester.pumpAndSettle();
      expect(e.voix.textesPrononces, ['je veux aller aux toilettes']);
      expect(dansBarre(find.text('WC')), findsOneWidget);
    });

    testWidgets('REQ008_AC1 dossier : navigation sans parole ni barre', (
      tester,
    ) async {
      final e = await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      expect(grille('pomme'), findsOneWidget);
      expect(grille('eau'), findsNothing);
      expect(e.voix.journal, isEmpty);
      expect(e.etat.session.barre, isEmpty);
    });

    testWidgets('REQ008_AC2 dossier orphelin inactif', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('Perdu'));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      expect(e.voix.journal, isEmpty);
      expect(e.etat.session.barre, isEmpty);
    });

    testWidgets('REQ008_AC4 dossier a un coin replié, pas un mot', (
      tester,
    ) async {
      await lance(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('case-d-manger')),
          matching: find.byKey(const Key('coin-dossier')),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.folder), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('case-eau')),
          matching: find.byKey(const Key('coin-dossier')),
        ),
        findsNothing,
      );
    });

    testWidgets('REQ033_AC4 Tab : cases de la ligne 0 de gauche à droite', (
      tester,
    ) async {
      await lance(tester);
      final anneau = find.byKey(const Key('anneau-focus'));
      // Les commandes de l'écran précèdent la grille dans l'ordre de focus.
      final surJe = find.descendant(
        of: find.byKey(const Key('case-je')),
        matching: anneau,
      );
      var essais = 0;
      while (surJe.evaluate().isEmpty && essais++ < 30) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      for (final id in ['je', 'veux', 'manger', 'eau', 'wc']) {
        expect(anneau, findsOneWidget, reason: id);
        expect(
          find.descendant(of: find.byKey(Key('case-$id')), matching: anneau),
          findsOneWidget,
          reason: id,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
    });

    testWidgets('REQ033_AC5 emplacement libre : rien en communication', (
      tester,
    ) async {
      await lance(tester);
      expect(find.byKey(const Key('vide-0-0')), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('REQ033_AC5 emplacement libre en édition : contour, « + »', (
      tester,
    ) async {
      final e = await lance(tester);
      e.etat.ouvrirEdition();
      await tester.pumpAndSettle();
      final vide = find.byKey(const Key('vide-1-3'));
      expect(vide, findsOneWidget);
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: vide,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect((deco.border! as Border).top.color, GlypheTokens.clair.border);
      expect(deco.borderRadius, BorderRadius.circular(14));
      final icone = tester.widget<Icon>(
        find.descendant(of: vide, matching: find.byIcon(Icons.add)),
      );
      expect(icone.color, GlypheTokens.clair.ink);
      expect(find.bySemanticsLabel('Ajouter une case'), findsWidgets);
    });

    testWidgets('REQ009_AC1 Retour remonte pas à pas', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      expect(grille('poire'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(grille('pomme'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      expect(e.etat.session.barre, isEmpty);
    });

    testWidgets('REQ009_AC2 Accueil depuis une sous-grille', (tester) async {
      await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onglet-acc')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
    });

    testWidgets('REQ009_AC3 Retour à l\'accueil sans effet', (tester) async {
      await lance(tester);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
    });

    testWidgets('REQ009_AC1 retour système = Retour dans une sous-grille', (
      tester,
    ) async {
      await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
    });

    testWidgets('REQ006_AC1 appui sur la barre lit la phrase', (tester) async {
      final e = await lance(tester);
      for (final l in ['je', 'veux', 'manger']) {
        await tester.tap(grille(l));
      }
      await tester.pumpAndSettle();
      e.voix.journal.clear();
      await tester.tap(find.byKey(const Key('zone-barre')));
      await tester.pumpAndSettle();
      expect(e.voix.textesPrononces, ['je veux manger']);
      expect(e.etat.session.barre, hasLength(3));
    });

    testWidgets('REQ006_AC1 bouton Parler', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('je'));
      await tester.tap(grille('veux'));
      await tester.pumpAndSettle();
      e.voix.journal.clear();
      await tester.tap(find.byKey(const Key('bouton-parler')));
      await tester.pumpAndSettle();
      expect(e.voix.textesPrononces, ['je veux']);
    });

    testWidgets('REQ006_AC3 barre vide : rien n\'est prononcé', (tester) async {
      final e = await lance(tester);
      await tester.tap(find.byKey(const Key('bouton-parler')));
      await tester.tap(find.byKey(const Key('zone-barre')));
      await tester.pumpAndSettle();
      expect(e.voix.journal, isEmpty);
    });

    testWidgets('REQ006_AC4 la barre défile jusqu\'au dernier élément', (
      tester,
    ) async {
      await lance(tester);
      for (var i = 0; i < 30; i++) {
        await tester.tap(grille('eau'));
      }
      await tester.pumpAndSettle();
      final zone = tester.getRect(find.byKey(const Key('zone-barre')));
      final dernier = tester.getRect(find.byKey(const Key('element-barre-29')));
      expect(dernier.right, lessThanOrEqualTo(zone.right + 0.5));
      expect(dernier.left, greaterThanOrEqualTo(zone.left));
      final defilement = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('zone-barre')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(defilement.position.pixels, defilement.position.maxScrollExtent);
    });

    testWidgets('REQ034_AC4 Arrêter : stop émis, retour à Parler', (
      tester,
    ) async {
      final e = await lance(tester);
      e.voix.parolePilotee = true;
      await tester.tap(grille('je'));
      await tester.pump();
      e.voix.terminerParole();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-parler')));
      await tester.pump();
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      e.voix.journal.clear();
      await tester.tap(find.byKey(const Key('bouton-parler')));
      await tester.pump();
      expect(e.voix.journal, ['stop']);
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      e.voix.terminerParole();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'REQ034_AC4 retour à Parler à la fin et à l\'appui d\'une case',
      (tester) async {
        final e = await lance(tester);
        e.voix.parolePilotee = true;
        await tester.tap(grille('je'));
        await tester.pump();
        e.voix.terminerParole();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bouton-parler')));
        await tester.pump();
        expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
        e.voix.terminerParole();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
        await tester.tap(find.byKey(const Key('bouton-parler')));
        await tester.pump();
        expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
        await tester.tap(grille('veux'));
        await tester.pump();
        expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
        e.voix.terminerParole();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('REQ007_AC1 effacer le dernier', (tester) async {
      final e = await lance(tester);
      for (final l in ['je', 'veux', 'manger']) {
        await tester.tap(grille(l));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-effacer')));
      await tester.pumpAndSettle();
      expect([for (final x in e.etat.session.barre) x.libelle], ['je', 'veux']);
      expect(dansBarre(find.text('manger')), findsNothing);
    });

    testWidgets('REQ007_AC2 tout effacer, AC3 sur barre vide', (tester) async {
      final e = await lance(tester);
      await tester.longPress(find.byKey(const Key('bouton-effacer')));
      await tester.tap(find.byKey(const Key('bouton-effacer')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(grille('je'));
      await tester.tap(grille('veux'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('bouton-effacer')));
      await tester.pumpAndSettle();
      expect(e.etat.session.barre, isEmpty);
    });

    testWidgets('REQ028_AC4 libellés d\'accessibilité des cases', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await lance(tester);
      expect(find.bySemanticsLabel('dossier Manger'), findsOneWidget);
      expect(find.bySemanticsLabel('eau'), findsWidgets);
      h.dispose();
    });

    testWidgets('REQ028_AC1 barre de phrase large en communication 640x360', (
      tester,
    ) async {
      await lance(tester, taille: const Size(640, 360));
      // 640 - marges - 6 commandes de 56 dp : au moins ~280 dp.
      expect(
        tester.getSize(find.byType(BarrePhrase)).width,
        greaterThanOrEqualTo(280),
      );
    });

    for (final taille in const [
      Size(360, 640),
      Size(640, 360),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      testWidgets('REQ028_AC1/AC2/AC4 guidelines d\'accessibilité $taille', (
        tester,
      ) async {
        final h = tester.ensureSemantics();
        await lance(tester, taille: taille);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }

    testWidgets(
      'REQ028_AC1 Effacer et Parler >= 56 dp, autres contrôles >= 48',
      (tester) async {
        await lance(tester);
        for (final f in [
          find.byKey(const Key('bouton-parler')),
          find.byKey(const Key('bouton-effacer')),
        ]) {
          final r = tester.getSize(f);
          expect(r.width, greaterThanOrEqualTo(56), reason: '$f');
          expect(r.height, greaterThanOrEqualTo(56), reason: '$f');
        }
        for (final f in [
          find.byKey(const Key('bouton-retour')),
          find.byKey(const Key('onglet-acc')),
          find.byKey(const Key('onglet-manger-g')),
          find.byKey(const Key('cadenas')),
        ]) {
          final r = tester.getSize(f);
          expect(r.width, greaterThanOrEqualTo(48), reason: '$f');
          expect(r.height, greaterThanOrEqualTo(48), reason: '$f');
        }
      },
    );

    for (final taille in const [
      Size(360, 640),
      Size(640, 360),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      testWidgets('REQ028_AC3 grille 4x4 sans débordement en $taille', (
        tester,
      ) async {
        await lance(tester, taille: taille);
        expect(tester.takeException(), isNull);
        final zone = tester.getRect(find.byKey(const Key('grille')));
        for (final l in ['je', 'golf', 'hotel', 'alpha']) {
          final r = tester.getRect(grille(l));
          expect(zone.contains(r.topLeft), isTrue, reason: l);
          expect(zone.contains(r.bottomRight), isTrue, reason: l);
        }
        // La grille ne défile pas (AC-030-2).
        expect(
          find.descendant(
            of: find.byKey(const Key('grille')),
            matching: find.byType(Scrollable),
          ),
          findsNothing,
        );
        final cible = tester.getSize(
          find.descendant(
            of: find.byKey(const Key('case-h')),
            matching: find.byType(InkWell),
          ),
        );
        expect(cible.width, greaterThanOrEqualTo(48));
        expect(cible.height, greaterThanOrEqualTo(48));
      });
    }
  });

  group('Disposition (REQ-030, REQ-031, REQ-009)', () {
    Future<Env> exemples(WidgetTester tester, {Size? taille}) => lance(
      tester,
      taille: taille ?? const Size(360, 640),
      d: donneesDepuisJson(
        jsonDecode(
          File('assets/exemples/grilles_exemple.json').readAsStringSync(),
        ),
      ),
    );

    // Couleur du contour de l'onglet : `primary` quand il est actif.
    Color? contourOnglet(WidgetTester tester, String id) =>
        ((tester.widget<Material>(find.byKey(Key('onglet-$id'))).shape!)
                as OutlinedBorder)
            .side
            .color;

    testWidgets('REQ031_AC1/AC2 onglets des grilles d\'exemple', (
      tester,
    ) async {
      await exemples(tester, taille: const Size(1280, 800));
      for (final id in ['accueil', 'besoins', 'emotions', 'manger', 'jouer']) {
        expect(find.byKey(Key('onglet-$id')), findsOneWidget, reason: id);
      }
      expect(find.byKey(const Key('onglet-fruits')), findsNothing);
      final x = [
        for (final id in ['accueil', 'besoins', 'emotions', 'manger', 'jouer'])
          tester.getTopLeft(find.byKey(Key('onglet-$id'))).dx,
      ];
      expect(x, [...x]..sort());
      expect(
        find.descendant(
          of: find.byKey(const Key('onglet-accueil')),
          matching: find.byIcon(Icons.home_outlined),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const Key('onglet-manger'))),
        Size(48, 48),
      );
    });

    testWidgets('REQ031_AC1 les onglets défilent horizontalement', (
      tester,
    ) async {
      await exemples(tester);
      final liste = find.byKey(const Key('onglets'));
      expect(liste, findsOneWidget);
      final etat = tester.state<ScrollableState>(
        find.descendant(of: liste, matching: find.byType(Scrollable)),
      );
      expect(etat.position.maxScrollExtent, greaterThan(0));
      expect(etat.position.axis, Axis.horizontal);
    });

    testWidgets('REQ031_AC4 Fruits : l\'onglet Manger est actif', (
      tester,
    ) async {
      final e = await exemples(tester, taille: const Size(1280, 800));
      final t = GlypheTokens.clair;
      expect(contourOnglet(tester, 'accueil'), t.primary);
      expect(contourOnglet(tester, 'manger'), t.border);
      e.etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'fruits');
      expect(contourOnglet(tester, 'manger'), t.primary);
      expect(contourOnglet(tester, 'accueil'), t.border);
    });

    testWidgets('REQ031_AC4 onglet actif exposé comme sélectionné', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      await exemples(tester, taille: const Size(1280, 800));
      expect(
        tester.getSemantics(find.byKey(const Key('onglet-accueil'))),
        isSemantics(label: 'Accueil', isSelected: true, isButton: true),
      );
      h.dispose();
    });

    testWidgets('REQ031_AC3 appui sur un onglet : rien dit, barre intacte', (
      tester,
    ) async {
      final e = await exemples(tester, taille: const Size(1280, 800));
      await tester.tap(grille('je'));
      await tester.pumpAndSettle();
      final avant = [for (final x in e.etat.session.barre) x.libelle];
      expect(avant, isNotEmpty);
      final dits = e.voix.journal.length;
      e.etat.session.ouvrirGrille('fruits');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onglet-manger')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'manger');
      expect(e.etat.session.chemin, ['accueil', 'manger']);
      expect(e.voix.journal.length, dits);
      expect([for (final x in e.etat.session.barre) x.libelle], avant);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'accueil');
      await tester.tap(find.byKey(const Key('onglet-jouer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onglet-accueil')));
      await tester.pumpAndSettle();
      expect(e.etat.session.chemin, ['accueil']);
    });

    testWidgets('REQ031_AC6 supprimer la grille Jouer retire son onglet', (
      tester,
    ) async {
      final e = await exemples(tester, taille: const Size(1280, 800));
      final d = e.etat.session.donnees;
      await e.etat.modifierDonnees(
        d.copyWith(
          grilles: [
            for (final g in d.grilles)
              if (g.id != 'jouer') g,
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onglet-jouer')), findsNothing);
      expect(find.byKey(const Key('onglet-manger')), findsOneWidget);
    });

    testWidgets('REQ009_AC5 Retour atténué et sans effet sur l\'accueil', (
      tester,
    ) async {
      final e = await lance(tester);
      double opacite() => tester
          .widget<Opacity>(find.byKey(const Key('bouton-retour')))
          .opacity;
      expect(opacite(), 0.4);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'acc');
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      expect(opacite(), 1);
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'acc');
    });

    testWidgets('REQ009_AC5 case-dossier vers l\'accueil : Retour atténué', (
      tester,
    ) async {
      final base = donnees();
      final d = base.copyWith(
        grilles: [
          for (final g in base.grilles)
            if (g.id == 'manger-g')
              Grille(
                id: g.id,
                nom: g.nom,
                lignes: g.lignes,
                colonnes: g.colonnes,
                cases: [...g.cases, dossier('d-maison', 'Maison', 1, 0, 'acc')],
              )
            else
              g,
        ],
      );
      final h = tester.ensureSemantics();
      final e = await lance(tester, d: d);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Maison'));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'acc');
      expect(
        tester.widget<Opacity>(find.byKey(const Key('bouton-retour'))).opacity,
        0.4,
      );
      await tester.tap(find.byKey(const Key('bouton-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'acc');
      expect(
        tester.getSemantics(find.byKey(const Key('onglet-acc'))),
        isSemantics(label: 'Accueil', isSelected: true, isButton: true),
      );
      h.dispose();
    });

    testWidgets('REQ009_AC5 plus de bouton Accueil séparé', (tester) async {
      await lance(tester);
      expect(find.byTooltip('Accueil'), findsNothing);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget); // dans l'onglet
    });

    testWidgets('REQ030_AC1 portrait : barre 72, navigation 56, marges', (
      tester,
    ) async {
      await lance(tester);
      final barre = tester.getRect(find.byType(BarrePhrase));
      final nav = tester.getRect(find.byType(BarreNavigation));
      final zone = tester.getRect(find.byKey(const Key('grille')));
      expect(barre.height, 72);
      expect(nav.height, 56);
      expect(barre.left, 12);
      expect(barre.right, 360 - 12);
      expect(nav.left, 12);
      expect(nav.right, 360 - 12);
      expect(nav.top - barre.bottom, 8);
      // La zone de grille inclut 4 de marge propre à chaque case.
      expect(zone.top + 4 - nav.bottom, 8);
      // Rectangle visible d'une case : sans sa marge propre de 3.
      Rect visible(String id) =>
          tester.getRect(find.byKey(Key('case-$id'))).deflate(3);
      final a = visible('je');
      final b = visible('veux');
      final c = visible('wc');
      expect(a.left, 12);
      expect(b.left - a.right, 8);
      expect(c.top - a.bottom, 8);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isNull,
      );
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        GlypheTokens.clair.surface100,
      );
    });

    testWidgets('REQ030_AC2 la grille remplit sans défiler (1x1 et 8x8)', (
      tester,
    ) async {
      for (final n in [1, 8]) {
        final d = Donnees(
          accueilId: 'g',
          grilles: [
            Grille(
              id: 'g',
              nom: 'G',
              lignes: n,
              colonnes: n,
              cases: [mot('m', 'm', 0, 0)],
            ),
          ],
        );
        await lance(tester, d: d);
        final zone = tester.getRect(find.byKey(const Key('grille')));
        final cm = tester.getRect(find.byKey(const Key('case-m')));
        expect(tester.takeException(), isNull);
        expect(cm.width, closeTo((zone.width / n) - 2, 0.01));
        expect(zone.bottom, closeTo(640 - 12 + 4, 0.01));
        expect(find.byKey(const Key('vide-0-1')), findsNothing);
      }
    });

    testWidgets('REQ030_AC3 paysage peu haut : une seule rangée de 72', (
      tester,
    ) async {
      await lance(tester, taille: const Size(640, 360));
      final barre = tester.getRect(find.byType(BarrePhrase));
      final nav = tester.getRect(find.byType(BarreNavigation));
      expect(barre.height, 72);
      expect(nav.height, 56);
      expect(barre.left, 12);
      expect(nav.right, 640 - 12);
      expect(nav.left, greaterThan(barre.right));
      expect(barre.center.dy, closeTo(nav.center.dy, 0.01));
      final total = 640 - 24 - 8;
      expect(barre.width / total, closeTo(0.55, 0.01));
      final zone = tester.getRect(find.byKey(const Key('grille')));
      expect(zone.top + 4, 8 + 72 + 8);
    });

    testWidgets('REQ030_AC3 paysage haut (>= 480) : deux rangées', (
      tester,
    ) async {
      await lance(tester, taille: const Size(1280, 800));
      final barre = tester.getRect(find.byType(BarrePhrase));
      final nav = tester.getRect(find.byType(BarreNavigation));
      expect(nav.top, greaterThan(barre.bottom));
    });

    for (final edition in [false, true]) {
      testWidgets('REQ030_AC4 barre d\'édition à la place de la barre de '
          'phrase (édition: $edition)', (tester) async {
        final e = await lance(tester);
        final barre = tester.getRect(find.byType(BarrePhrase));
        if (edition) {
          e.etat.ouvrirEdition();
          await tester.pumpAndSettle();
          expect(find.byType(BarrePhrase), findsNothing);
          expect(tester.getRect(find.byType(BarreEdition)), barre);
          expect(find.byKey(const Key('cadenas')), findsNothing);
          expect(find.byKey(const Key('espace-cadenas')), findsOneWidget);
          expect(find.byKey(const Key('onglet-acc')), findsOneWidget);
          for (final f in [
            find.widgetWithText(FilledButton, 'Terminer'),
            find.byKey(const Key('ajouter-case')),
            find.byKey(const Key('bouton-plus')),
          ]) {
            expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
          }
          await tester.tap(find.byKey(const Key('bouton-plus')));
          await tester.pumpAndSettle();
          for (final k in [
            'bouton-code',
            'bouton-grilles',
            'bouton-taille',
            'bouton-reglages',
            'bouton-a-propos',
          ]) {
            expect(find.byKey(Key(k)), findsOneWidget, reason: k);
          }
        } else {
          expect(find.byType(BarreEdition), findsNothing);
          expect(find.byKey(const Key('cadenas')), findsOneWidget);
        }
      });
    }

    for (final taille in const [
      Size(360, 640),
      Size(412, 915),
      Size(640, 360),
      Size(915, 412),
      Size(800, 1280),
      Size(1280, 800),
    ]) {
      testWidgets('REQ030_AC5 mêmes rectangles de cases en communication et '
          'en édition $taille', (tester) async {
        final e = await lance(tester, taille: taille);
        final ids = ['je', 'veux', 'g', 'h'];
        final avant = [
          for (final i in ids) tester.getRect(find.byKey(Key('case-$i'))),
        ];
        e.etat.ouvrirEdition();
        await tester.pumpAndSettle();
        final apres = [
          for (final i in ids) tester.getRect(find.byKey(Key('case-$i'))),
        ];
        expect(apres, avant);
      });

      testWidgets('REQ028_AC3 cases >= 48 et lisibles en $taille', (
        tester,
      ) async {
        await lance(tester, taille: taille);
        expect(tester.takeException(), isNull);
        final r = tester.getRect(find.byKey(const Key('case-h')));
        expect(r.width, greaterThanOrEqualTo(48));
        expect(r.height, greaterThanOrEqualTo(48));
        if (taille == const Size(412, 915)) {
          expect(r.width, greaterThanOrEqualTo(80));
        }
      });
    }

    testWidgets('REQ030_AC6 aucun autre contrôle en communication', (
      tester,
    ) async {
      await lance(tester);
      expect(find.byKey(const Key('bouton-a-propos')), findsNothing);
      expect(find.text('À propos'), findsNothing);
      expect(find.text('Terminer'), findsNothing);
      expect(find.byKey(const Key('bouton-plus')), findsNothing);
    });

    testWidgets('REQ035_AC4 échelle de texte 2 : libellé de case en 17', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await lance(tester, taille: const Size(412, 915));
      final texte = tester.widget<Text>(grille('je'));
      expect(texte.style!.fontSize, 17);
      expect(
        MediaQuery.of(tester.element(find.byType(BarrePhrase))).textScaler,
        TextScaler.noScaling,
      );
    });
  });
}
