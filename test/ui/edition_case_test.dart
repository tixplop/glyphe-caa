import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/etat_appli.dart';

import '../faux/faux_stockage.dart';
import '../faux/faux_voix.dart';
import '../faux/fausse_horloge.dart';

Donnees donnees({int lignes = 2, int colonnes = 2}) => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: lignes,
      colonnes: colonnes,
      cases: const [
        Case(
          id: 'je',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'je',
          image: ImageArasaac(2617),
        ),
        Case(
          id: 'd-man',
          ligne: 0,
          colonne: 1,
          type: TypeCase.dossier,
          libelle: 'Manger',
          cibleId: 'man',
        ),
        Case(
          id: 'd-orph',
          ligne: 1,
          colonne: 0,
          type: TypeCase.dossier,
          libelle: 'Perdu',
          cibleId: 'inexistante',
        ),
      ],
    ),
    Grille(
      id: 'man',
      nom: 'Manger',
      lignes: 2,
      colonnes: 2,
      cases: const [
        Case(
          id: 'pomme',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'pomme',
        ),
      ],
    ),
  ],
);

class Env {
  Env(this.stockage, this.voix, this.etat);
  final FauxStockage stockage;
  final FauxVoix voix;
  final EtatAppli etat;
}

EtatAppli creerEtat(FauxStockage s, FauxVoix v) => EtatAppli(
  stockage: s,
  voix: v,
  horloge: FausseHorloge(),
  jsonExemples: '{}',
);

