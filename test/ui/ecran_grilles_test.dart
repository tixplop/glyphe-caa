import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';
import 'selecteur_image_test.dart' show io;

Donnees donnees({String? photo}) => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 4,
      colonnes: 4,
      cases: const [
        Case(
          id: 'd-man',
          ligne: 0,
          colonne: 0,
          type: TypeCase.dossier,
          libelle: 'Manger',
          cibleId: 'man',
        ),
      ],
    ),
    Grille(
      id: 'man',
      nom: 'Manger',
      lignes: 4,
      colonnes: 4,
      cases: [
        for (var l = 0; l < 4; l++)
          for (var c = 0; c < 4; c++)
            Case(
              id: 'm$l$c',
              ligne: l,
              colonne: c,
              type: TypeCase.mot,
              libelle: 'm$l$c',
              image: (l == 3 && c == 3 && photo != null)
                  ? ImagePhoto(photo)
                  : const ImageAucune(),
            ),
      ],
    ),
  ],
);

class Env {
  Env(this.etat, this.stockage, this.dossier);
  final EtatAppli etat;
  final FauxStockage stockage;
  final Directory dossier;

  Grille grille(String id) => etat.session.donnees.grillePar(id)!;
}

Future<Env> lance(
  WidgetTester tester, {
  Donnees? d,
  String? json,
  Size taille = const Size(915, 412),
  String? photo,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final dossier = Directory.systemTemp.createTempSync('glyphe_grilles_');
  addTearDown(() => dossier.deleteSync(recursive: true));
  final photos = Photos(Directory('${dossier.path}/photos'));
  if (photo != null) {
    Directory('${dossier.path}/photos').createSync();
    File('${dossier.path}/photos/$photo').writeAsBytesSync([1, 2, 3]);
  }
  final stockage = FauxStockage(
    json == null ? (d ?? donnees(photo: photo)) : null,
  );
  final etat = EtatAppli(
    stockage: stockage,
    voix: FauxVoix(),
    horloge: FausseHorloge(),
    jsonExemples: json ?? '{}',
    photos: photos,
  );
  await etat.init();
  etat.ouvrirEdition();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return Env(etat, stockage, dossier);
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Ouvre le menu « Plus » (sans défilement) puis touche l'entrée.
Future<void> viaMenu(WidgetTester tester, String cle) async {
  await tester.tap(find.byKey(const Key('bouton-plus')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(cle)));
  await tester.pumpAndSettle();
}

Future<void> ouvrirListe(WidgetTester tester) async {
  await viaMenu(tester, 'bouton-grilles');
  expect(find.byKey(const Key('ecran-grilles')), findsOneWidget);
}

int casesAffichees() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('case-'),
    )
    .evaluate()
    .length;

Future<void> regler(WidgetTester tester, String cle, int fois) async {
  for (var i = 0; i < fois; i++) {
    await toucher(tester, find.byKey(Key(cle)));
  }
}

void main() {
  testsVisibilite();
  testWidgets('REQ017_AC1 la liste montre toutes les grilles', (tester) async {
    await lance(tester);
    await ouvrirListe(tester);
    expect(find.byKey(const Key('grille-acc')), findsOneWidget);
    expect(find.byKey(const Key('grille-man')), findsOneWidget);
    expect(find.text('Manger'), findsOneWidget);
  });

  testWidgets('REQ017_AC1 renommer une grille (persisté)', (tester) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('renommer-man')));
    await tester.enterText(find.byKey(const Key('champ-nom-grille')), 'Repas');
    await toucher(tester, find.text('Enregistrer'));
    expect(e.grille('man').nom, 'Repas');
    expect(e.stockage.donnees!.grillePar('man')!.nom, 'Repas');
    expect(find.text('Repas'), findsOneWidget);
  });

  testWidgets('REQ017_AC1 nom vide : refusé, rien n\'est écrit', (
    tester,
  ) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('renommer-man')));
    await tester.enterText(find.byKey(const Key('champ-nom-grille')), '  ');
    await toucher(tester, find.text('Enregistrer'));
    expect(e.grille('man').nom, 'Manger');
    expect(e.stockage.ecritures, 0);
    expect(find.byKey(const Key('champ-nom-grille')), findsOneWidget);
  });

  testWidgets('REQ017_AC1 l\'accueil se renomme', (tester) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('renommer-acc')));
    await tester.enterText(find.byKey(const Key('champ-nom-grille')), 'Maison');
    await toucher(tester, find.text('Enregistrer'));
    expect(e.grille('acc').nom, 'Maison');
  });

  testWidgets('REQ017_AC1 ouvrir une grille pour l\'éditer', (tester) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('ouvrir-man')));
    expect(find.byKey(const Key('ecran-grilles')), findsNothing);
    expect(e.etat.session.grilleCourante.id, 'man');
    expect(e.etat.modeEdition, isTrue);
    expect(find.byKey(const Key('case-m00')), findsOneWidget);
  });

  testWidgets('REQ017_AC2 supprimer après confirmation, dossier orphelin', (
    tester,
  ) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('supprimer-man')));
    expect(find.byKey(const Key('dialogue-suppression-grille')), findsOne);
    expect(e.grille('man').nom, 'Manger');
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    expect(e.etat.session.donnees.grillePar('man'), isNull);
    expect(e.stockage.donnees!.grillePar('man'), isNull);
    expect(find.byKey(const Key('grille-man')), findsNothing);
    await toucher(tester, find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badge-orphelin')), findsOneWidget);
  });

  testWidgets('REQ017_AC2 suppression annulée : rien ne change', (
    tester,
  ) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('supprimer-man')));
    await toucher(tester, find.byKey(const Key('annuler-suppression')));
    expect(e.grille('man').cases, hasLength(16));
    expect(e.stockage.ecritures, 0);
    expect(find.byKey(const Key('grille-man')), findsOneWidget);
  });

  testWidgets('REQ017_AC3 l\'accueil n\'offre pas la suppression', (
    tester,
  ) async {
    await lance(tester);
    await ouvrirListe(tester);
    expect(find.byKey(const Key('supprimer-acc')), findsNothing);
    expect(find.byKey(const Key('supprimer-man')), findsOneWidget);
    expect(find.byKey(const Key('renommer-acc')), findsOneWidget);
  });

  testWidgets('REQ017_AC2 suppression : photos des cases nettoyées', (
    tester,
  ) async {
    final e = await lance(tester, photo: 'p1.jpg');
    final fichier = File('${e.dossier.path}/photos/p1.jpg');
    expect(fichier.existsSync(), isTrue);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('supprimer-man')));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    await io(tester, jusqua: () => !fichier.existsSync());
    expect(fichier.existsSync(), isFalse);
  });

  testWidgets('REQ001_AC4 une grille d\'exemple se supprime', (tester) async {
    final json = File('assets/exemples/grilles_exemple.json')
        .readAsStringSync();
    final e = await lance(tester, json: json);
    final avant = e.etat.session.donnees.grilles.length;
    final jouer = e.etat.session.donnees.grilles.firstWhere(
      (g) => g.nom == 'Jouer',
    );
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(Key('supprimer-${jouer.id}')));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    expect(e.etat.session.donnees.grilles.length, avant - 1);
    expect(e.etat.session.donnees.grillePar(jouer.id), isNull);
    expect(e.etat.session.donnees.grillePar('accueil'), isNotNull);
  });

  testWidgets('REQ018_AC2/AC3 4x4 -> 3x3 -> 4x4 en édition et communication', (
    tester,
  ) async {
    final e = await lance(tester);
    await ouvrirListe(tester);
    await toucher(tester, find.byKey(const Key('ouvrir-man')));
    expect(casesAffichees(), 16);

    await viaMenu(tester, 'bouton-taille');
    expect(find.byKey(const Key('dialogue-taille')), findsOneWidget);
    await regler(tester, 'lignes-moins', 1);
    await regler(tester, 'colonnes-moins', 1);
    await toucher(tester, find.text('Enregistrer'));
    expect(find.byKey(const Key('dialogue-taille')), findsNothing);
    final g = e.grille('man');
    expect((g.lignes, g.colonnes), (3, 3));
    expect(g.cases, hasLength(16));
    expect(g.casesVisibles, hasLength(9));
    expect(casesAffichees(), 9);
    final stocke = e.stockage.donnees!.grillePar('man')!;
    expect((stocke.lignes, stocke.colonnes), (3, 3));

    e.etat.verrouiller();
    await tester.pumpAndSettle();
    expect(casesAffichees(), 9);
    e.etat.ouvrirEdition();
    await tester.pumpAndSettle();

    await viaMenu(tester, 'bouton-taille');
    await regler(tester, 'lignes-plus', 1);
    await regler(tester, 'colonnes-plus', 1);
    await toucher(tester, find.text('Enregistrer'));
    expect(casesAffichees(), 16);
    final apres = e.grille('man');
    expect(
      apres.cases.map((c) => (c.id, c.ligne, c.colonne)),
      donnees().grillePar('man')!.cases.map((c) => (c.id, c.ligne, c.colonne)),
    );
  });

  testWidgets('REQ018_AC1 bornes 1..8 et annulation', (tester) async {
    final e = await lance(tester);
    await viaMenu(tester, 'bouton-taille');
    await regler(tester, 'lignes-plus', 6);
    expect(find.byKey(const Key('lignes-valeur')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('lignes-valeur'))).data,
      '8',
    );
    await regler(tester, 'colonnes-moins', 7);
    expect(
      tester.widget<Text>(find.byKey(const Key('colonnes-valeur'))).data,
      '1',
    );
    await toucher(tester, find.text('Annuler'));
    expect(e.grille('acc').lignes, 4);
    expect(e.stockage.ecritures, 0);

    await viaMenu(tester, 'bouton-taille');
    await regler(tester, 'lignes-plus', 4);
    await regler(tester, 'colonnes-moins', 3);
    await toucher(tester, find.text('Enregistrer'));
    expect((e.grille('acc').lignes, e.grille('acc').colonnes), (8, 1));
  });

  for (final taille in const [
    Size(640, 360),
    Size(915, 412),
    Size(1280, 800),
  ]) {
    testWidgets('REQ028 liste des grilles et dialogue de taille $taille', (
      tester,
    ) async {
      final h = tester.ensureSemantics();
      final json = File('assets/exemples/grilles_exemple.json')
          .readAsStringSync();
      await lance(tester, json: json, taille: taille);
      await viaMenu(tester, 'bouton-grilles');
      expect(find.byKey(const Key('ecran-grilles')), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await toucher(tester, find.byKey(const Key('renommer-accueil')));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await toucher(tester, find.text('Annuler'));
      await toucher(tester, find.byTooltip('Retour'));
      await viaMenu(tester, 'bouton-taille');
      expect(find.byKey(const Key('dialogue-taille')), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      h.dispose();
    });
  }
}

void testsVisibilite() {
  for (final taille in [const Size(640, 360), const Size(915, 412)]) {
    testWidgets('REQ017_AC1/REQ018_AC1 actions d\'édition visibles $taille', (
      tester,
    ) async {
      await lance(tester, taille: taille);
      final ecran = Offset.zero & taille;
      for (final f in [
        find.byKey(const Key('bouton-terminer')),
        find.byKey(const Key('ajouter-case')),
        find.byKey(const Key('bouton-plus')),
      ]) {
        final r = tester.getRect(f);
        expect(
          ecran.contains(r.topLeft) && ecran.contains(r.bottomRight),
          isTrue,
          reason: '$f hors écran : $r',
        );
        expect(r.height >= 48 && r.width >= 48, isTrue);
      }
      await tester.tap(find.byKey(const Key('bouton-plus')));
      await tester.pumpAndSettle();
      for (final k in ['bouton-code', 'bouton-grilles', 'bouton-taille']) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(
          ecran.contains(r.topLeft) && ecran.contains(r.bottomRight),
          isTrue,
          reason: '$k hors écran : $r',
        );
        expect(r.height >= 48, isTrue);
      }
    });
  }
}
