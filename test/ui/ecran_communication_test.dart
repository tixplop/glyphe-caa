import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/theme.dart';
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
  int? couleur,
}) => Case(
  id: id,
  ligne: l,
  colonne: c,
  type: TypeCase.mot,
  libelle: lib,
  textePrononce: texte,
  image: ImageArasaac(2617),
  couleur: couleur,
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
        mot('eau', 'eau', 0, 3, couleur: 0xFFBBDEFB),
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

  group('Thème', () {
    double lum(Color c) {
      double f(double v) =>
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    test('REQ028_AC2 palette de 8 couleurs, contraste >= 4,5 avec le noir', () {
      expect(PaletteCases.couleurs, hasLength(8));
      for (final c in PaletteCases.couleurs) {
        expect((lum(c) + 0.05) / 0.05, greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });
  });

  group('Écran de communication', () {
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

    testWidgets('REQ008_AC4 dossier a une icône dossier, pas un mot', (
      tester,
    ) async {
      await lance(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('case-d-manger')),
          matching: find.byIcon(Icons.folder),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('case-eau')),
          matching: find.byIcon(Icons.folder),
        ),
        findsNothing,
      );
    });

    testWidgets('REQ009_AC1 Retour remonte pas à pas', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('Manger'));
      await tester.pumpAndSettle();
      await tester.tap(grille('Fruits'));
      await tester.pumpAndSettle();
      expect(grille('poire'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(grille('pomme'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
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
      await tester.tap(find.byTooltip('Accueil'));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(grille('eau'), findsOneWidget);
    });

    testWidgets('REQ009_AC3 Retour à l\'accueil sans effet', (tester) async {
      await lance(tester);
      await tester.tap(find.byTooltip('Retour'));
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

    testWidgets('REQ006_AC1 bouton Lire', (tester) async {
      final e = await lance(tester);
      await tester.tap(grille('je'));
      await tester.tap(grille('veux'));
      await tester.pumpAndSettle();
      e.voix.journal.clear();
      await tester.tap(find.byTooltip('Lire'));
      await tester.pumpAndSettle();
      expect(e.voix.textesPrononces, ['je veux']);
    });

    testWidgets('REQ006_AC3 barre vide : rien n\'est prononcé', (tester) async {
      final e = await lance(tester);
      await tester.tap(find.byTooltip('Lire'));
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
    });

    testWidgets('REQ007_AC1 effacer le dernier', (tester) async {
      final e = await lance(tester);
      for (final l in ['je', 'veux', 'manger']) {
        await tester.tap(grille(l));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Effacer le dernier'));
      await tester.pumpAndSettle();
      expect([for (final x in e.etat.session.barre) x.libelle], ['je', 'veux']);
      expect(dansBarre(find.text('manger')), findsNothing);
    });

    testWidgets('REQ007_AC2 tout effacer, AC3 sur barre vide', (tester) async {
      final e = await lance(tester);
      await tester.tap(find.byTooltip('Tout effacer'));
      await tester.tap(find.byTooltip('Effacer le dernier'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(grille('je'));
      await tester.tap(grille('veux'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tout effacer'));
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

    testWidgets('REQ028_AC1 boutons de barre et de navigation >= 56 dp', (
      tester,
    ) async {
      await lance(tester);
      for (final t in [
        'Lire',
        'Effacer le dernier',
        'Tout effacer',
        'Retour',
        'Accueil',
      ]) {
        final r = tester.getSize(find.byTooltip(t));
        expect(r.width, greaterThanOrEqualTo(56), reason: t);
        expect(r.height, greaterThanOrEqualTo(56), reason: t);
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
        expect(find.byType(Scrollable), findsOneWidget); // la barre seule
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
}
