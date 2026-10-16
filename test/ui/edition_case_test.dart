import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/ui/app.dart';
import 'package:glyphe/ui/ecran_a_propos.dart';
import 'package:glyphe/ui/ecran_code.dart';
import 'package:glyphe/ui/ecran_grilles.dart';
import 'package:glyphe/ui/ecran_reglages.dart';
import 'package:glyphe/ui/etat_appli.dart';
import 'package:glyphe/ui/selecteur_image.dart';
import 'package:glyphe/ui/tokens.dart';
import 'package:glyphe/ui/widgets/barre_edition.dart';

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

Finder cle(String k) => find.byKey(Key(k));

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
  await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
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
    await toucher(tester, find.byKey(const Key('bouton-ouvrir')));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.grilleCourante.id, 'man');
    expect(find.byKey(const Key('case-pomme')), findsOneWidget);
  });

  testWidgets('REQ015_AC5 pas d\'« Ouvrir » pour un mot', (tester) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    expect(find.byKey(const Key('bouton-ouvrir')), findsNothing);
  });

  testWidgets('REQ015_AC1 emplacement vide : « + », ajout d\'une case', (
    tester,
  ) async {
    final e = await lance(tester);
    expect(find.byKey(const Key('vide-1-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('vide-1-1')),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
    await ajouterMot(tester, 'chat');
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    final g = e.etat.session.donnees.grillePar('acc')!;
    final c = g.cases.firstWhere((c) => c.libelle == 'chat');
    expect((c.ligne, c.colonne), (1, 1));
    expect(find.text('chat'), findsOneWidget);
    expect(find.byKey(const Key('vide-1-1')), findsNothing);
  });

  testWidgets('REQ015_AC1 pas de « + » en communication', (tester) async {
    await lance(tester, edition: false);
    expect(find.byKey(const Key('vide-1-1')), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('REQ015_AC1 modifier libellé, texte prononcé, catégorie', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await saisir(tester, 'champ-libelle', 'moi');
    await saisir(tester, 'champ-texte', 'c\'est moi');
    await toucher(tester, champ('categorie-description'));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    final c = caseDe(e, 'acc', 'je');
    expect(c.libelle, 'moi');
    expect(c.textePrononce, 'c\'est moi');
    expect(c.categorie, Categorie.description);
    expect(c.image, const ImageArasaac(2617));
  });

  testWidgets('REQ032_AC3 sept catégories proposées, avec leur nom', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await tester.ensureVisible(find.text('Catégorie'));
    expect(find.text('Catégorie'), findsOneWidget);
    for (final c in Categorie.values) {
      expect(champ('categorie-${c.name}'), findsOneWidget, reason: c.name);
    }
    for (final nom in [
      'Personnes',
      'Actions',
      'Choses',
      'Description',
      'Social',
      'Questions',
      'Petits mots',
    ]) {
      expect(find.text(nom), findsOneWidget, reason: nom);
    }
  });

  testWidgets('REQ032_AC1 une nouvelle case est en Petits mots', (
    tester,
  ) async {
    final e = await lance(tester);
    await ajouterMot(tester, 'chat');
    final g = e.etat.session.donnees.grillePar('acc')!;
    expect(
      g.cases.firstWhere((c) => c.libelle == 'chat').categorie,
      Categorie.petitMot,
    );
  });

  testWidgets('REQ032_AC3 la catégorie choisie est enregistrée', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await saisir(tester, 'champ-libelle', 'chat');
    await toucher(tester, champ('categorie-question'));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    final c = e.stockage.donnees!
        .grillePar('acc')!
        .cases
        .firstWhere((c) => c.libelle == 'chat');
    expect(c.categorie, Categorie.question);
  });

  testWidgets('REQ015_AC1 l\'écran propose l\'image (icône d\'ajout)', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    expect(champ('bouton-image'), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
  });

  testWidgets('REQ015_AC2 sans image ni libellé : message, rien enregistré', (
    tester,
  ) async {
    final e = await lance(tester);
    final avant = e.stockage.ecritures;
    await toucher(tester, find.byKey(const Key('vide-1-1')));
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    expect(find.text('Ajoutez une image ou un libellé'), findsOneWidget);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.stockage.ecritures, avant);
  });

  testWidgets('REQ015_AC3 suppression : annuler ne change rien', (
    tester,
  ) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.byKey(const Key('bouton-supprimer')));
    expect(find.byKey(const Key('confirmation-suppression')), findsOneWidget);
    await toucher(tester, find.text('Annuler'));
    expect(find.byKey(const Key('confirmation-suppression')), findsNothing);
    expect(find.byKey(const Key('ecran-edition-case')), findsOneWidget);
    expect(e.etat.session.donnees.grillePar('acc')!.cases.length, 3);
  });

  testWidgets('REQ015_AC3 suppression : confirmer supprime', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.byKey(const Key('bouton-supprimer')));
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
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
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
    await toucher(tester, find.byKey(const Key('bouton-supprimer')));
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
    await toucher(tester, find.byKey(const Key('ajouter-case')));
    expect(find.text('Agrandissez la grille'), findsOneWidget);
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    expect(e.etat.session.donnees.grillePar('acc')!.cases.length, avant);
  });

  testWidgets('REQ015_AC1 « Ajouter une case » ouvre l\'édition si libre', (
    tester,
  ) async {
    await lance(tester);
    await toucher(tester, find.byKey(const Key('ajouter-case')));
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
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    expect(find.text('Agrandissez la grille'), findsOneWidget);
    expect(find.text('Modification impossible'), findsNothing);
  });

  testWidgets('REQ015_AC6 échanger avec un emplacement', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.byKey(const Key('bouton-echanger')));
    await toucher(tester, find.byKey(const Key('emplacement-1-1')));
    expect(find.byKey(const Key('ecran-edition-case')), findsNothing);
    final c = caseDe(e, 'acc', 'je');
    expect((c.ligne, c.colonne), (1, 1));
    expect(find.byKey(const Key('vide-0-0')), findsOneWidget);
  });

  testWidgets('REQ015_AC6 échanger avec une case occupée', (tester) async {
    final e = await lance(tester);
    await toucher(tester, find.byKey(const Key('case-je')));
    await toucher(tester, find.byKey(const Key('bouton-echanger')));
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
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
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
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
    final d = e.etat.session.donnees;
    final nouvelle = d.grilles.firstWhere((g) => g.nom == 'Animaux');
    expect((nouvelle.lignes, nouvelle.colonnes), (3, 4));
    final r = nouvelle.cases.single;
    expect((r.type, r.ligne, r.colonne), (TypeCase.retour, 0, 0));
    expect(r.libelle, 'Retour');
    expect(r.image, isA<ImageAucune>());
    expect(r.categorie, Categorie.petitMot);
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
    await toucher(tester, find.byKey(const Key('bouton-enregistrer')));
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
    await toucher(tester, find.byKey(const Key('bouton-supprimer')));
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

  group('REQ036 actions en icônes', () {
    Finder cle(String k) => find.byKey(Key(k));
    double gauche(WidgetTester t, String k) => t.getTopLeft(cle(k)).dx;

    testWidgets('REQ036_AC3 nouvelle case : seulement Enregistrer', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      expect(cle('bouton-enregistrer'), findsOneWidget);
      expect(cle('bouton-supprimer'), findsNothing);
      expect(cle('bouton-echanger'), findsNothing);
      expect(cle('bouton-ouvrir'), findsNothing);
      expect(find.text('Nouvelle case'), findsOneWidget);
    });

    testWidgets('REQ036_AC3 mot : Supprimer, Échanger, pas Ouvrir', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('case-je'));
      expect(cle('bouton-supprimer'), findsOneWidget);
      expect(cle('bouton-echanger'), findsOneWidget);
      expect(cle('bouton-ouvrir'), findsNothing);
    });

    testWidgets('REQ036_AC3 dossier orphelin : pas d\'Ouvrir', (tester) async {
      await lance(tester);
      await toucher(tester, cle('case-d-orph'));
      expect(cle('bouton-ouvrir'), findsNothing);
      expect(cle('bouton-supprimer'), findsOneWidget);
    });

    testWidgets('REQ037_AC8 dossier existant devenu Retour : pas d\'Ouvrir', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('case-d-man'));
      expect(cle('bouton-ouvrir'), findsOneWidget);
      await toucher(tester, cle('type-retour'));
      expect(cle('bouton-ouvrir'), findsNothing);
    });

    testWidgets('REQ036_AC3 AC9 dossier existant : ordre, icônes, sans texte', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('case-d-man'));
      final ordre = [
        'bouton-supprimer',
        'bouton-echanger',
        'bouton-ouvrir',
        'bouton-enregistrer',
      ];
      for (var i = 0; i < ordre.length - 1; i++) {
        expect(
          gauche(tester, ordre[i]),
          lessThan(gauche(tester, ordre[i + 1])),
        );
      }
      expect(tester.getSize(cle('bouton-enregistrer')), const Size(48, 48));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check), findsWidgets);
      final suppr = tester.widget<IconButton>(cle('bouton-supprimer'));
      expect(suppr.tooltip, 'Supprimer');
      expect((suppr.icon as Icon).color, GlypheTokens.clair.danger);
      // Aucune action sous le formulaire.
      final bas = tester.getBottomLeft(find.text('Dossier')).dy;
      for (final k in ordre) {
        expect(tester.getTopLeft(cle(k)).dy, lessThan(bas));
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      // Retour en français.
      expect(find.byTooltip('Retour'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
    });

    for (final taille in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets('REQ036_AC5 $taille dossier existant : sans débordement', (
        tester,
      ) async {
        await lance(tester);
        tester.view.physicalSize = taille;
        await tester.pumpAndSettle();
        await tester.tap(cle('case-d-man'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final k in [
          'bouton-supprimer',
          'bouton-echanger',
          'bouton-ouvrir',
          'bouton-enregistrer',
        ]) {
          final r = tester.getRect(cle(k));
          expect(r.right, lessThanOrEqualTo(taille.width), reason: k);
          expect(r.top, greaterThanOrEqualTo(0), reason: k);
          expect(r.bottom, lessThanOrEqualTo(taille.height), reason: k);
        }
      });
    }

    testWidgets('REQ036_AC4 aperçu 72 : icône vide, focus avant Libellé', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      expect(
        tester.getSize(
          find
              .ancestor(
                of: cle('bouton-image'),
                matching: find.byType(Material),
              )
              .first,
        ),
        const Size(72, 72),
      );
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byTooltip('Image'), findsOneWidget);
      expect(
        tester.getTopLeft(cle('bouton-image')).dx,
        lessThan(tester.getTopLeft(cle('champ-libelle')).dx),
      );
      expect(find.text('Image'), findsNothing);
      final h = tester.ensureSemantics();
      expect(
        tester.getSemantics(cle('bouton-image')),
        matchesSemantics(label: 'Image', isButton: true, hasTapAction: true),
      );
      h.dispose();
      // Le focus clavier part de l'aperçu, avant le libellé.
      bool dans(Key k) =>
          FocusManager.instance.primaryFocus!.context!
                  .findAncestorWidgetOfExactType<InkWell>()
                  ?.key ==
              k ||
          FocusManager.instance.primaryFocus!.context!
                  .findAncestorWidgetOfExactType<TextField>()
                  ?.key ==
              k;
      Key? atteint;
      for (var i = 0; i < 10 && atteint == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final k in const [Key('bouton-image'), Key('champ-libelle')]) {
          if (dans(k)) atteint = k;
        }
      }
      expect(atteint, const Key('bouton-image'));
    });

    testWidgets('REQ036_AC4 aperçu avec image existante, sans icône vide', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('case-je'));
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);
      expect(
        find.descendant(of: cle('bouton-image'), matching: find.byType(Image)),
        findsOneWidget,
      );
    });

    testWidgets('REQ036_AC4 toucher l\'aperçu ouvre le sélecteur', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('bouton-image'));
      expect(find.byKey(const Key('ecran-selecteur-image')), findsOneWidget);
    });

    testWidgets('REQ036 erreur : focus sur le libellé', (tester) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('bouton-enregistrer'));
      expect(find.byKey(const Key('erreur-edition')), findsOneWidget);
      final f = FocusManager.instance.primaryFocus!;
      expect(
        f.context!.findAncestorWidgetOfExactType<TextField>()?.key,
        const Key('champ-libelle'),
      );
    });

    testWidgets('REQ036 erreur : focus sur la grille cible', (tester) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await saisir(tester, 'champ-libelle', 'x');
      await toucher(tester, cle('type-dossier'));
      await toucher(tester, cle('bouton-enregistrer'));
      expect(find.byKey(const Key('erreur-edition')), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<DropdownButton<String>>()
            ?.key,
        const Key('champ-cible'),
      );
    });
  });

  testWidgets('REQ036_AC4 nouvelle case : l\'image choisie remplace l\'icône', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final etat = EtatAppli(
      stockage: FauxStockage(donnees()),
      voix: FauxVoix(),
      horloge: FausseHorloge(),
      jsonExemples: '{}',
      banque: BanquePictos.depuisJson('[{"id":2517,"motsCles":["chien"]}]'),
    );
    await etat.init();
    etat.ouvrirEdition();
    await tester.pumpWidget(GlypheApp(etat: etat));
    await tester.pumpAndSettle();
    await toucher(tester, cle('vide-1-1'));
    expect(
      find.descendant(
        of: cle('bouton-image'),
        matching: find.byIcon(Icons.add_photo_alternate_outlined),
      ),
      findsOneWidget,
    );
    await toucher(tester, cle('bouton-image'));
    await tester.enterText(cle('champ-recherche'), 'chien');
    await tester.pumpAndSettle();
    await toucher(tester, cle('picto-2517'));
    expect(cle('ecran-edition-case'), findsOneWidget);
    expect(
      find.descendant(of: cle('bouton-image'), matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cle('bouton-image'),
        matching: find.byIcon(Icons.add_photo_alternate_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets('REQ029_AC1 aucune info-bulle « Back » sur les 6 écrans', (
    tester,
  ) async {
    final e = await lance(tester, edition: false);
    void verifie(String ecran) {
      expect(find.byTooltip('Back'), findsNothing, reason: ecran);
      expect(find.byTooltip('Retour'), findsOneWidget, reason: ecran);
    }

    Future<void> affiche(String nom, Widget w) async {
      await tester.pumpWidget(MaterialApp(home: w));
      await tester.pumpAndSettle();
      verifie(nom);
    }

    await affiche('grilles', EcranGrilles(etat: e.etat));
    await affiche('sélecteur', SelecteurImage(etat: e.etat));
    await affiche('à propos', const EcranAPropos());
    await affiche('réglages', EcranReglages(etat: e.etat));
    await affiche('code', EcranCode(verrou: e.etat.verrou));

    await tester.pumpWidget(GlypheApp(etat: e.etat));
    await tester.pumpAndSettle();
    e.etat.ouvrirEdition();
    await tester.pumpAndSettle();
    await toucher(tester, cle('case-je'));
    expect(cle('ecran-edition-case'), findsOneWidget);
    verifie('édition de case');
  });

  group('case-retour dans l\'éditeur (REQ-037, REQ-016)', () {
    testWidgets('REQ037_AC8 trois puces, champs masqués, aide, Ouvrir absent', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      // Ordre de lecture : ligne puis colonne (les puces peuvent passer à
      // la ligne).
      final pos = [
        for (final k in ['type-mot', 'type-dossier', 'type-retour'])
          tester.getTopLeft(cle(k)),
      ];
      for (var i = 0; i < 2; i++) {
        final apres =
            pos[i + 1].dy > pos[i].dy ||
            (pos[i + 1].dy == pos[i].dy && pos[i + 1].dx > pos[i].dx);
        expect(apres, isTrue);
      }
      expect(find.text('Retour'), findsWidgets);
      expect(cle('champ-texte'), findsOneWidget);
      await toucher(tester, cle('type-retour'));
      expect(cle('champ-texte'), findsNothing);
      expect(cle('champ-cible'), findsNothing);
      expect(find.textContaining('est sans effet'), findsOneWidget);
      expect(cle('bouton-ouvrir'), findsNothing);
      // Libellé pré-rempli.
      expect(
        tester.widget<TextField>(cle('champ-libelle')).controller!.text,
        'Retour',
      );
      // Retour à Mot : champs réaffichés.
      await toucher(tester, cle('type-mot'));
      expect(cle('champ-texte'), findsOneWidget);
      expect(find.textContaining('est sans effet'), findsNothing);
      await toucher(tester, cle('type-dossier'));
      expect(cle('champ-cible'), findsOneWidget);
    });

    testWidgets('REQ037_AC5 libellé existant non écrasé', (tester) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await saisir(tester, 'champ-libelle', 'Revenir');
      await toucher(tester, cle('type-retour'));
      expect(
        tester.widget<TextField>(cle('champ-libelle')).controller!.text,
        'Revenir',
      );
    });

    testWidgets('REQ037_AC8 sur l\'accueil : sans effet', (tester) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('type-retour'));
      expect(
        find.text('Sur l\'accueil, cette case est sans effet.'),
        findsOneWidget,
      );
    });

    testWidgets('REQ037_AC5 enregistrement persistant, sans texte ni cible', (
      tester,
    ) async {
      final e = await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await saisir(tester, 'champ-texte', 'bidon');
      await toucher(tester, cle('type-retour'));
      await toucher(tester, cle('bouton-enregistrer'));
      final c = e.stockage.donnees!
          .grillePar('acc')!
          .cases
          .firstWhere((c) => c.type == TypeCase.retour);
      expect((c.ligne, c.colonne), (1, 1));
      expect(c.libelle, 'Retour');
      expect(c.textePrononce, '');
      expect(c.cibleId, isNull);
      expect(cle('fleche-retour'), findsOneWidget);
      // Identique en édition : appui = éditeur, type Retour conservé.
      await toucher(tester, cle('case-${c.id}'));
      expect(tester.widget<ChoiceChip>(cle('type-retour')).selected, isTrue);
    });

    testWidgets('REQ037_AC5 sur une sous-grille : aide « Revient »', (
      tester,
    ) async {
      final e = await lance(tester);
      e.etat.session.ouvrirGrille('man');
      await tester.pumpAndSettle();
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('type-retour'));
      expect(find.text('Revient à la grille précédente.'), findsOneWidget);
    });

    testWidgets('REQ037_AC5 AC015_2 retour sans libellé ni image refusé', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('type-retour'));
      await saisir(tester, 'champ-libelle', '');
      await toucher(tester, cle('bouton-enregistrer'));
      expect(find.text('Ajoutez une image ou un libellé'), findsOneWidget);
    });

    for (final taille in const [Size(360, 640), Size(640, 360)]) {
      testWidgets('REQ037_AC8 type Retour sans débordement $taille', (
        tester,
      ) async {
        await lance(tester);
        tester.view.physicalSize = taille;
        await tester.pumpAndSettle();
        await toucher(tester, cle('vide-1-1'));
        await toucher(tester, cle('type-retour'));
        expect(tester.takeException(), isNull);
        await toucher(tester, cle('type-dossier'));
        await toucher(tester, cle('champ-cible'));
        await toucher(tester, find.text('Nouvelle grille').last);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('REQ016_AC4 aide « Nouvelle grille » suit la frappe', (
      tester,
    ) async {
      await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await toucher(tester, cle('type-dossier'));
      await toucher(tester, cle('champ-cible'));
      await toucher(tester, find.text('Manger').last);
      // Grille existante : pas d'aide.
      expect(find.textContaining('sera créée'), findsNothing);
      await toucher(tester, cle('champ-cible'));
      await toucher(tester, find.text('Nouvelle grille').last);
      expect(
        find.text(
          'Une grille « Nouvelle grille » sera créée, avec une case Retour.',
        ),
        findsOneWidget,
      );
      await saisir(tester, 'champ-libelle', '  Animaux ');
      expect(
        find.text('Une grille « Animaux » sera créée, avec une case Retour.'),
        findsOneWidget,
      );
    });

    testWidgets('REQ016_AC5 enregistrement puis ouverture de la grille', (
      tester,
    ) async {
      final e = await lance(tester);
      await toucher(tester, cle('vide-1-1'));
      await saisir(tester, 'champ-libelle', 'Animaux');
      await toucher(tester, cle('type-dossier'));
      await toucher(tester, cle('champ-cible'));
      await toucher(tester, find.text('Nouvelle grille').last);
      await toucher(tester, cle('bouton-enregistrer'));
      expect(e.etat.session.grilleCourante.id, 'acc');
      expect(e.etat.modeEdition, isTrue);
      final id = e.etat.session.donnees
          .grillePar('acc')!
          .cases
          .firstWhere((c) => c.libelle == 'Animaux')
          .id;
      expect(
        find.descendant(of: cle('case-$id'), matching: cle('coin-dossier')),
        findsOneWidget,
      );
      await toucher(tester, cle('case-$id'));
      await toucher(tester, cle('bouton-ouvrir'));
      expect(find.text('Mode édition'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BarreEdition),
          matching: find.text('Animaux'),
        ),
        findsOneWidget,
      );
      final g = e.etat.session.grilleCourante;
      final r = g.cases.single;
      final zone = tester.getTopLeft(cle('grille'));
      final pos = tester.getTopLeft(cle('case-${r.id}'));
      expect((pos.dx - zone.dx).abs(), lessThan(8));
      expect((pos.dy - zone.dy).abs(), lessThan(8));
      expect(cle('fleche-retour'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) {
          final k = w.key;
          return k is ValueKey<String> && k.value.startsWith('vide-');
        }),
        findsNWidgets(11),
      );
      expect(cle('vide-0-0'), findsNothing);
    });
  });
}