Future<Env> lance(
  WidgetTester tester, {
  bool edition = true,
  Donnees? d,
  FauxStockage? stockage,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = stockage ?? FauxStockage(d ?? donnees());
  final v = FauxVoix();
  final etat = creerEtat(s, v);
  await etat.init();
  if (edition) etat.ouvrirEdition();
  await tester.pumpWidget(GlypheApp(etat: etat));
  await tester.pumpAndSettle();
  return Env(s, v, etat);
}

Finder champ(String nom) => find.byKey(Key(nom));

Future<void> saisir(WidgetTester tester, String nom, String texte) async {
  await tester.ensureVisible(champ(nom));
  await tester.enterText(champ(nom), texte);
  await tester.pump();
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Case caseDe(Env e, String grille, String id) => e.etat.session.donnees
    .grillePar(grille)!
    .cases
    .firstWhere((c) => c.id == id);

Future<void> ajouterMot(WidgetTester tester, String lib) async {
  await toucher(tester, find.byKey(const Key('vide-1-1')));
  await saisir(tester, 'champ-libelle', lib);
  await toucher(tester, find.text('Enregistrer'));
}

void main() {
  testWidgets('REQ015_AC5 en édition, un appui ouvre l\'édition sans parler', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.voix.textesPrononces, isEmpty);
    expect(e.etat.session.barre, isEmpty);
  });

  testWidgets('REQ015_AC5 en communication, pas d\'édition', (tester) async {
    final e = await lance(tester, edition: false);
    await toucher(tester, find.byKey(const Key('case-je')));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.barre.length, 1);
  });

  testWidgets('REQ015_AC5 « Ouvrir » ouvre la sous-grille d\'un dossier', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-d-man')));
    await toucher(tester, find.text('Ouvrir'));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.grilleCourante.id, 'man');
    expect(find.byKey(const Key('case-pomme')), findsOneWidget);
  });

  testWidgets('REQ015_AC5 pas d\'« Ouvrir » pour un mot', (tester) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    expect(find.text('Ouvrir'), findsNothing);
  });

  testWidgets('REQ015_AC1 emplacement vide : « + », ajout d\'une case', (
    tester,
  ) async {
    final e = await lance(tester);
    expect(find.byKey(const Key('vide-1-1')), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await ajouterMot(tester, 'chat');
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    final g = e.etat.session.donnees.grillePar('acc')!;
    final c = g.cases.firstWhere((c) => c.libelle == 'chat');
    expect((c.ligne, c.colonne), (1, 1));
    expect(find.text('chat'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('REQ015_AC1 pas de « + » en communication', (tester) async {
    await lance(tester, edition: false);
    expect(find.byKey(const Key('vide-1-1')), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('REQ015_AC1 modifier libellé, texte prononcé, couleur', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await saisir(tester, 'champ-libelle', 'moi');
    await saisir(tester, 'champ-texte', 'c\'est moi');
    await toucher(tester, champ('couleur-2'));
    await toucher(tester, find.text('Enregistrer'));
    final c = caseDe(e, 'acc', 'je');
    expect(c.libelle, 'moi');
    expect(c.textePrononce, 'c\'est moi');
    expect(c.couleur, 0xFFBBDEFB);
    expect(c.image, const ImageArasaac(2617));
  });

  testWidgets('REQ015_AC1 l\'écran propose l\'image (provisoirement aucune)', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    expect(champ('bouton-image'), findsOneWidget);
    expect(find.text('aucune'), findsOneWidget);
  });

  testWidgets('REQ015_AC2 sans image ni libellé : message, rien enregistré', (
    tester,
  ) async {
    final e = await lance(tester);
    final avant = e.stockage.ecritures;
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await toucher(tester, find.text('Enregistrer'));
    expect(find.text('Ajoutez une image ou un libellé'), findsOneWidget);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.stockage.ecritures, avant);
  });

  testWidgets('REQ015_AC3 suppression : annuler ne change rien', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.text('Supprimer'));
    expect(find.byKey(const Key('confirmation-suppression')), findsOneWidget);
    await toucher(tester, find.text('Annuler'));
    expect(find.byKey(const Key('confirmation-suppression')), findsNothing);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.etat.session.donnees.grillePar('acc')!.cases.length, 3);
  });

  testWidgets('REQ015_AC3 suppression : confirmer supprime', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.text('Supprimer'));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.donnees.grillePar('acc')!.cases.length, 2);
    expect(find.byKey(const Key('case-je')), findsNothing);
    expect(find.byKey(const Key('vide-0-0')), findsOneWidget);
  });

  testWidgets('REQ015_AC4 persistance après recréation de l\'EtatAppli', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await saisir(tester, 'champ-libelle', 'moi');
    await toucher(tester, find.text('Enregistrer'));
    await ajouterMot(tester, 'chat');
    final apres = creerEtat(e.stockage, FauxVoix());
    await apres.init();
    final g = apres.session.donnees.grillePar('acc')!;
    expect(g.cases.any((c) => c.id == 'je' && c.libelle == 'moi'), isTrue);
    expect(g.cases.any((c) => c.libelle == 'chat'), isTrue);
  });

  testWidgets('REQ015_AC4 suppression persistée', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.text('Supprimer'));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    final apres = creerEtat(e.stockage, FauxVoix());
    await apres.init();
    expect(
      apres.session.donnees.grillePar('acc')!.cases.any((c) => c.id == 'je'),
      isFalse,
    );
  });

  testWidgets('REQ015_AC1 grille pleine : « Agrandissez la grille »', (
    tester,
  ) async {
    final e = await lance(tester, d: donnees(lignes: 1, colonnes: 2));
    expect(find.byKey(const Key('vide-0-0')), findsNothing);
    final avant = e.etat.session.donnees.grillePar('acc')!.cases.length;
    await toucher(tester, find.text('Ajouter une case'));
    expect(find.text('Agrandissez la grille'), findsOneWidget);
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.donnees.grillePar('acc')!.cases.length, avant);
  });

  testWidgets('REQ015_AC1 « Ajouter une case » ouvre l\'édition si libre', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.text('Ajouter une case'));
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
  });

  testWidgets('REQ015_AC1 grille remplie pendant l\'édition : consigne', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    final g = e.etat.session.donnees.grillePar('acc')!;
    final pleine = g.copyWith(
      cases: [
        ...g.cases,
        const Case(
          id: 'x',
          ligne: 1,
          colonne: 1,
          type: TypeCase.mot,
          libelle: 'x',
          textePrononce: 'x',
        ),
      ],
    );
    await e.etat.modifierDonnees(
      e.etat.session.donnees.copyWith(
        grilles: [
          for (final h in e.etat.session.donnees.grilles)
            h.id == 'acc' ? pleine : h,
        ],
      ),
    );
    await saisir(tester, 'champ-libelle', 'chat');
    await toucher(tester, find.text('Enregistrer'));
    expect(find.text('Agrandissez la grille'), findsOneWidget);
    expect(find.text('Modification impossible'), findsNothing);
  });

  testWidgets('REQ015_AC6 échanger avec un emplacement', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.text('Échanger avec l\'emplacement…'));
    await toucher(tester, find.byKey(const Key('emplacement-1-1')));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    final c = caseDe(e, 'acc', 'je');
    expect((c.ligne, c.colonne), (1, 1));
    expect(find.byKey(const Key('vide-0-0')), findsOneWidget);
  });

  testWidgets('REQ015_AC6 échanger avec une case occupée', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.text('Échanger avec l\'emplacement…'));
    await toucher(tester, find.byKey(const Key('emplacement-0-1')));
    expect(caseDe(e, 'acc', 'je').colonne, 1);
    expect(caseDe(e, 'acc', 'd-man').colonne, 0);
  });

  testWidgets('REQ016_AC1 dossier vers une grille existante', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await saisir(tester, 'champ-libelle', 'Repas');
    await toucher(tester, champ('type-dossier'));
    await toucher(tester, champ('champ-cible'));
    // La grille courante n'est pas proposée.
    expect(find.text('Accueil'), findsNothing);
    await toucher(tester, find.text('Manger').last);
    await toucher(tester, find.text('Enregistrer'));
    final c = caseDe(
      e,
      'acc',
      e.etat.session.donnees
          .grillePar('acc')!
          .cases
          .firstWhere((c) => c.libelle == 'Repas')
          .id,
    );
    expect(c.type, TypeCase.dossier);
    expect(c.cibleId, 'man');
  });

  testWidgets('REQ016_AC2 « Nouvelle grille » nommée comme la case', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await saisir(tester, 'champ-libelle', 'Animaux');
    await toucher(tester, champ('type-dossier'));
    await toucher(tester, champ('champ-cible'));
    await toucher(tester, find.text('Nouvelle grille').last);
    await toucher(tester, find.text('Enregistrer'));
    final d = e.etat.session.donnees;
    final nouvelle = d.grilles.firstWhere((g) => g.nom == 'Animaux');
    expect((nouvelle.lignes, nouvelle.colonnes), (4, 4));
    expect(nouvelle.cases, isEmpty);
    final c = d
        .grillePar('acc')!
        .cases
        .firstWhere((c) => c.libelle == 'Animaux');
    expect(c.cibleId, nouvelle.id);
  });

  testWidgets('REQ016_AC3 dossier sans cible : message, rien enregistré', (
    tester,
  ) async {
    final e = await lance(tester);
    final avant = e.stockage.ecritures;
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await saisir(tester, 'champ-libelle', 'Animaux');
    await toucher(tester, champ('type-dossier'));
    await toucher(tester, find.text('Enregistrer'));
    expect(find.text('Choisissez une grille pour ce dossier'), findsOneWidget);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.stockage.ecritures, avant);
    expect(e.etat.session.donnees.grilles.length, 2);
  });

  testWidgets('REQ008_AC3 badge « grille introuvable » en édition seulement', (
    tester,
  ) async {
    final e = await lance(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('case-d-orph')),
        matching: find.byKey(const Key('badge-orphelin')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('badge-orphelin')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('grille introuvable')), findsWidgets);
    e.etat.verrouiller();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('badge-orphelin')), findsNothing);
  });

  testWidgets('REQ001_AC4 modifier puis supprimer une case d\'exemple', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-d-man')));
    await toucher(tester, find.text('Supprimer'));
    await toucher(tester, find.byKey(const Key('confirmer-suppression')));
    expect(
      e.etat.session.donnees
          .grillePar('acc')!
          .cases
          .any((c) => c.id == 'd-man'),
      isFalse,
    );
  });

  testWidgets('édition : le reverrouillage ferme l\'écran d\'édition', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    e.etat.verrouiller();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
  });

  testWidgets('édition : une notification ne ferme pas l\'écran d\'édition', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    // Notification de session pendant l'édition, toujours déverrouillé.
    e.etat.session.toutEffacer();
    e.etat.session.accueil();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
  });

  testWidgets('verrouillé : les notifications ne ferment pas les routes', (
    tester,
  ) async {
    final e = await lance(tester, edition: false);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('autre-route')),
      ),
    );
    await tester.pumpAndSettle();
    // ignore: invalid_use_of_protected_member
    e.etat.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('autre-route'), findsOneWidget);
  });
}
