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
import 'package:glyphe/ui/widgets/barre_phrase.dart';
import 'package:glyphe/ui/widgets/bouton_barre.dart';
import 'package:glyphe/ui/widgets/case_widget.dart';

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

    testWidgets('REQ009_AC1 retour système remonte pas à pas', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      expect(grille('poire'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(grille('pomme'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      expect(e.etat.session.barre, isEmpty);
    });

    testWidgets('REQ009_AC2 Accueil depuis une sous-grille', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-accueil')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      expect(e.etat.session.chemin, ['acc']);
      expect(e.voix.journal, isEmpty);
    });

    testWidgets('REQ009_AC2 AC8 Accueil sur l\'accueil : rien ne change', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final e = await lance(tester);
      await tester.tap(grille('je'));
      await tester.pumpAndSettle();
      e.voix.journal.clear();
      await tester.tap(find.byKey(const Key('bouton-accueil')));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      expect(e.etat.session.chemin, ['acc']);
      expect([for (final x in e.etat.session.barre) x.libelle], ['je']);
      expect(e.voix.journal, isEmpty);
      expect(
        tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: find.byKey(const Key('bouton-accueil')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('bouton-accueil')))
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name,
        isNot('isFalse'),
      );
      h.dispose();
    });

    testWidgets('REQ009_AC4 Accueil ne modifie pas la barre', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('je'));
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-accueil')));
      await tester.pumpAndSettle();
      expect([for (final x in e.etat.session.barre) x.libelle], ['je']);
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

    testWidgets('REQ006_AC3 barre vide : rien n\'est prononcé', (tester) async {
      final e = await lance(tester);
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
      // Le dernier élément est au bout de la zone (marge interne de 9).
      expect(dernier.right, greaterThanOrEqualTo(zone.right - 9 - 0.5));
      final defilement = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('zone-barre')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(defilement.position.pixels, defilement.position.maxScrollExtent);
    });

    Color couleurCadre(WidgetTester tester) =>
        ((tester
                    .widget<DecoratedBox>(
                      find.byKey(const Key('cadre-lecture')),
                    )
                    .decoration)
                as BoxDecoration)
            .border!
            .top
            .color;

    testWidgets('REQ034_AC4 appui pendant la lecture : stop, sans relire', (
      tester,
    ) async {
      final e = await lance(tester);
      e.voix.parolePilotee = true;
      await tester.tap(grille('je'));
      await tester.pump();
      e.voix.terminerParole();
      await tester.pumpAndSettle();
      expect(couleurCadre(tester), Colors.transparent);
      await tester.tap(find.byKey(const Key('zone-barre')));
      await tester.pump();
      expect(couleurCadre(tester), GlypheTokens.clair.primary);
      e.voix.journal.clear();
      await tester.tap(find.byKey(const Key('zone-barre')));
      await tester.pump();
      expect(e.voix.journal, ['stop']);
      expect(couleurCadre(tester), Colors.transparent);
      e.voix.terminerParole();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'REQ034_AC4 fin de lecture et appui d\'une case : cadre transparent',
      (tester) async {
        final e = await lance(tester);
        e.voix.parolePilotee = true;
        await tester.tap(grille('je'));
        await tester.pump();
        e.voix.terminerParole();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('zone-barre')));
        await tester.pump();
        expect(couleurCadre(tester), GlypheTokens.clair.primary);
        e.voix.terminerParole();
        await tester.pumpAndSettle();
        expect(couleurCadre(tester), Colors.transparent);
        await tester.tap(find.byKey(const Key('zone-barre')));
        await tester.pump();
        expect(couleurCadre(tester), GlypheTokens.clair.primary);
        await tester.tap(grille('veux'));
        await tester.pump();
        expect(couleurCadre(tester), Colors.transparent);
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

    testWidgets('REQ007_AC2 Corbeille, AC3 sur barre vide', (tester) async {
      final e = await lance(tester);
      await tester.tap(find.byKey(const Key('bouton-corbeille')));
      await tester.tap(find.byKey(const Key('bouton-effacer')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(grille('je'));
      await tester.tap(grille('veux'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bouton-corbeille')));
      await tester.pumpAndSettle();
      expect(e.etat.session.barre, isEmpty);
      expect(find.text('Ta phrase apparaît ici'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('REQ007_AC4 appui maintenu 1 s sur Effacer : un mot retiré', (
      tester,
    ) async {
      final e = await lance(tester);
      for (final l in ['je', 'veux', 'manger']) {
        await tester.tap(grille(l));
      }
      await tester.pumpAndSettle();
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('bouton-effacer'))),
      );
      await tester.pump(const Duration(seconds: 1));
      await g.up();
      await tester.pumpAndSettle();
      expect([for (final x in e.etat.session.barre) x.libelle], ['je', 'veux']);
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

    testWidgets('REQ028_AC1 boutons de la barre de phrase >= 48 dp', (
      tester,
    ) async {
      await lance(tester);
      for (final f in [
        find.byKey(const Key('bouton-accueil')),
        find.byKey(const Key('bouton-corbeille')),
        find.byKey(const Key('bouton-effacer')),
        find.byKey(const Key('cadenas')),
      ]) {
        final r = tester.getSize(f);
        expect(r.width, greaterThanOrEqualTo(48), reason: '$f');
        expect(r.height, greaterThanOrEqualTo(48), reason: '$f');
      }
    });

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

  group('Disposition (REQ-030, REQ-034, REQ-009)', () {
    Future<Env> exemples(WidgetTester tester, {Size? taille}) => lance(
      tester,
      taille: taille ?? const Size(360, 640),
      d: donneesDepuisJson(
        jsonDecode(
          File('assets/exemples/grilles_exemple.json').readAsStringSync(),
        ),
      ),
    );

    testWidgets('REQ009_AC1 cases-retour des grilles d\'exemple', (
      tester,
    ) async {
      final e = await exemples(tester);
      e.etat.session.ouvrirGrille('fruits');
      await tester.pumpAndSettle();
      expect(e.etat.session.chemin, ['accueil', 'fruits']);
      await tester.tap(find.byKey(const Key('case-fruits-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'accueil');
      e.etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('case-manger-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'accueil');
      expect(e.etat.session.barre, isEmpty);
    });

    for (final g in ['besoins', 'emotions', 'manger', 'fruits', 'jouer']) {
      testWidgets('REQ001_AC8 $g : case-retour en (0, 0)', (tester) async {
        final h = tester.ensureSemantics();
        final e = await exemples(tester);
        e.etat.session.ouvrirGrille(g);
        await tester.pumpAndSettle();
        final c = e.etat.session.grilleCourante.cases.firstWhere(
          (c) => c.ligne == 0 && c.colonne == 0,
        );
        expect(c.type, TypeCase.retour);
        final k = find.byKey(Key('case-${c.id}'));
        expect(
          find.descendant(
            of: k,
            matching: find.byKey(const Key('fleche-retour')),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: k,
            matching: find.byKey(const Key('coin-dossier')),
          ),
          findsNothing,
        );
        final fleche = tester.widget<Icon>(
          find.byKey(const Key('fleche-retour')),
        );
        expect(fleche.icon, Icons.arrow_back);
        expect(fleche.color, GlypheTokens.clair.ink);
        final m = tester.widget<Material>(
          find.descendant(of: k, matching: find.byType(Material)).first,
        );
        final forme = m.shape! as RoundedRectangleBorder;
        expect(m.color, GlypheTokens.clair.catLittleBg);
        expect(forme.side.color, GlypheTokens.clair.catLittleEdge);
        expect(find.bySemanticsLabel('Retour'), findsOneWidget);
        h.dispose();
      });
    }

    testWidgets('REQ037_AC2 appui sur la case-retour : accueil, rien dit', (
      tester,
    ) async {
      final e = await exemples(tester);
      await tester.tap(find.byKey(const Key('case-accueil-0')));
      await tester.pumpAndSettle();
      e.etat.session.ouvrirGrille('manger');
      await tester.pumpAndSettle();
      final avant = e.etat.session.barre.length;
      final dits = e.voix.textesPrononces.length;
      await tester.tap(find.byKey(const Key('case-manger-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'accueil');
      expect(e.etat.session.barre.length, avant);
      expect(e.voix.textesPrononces.length, dits);
    });

    testWidgets('REQ037_AC2 le réglage retour à l\'accueil ne joue pas', (
      tester,
    ) async {
      final d = donneesDepuisJson(
        jsonDecode(
          File('assets/exemples/grilles_exemple.json').readAsStringSync(),
        ),
      );
      final e = await lance(
        tester,
        d: d.copyWith(
          reglages: d.reglages.copyWith(retourAccueilApresMot: true),
        ),
      );
      for (final cible in ['manger', 'fruits']) {
        final s = e.etat.session;
        s.appuyerCase(
          s.grilleCourante.cases.firstWhere((c) => c.cibleId == cible),
        );
        await tester.pumpAndSettle();
      }
      expect(e.etat.session.grilleCourante.id, 'fruits');
      await tester.tap(find.byKey(const Key('case-fruits-retour')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'manger');
    });

    testWidgets('REQ037_AC3 case-retour sur l\'accueil : sans effet', (
      tester,
    ) async {
      final d = donnees();
      final acc = d.grilles.first;
      final e = await lance(
        tester,
        d: d.copyWith(
          grilles: [
            acc.copyWith(cases: [...acc.cases]),
            ...d.grilles.skip(1),
          ],
        ),
      );
      // Remplace « h » (3, 3) par une case-retour.
      final g = e.etat.session.donnees.grillePar('acc')!;
      await e.etat.modifierDonnees(
        e.etat.session.donnees.copyWith(
          grilles: [
            g.copyWith(
              cases: [
                for (final c in g.cases)
                  if (c.id == 'h')
                    const Case(
                      id: 'h',
                      ligne: 3,
                      colonne: 3,
                      type: TypeCase.retour,
                      libelle: 'Retour',
                    )
                  else
                    c,
              ],
            ),
            ...e.etat.session.donnees.grilles.skip(1),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('case-je')));
      await tester.tap(find.byKey(const Key('case-h')));
      await tester.pumpAndSettle();
      expect(e.etat.session.grilleCourante.id, 'acc');
      expect(e.etat.session.barre.length, 1);
    });

    group('focus après navigation (AC-009-9)', () {
      Future<void> focaliser(WidgetTester tester, String id) async {
        final scope = FocusScope.of(
          tester.element(find.byKey(Key('case-$id'))),
        );
        scope.traversalDescendants
            .firstWhere(
              (n) =>
                  n.context?.findAncestorWidgetOfExactType<CaseWidget>()?.key ==
                  Key('case-$id'),
            )
            .requestFocus();
        await tester.pump();
      }

      Key? surCase() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<CaseWidget>()
          ?.key;

      Key? surAccueil() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<BoutonBarre>()
          ?.key;

      Future<void> entree(WidgetTester tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }

      Future<void> naviguer(WidgetTester tester, Env e) async {
        for (final cible in ['manger', 'fruits']) {
          final s = e.etat.session;
          s.appuyerCase(
            s.grilleCourante.cases.firstWhere((c) => c.cibleId == cible),
          );
          await tester.pumpAndSettle();
        }
      }

      testWidgets('Fruits -> Manger -> accueil', (tester) async {
        final e = await exemples(tester);
        await naviguer(tester, e);
        expect(e.etat.session.grilleCourante.id, 'fruits');
        await focaliser(tester, 'fruits-retour');
        await entree(tester);
        expect(e.etat.session.grilleCourante.id, 'manger');
        expect(surCase(), const Key('case-manger-retour'));
        await entree(tester);
        expect(e.etat.session.grilleCourante.id, 'accueil');
        expect(surCase(), const Key('case-accueil-0'));
      });

      testWidgets('dossier : focus sur la première case de la cible', (
        tester,
      ) async {
        final e = await exemples(tester);
        e.etat.session.ouvrirGrille('manger');
        await tester.pumpAndSettle();
        final fruits = e.etat.session.grilleCourante.cases.firstWhere(
          (c) => c.type == TypeCase.dossier,
        );
        await focaliser(tester, fruits.id);
        await entree(tester);
        expect(e.etat.session.grilleCourante.id, 'fruits');
        expect(surCase(), const Key('case-fruits-retour'));
      });

      testWidgets('grille sans case : focus sur Accueil', (tester) async {
        final d = donnees();
        final vide = Grille(id: 'vide', nom: 'Vide', lignes: 2, colonnes: 2);
        final acc = d.grilles.first;
        final e = await lance(
          tester,
          d: d.copyWith(
            grilles: [
              acc.copyWith(
                cases: [
                  for (final c in acc.cases)
                    if (c.id == 'd-manger')
                      dossier('d-manger', 'Manger', 1, 1, 'vide')
                    else
                      c,
                ],
              ),
              ...d.grilles.skip(1),
              vide,
            ],
          ),
        );
        await focaliser(tester, 'd-manger');
        await entree(tester);
        expect(e.etat.session.grilleCourante.id, 'vide');
        expect(surAccueil(), const Key('bouton-accueil'));
      });

      testWidgets('Entrée sur Accueil : le focus reste sur Accueil', (
        tester,
      ) async {
        final e = await exemples(tester);
        e.etat.session.ouvrirGrille('fruits');
        await tester.pumpAndSettle();
        final ctx = tester.element(find.byKey(const Key('bouton-accueil')));
        FocusScope.of(ctx).traversalDescendants
            .firstWhere(
              (n) =>
                  n.context
                      ?.findAncestorWidgetOfExactType<BoutonBarre>()
                      ?.key ==
                  const Key('bouton-accueil'),
            )
            .requestFocus();
        await tester.pump();
        expect(surAccueil(), const Key('bouton-accueil'));
        await entree(tester);
        expect(e.etat.session.grilleCourante.id, 'accueil');
        expect(surAccueil(), const Key('bouton-accueil'));
      });

      testWidgets('sans focus sur une case : pas de déplacement', (
        tester,
      ) async {
        final e = await exemples(tester);
        await naviguer(tester, e);
        await tester.tap(find.byKey(const Key('case-fruits-retour')));
        await tester.pumpAndSettle();
        // Appui tactile : le focus n'est pas sur la case -> pas forcé.
        expect(e.etat.session.grilleCourante.id, 'manger');
        expect(surCase(), isNull);
      });
    });

    for (final taille in const [Size(360, 640), Size(640, 360)]) {
      testWidgets('REQ030_AC5 case-accueil-0 même rectangle dans les deux '
          'modes $taille', (tester) async {
        final e = await exemples(tester, taille: taille);
        final avant = tester.getRect(find.byKey(const Key('case-accueil-0')));
        e.etat.ouvrirEdition();
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(const Key('case-accueil-0'))), avant);
      });
    }

    testWidgets('REQ030_AC6 aucune navigation hors de la grille', (
      tester,
    ) async {
      await exemples(tester, taille: const Size(1280, 800));
      expect(find.byKey(const Key('bouton-retour')), findsNothing);
      expect(find.byKey(const Key('bouton-parler')), findsNothing);
      expect(find.byKey(const Key('onglets')), findsNothing);
      expect(find.byKey(const Key('onglet-accueil')), findsNothing);
      expect(find.byKey(const Key('onglet-manger')), findsNothing);
      expect(find.byKey(const Key('espace-cadenas')), findsNothing);
    });

    testWidgets('REQ030_AC1 AC12 portrait : barre 72, grille dessous', (
      tester,
    ) async {
      await lance(tester);
      final barre = tester.getRect(find.byType(BarrePhrase));
      final zone = tester.getRect(find.byKey(const Key('grille')));
      expect(barre.top, 8);
      expect(barre.height, 72);
      expect(barre.left, 12);
      expect(barre.right, 360 - 12);
      // La zone de grille inclut 4 de marge propre à chaque case.
      expect(zone.top + 4 - barre.bottom, 8);
      expect(tester.getSize(find.byKey(const Key('zone-barre'))).width, 112);
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

    for (final taille in const [Size(640, 360), Size(915, 412)]) {
      testWidgets('REQ030_AC12 paysage $taille : barre pleine largeur, grille '
          'entière dessous', (tester) async {
        await lance(tester, taille: taille);
        final barre = tester.getRect(find.byType(BarrePhrase));
        expect(barre.height, 72);
        expect(barre.left, 12);
        expect(barre.width, taille.width - 24);
        if (taille.width == 640) expect(barre.width, 616);
        final zone = tester.getRect(find.byKey(const Key('grille')));
        expect(zone.top + 4, barre.bottom + 8);
        expect(zone.bottom, taille.height - 12 + 4);
        expect(tester.takeException(), isNull);
        for (final id in ['je', 'h']) {
          final r = tester.getRect(find.byKey(Key('case-$id')));
          expect(r.top, greaterThanOrEqualTo(barre.bottom));
          expect(r.bottom, lessThanOrEqualTo(taille.height));
        }
      });
    }

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
          expect(find.byKey(const Key('bouton-accueil')), findsOneWidget);
          for (final f in [
            find.byKey(const Key('bouton-terminer')),
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
      expect(find.byKey(const Key('bouton-terminer')), findsNothing);
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
