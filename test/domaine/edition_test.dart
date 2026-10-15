import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/edition.dart';
import 'package:glyphe/domaine/modeles.dart';

Case mot(String id, int l, int c, {String lib = 'x'}) =>
    Case(id: id, ligne: l, colonne: c, type: TypeCase.mot, libelle: lib);

Donnees base({int lignes = 2, int colonnes = 2, List<Case>? cases}) => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: lignes,
      colonnes: colonnes,
      cases: cases ?? [mot('a', 0, 0), mot('b', 0, 1)],
    ),
    Grille(id: 'g2', nom: 'Autre', lignes: 4, colonnes: 4),
    Grille(id: 'g3', nom: 'Tiers', lignes: 4, colonnes: 4),
  ],
);

void expectErreur(void Function() f, CodeErreurEdition code) {
  try {
    f();
  } on ErreurEdition catch (e) {
    expect(e.code, code);
    return;
  }
  fail('ErreurEdition attendue');
}

void main() {
  test('REQ015_AC1 ajouter une case sur le premier emplacement libre', () {
    final d = ajouterCase(base(), 'acc', mot('n', 0, 0, lib: 'neuf'));
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'n');
    expect((c.ligne, c.colonne), (1, 0));
  });

  test('REQ015_AC1 ajouter sur un emplacement choisi', () {
    final d = ajouterCase(base(), 'acc', mot('n', 0, 0), ligne: 1, colonne: 1);
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'n');
    expect((c.ligne, c.colonne), (1, 1));
  });

  test('REQ015_AC1 emplacement occupé ou hors taille : refusé', () {
    expectErreur(
      () => ajouterCase(base(), 'acc', mot('n', 0, 0), ligne: 0, colonne: 0),
      CodeErreurEdition.emplacementInvalide,
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', mot('n', 0, 0), ligne: 2, colonne: 0),
      CodeErreurEdition.emplacementInvalide,
    );
  });

  test('REQ015_AC1 grille inexistante, id déjà utilisé : refusé', () {
    expectErreur(
      () => ajouterCase(base(), 'nope', mot('n', 0, 0)),
      CodeErreurEdition.grilleIntrouvable,
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', mot('a', 0, 0)),
      CodeErreurEdition.idDejaUtilise,
    );
  });

  test('REQ015_AC1 grille visible pleine : « Agrandissez la grille »', () {
    final d = base(
      lignes: 1,
      colonnes: 2,
      cases: [mot('a', 0, 0), mot('b', 0, 1), mot('cachee', 1, 0)],
    );
    expectErreur(
      () => ajouterCase(d, 'acc', mot('n', 0, 0)),
      CodeErreurEdition.grillePleine,
    );
  });

  test('REQ015_AC1 modifier une case', () {
    final d = modifierCase(
      base(),
      'acc',
      mot('a', 0, 0).copyWith(
        libelle: 'bonjour',
        textePrononce: 'salut',
        couleur: () => 0xFFC8E6C9,
        image: const ImageArasaac(5),
      ),
    );
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'a');
    expect(c.libelle, 'bonjour');
    expect(c.textePrononce, 'salut');
    expect(c.couleur, 0xFFC8E6C9);
    expect(c.image, const ImageArasaac(5));
    expect((c.ligne, c.colonne), (0, 0));
  });

  test('REQ015_AC1 modifier : la position ne change pas, case inconnue', () {
    final d = modifierCase(base(), 'acc', mot('a', 1, 1, lib: 'z'));
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'a');
    expect((c.ligne, c.colonne), (0, 0));
    expectErreur(
      () => modifierCase(base(), 'acc', mot('zz', 0, 0)),
      CodeErreurEdition.caseIntrouvable,
    );
  });

  test('REQ015_AC2 ni image ni libellé : refusé', () {
    final vide = Case(id: 'v', ligne: 0, colonne: 0, type: TypeCase.mot);
    expectErreur(
      () => ajouterCase(base(), 'acc', vide),
      CodeErreurEdition.contenuVide,
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', vide.copyWith(libelle: '   ')),
      CodeErreurEdition.contenuVide,
    );
    expectErreur(
      () => modifierCase(base(), 'acc', vide.copyWith(id: 'a', libelle: '')),
      CodeErreurEdition.contenuVide,
    );
  });

  test('REQ015_AC2 image seule ou libellé seul : accepté', () {
    final img = Case(
      id: 'i',
      ligne: 0,
      colonne: 0,
      type: TypeCase.mot,
      image: const ImagePhoto('x.jpg'),
    );
    expect(ajouterCase(base(), 'acc', img).grillePar('acc')!.cases.length, 3);
  });

  test('REQ015_AC3 supprimer une case', () {
    final d = supprimerCase(base(), 'acc', 'a');
    expect(d.grillePar('acc')!.cases.map((c) => c.id), ['b']);
    expectErreur(
      () => supprimerCase(base(), 'acc', 'zz'),
      CodeErreurEdition.caseIntrouvable,
    );
  });

  test('REQ015_AC6 échanger : vers un emplacement vide', () {
    final d = echangerEmplacements(base(), 'acc', 'a', 1, 1);
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'a');
    expect((c.ligne, c.colonne), (1, 1));
  });

  test('REQ015_AC6 échanger : avec une case occupée', () {
    final d = echangerEmplacements(base(), 'acc', 'a', 0, 1);
    final cs = d.grillePar('acc')!.cases;
    final a = cs.firstWhere((c) => c.id == 'a');
    final b = cs.firstWhere((c) => c.id == 'b');
    expect((a.ligne, a.colonne), (0, 1));
    expect((b.ligne, b.colonne), (0, 0));
  });

  test('REQ015_AC6 échanger : hors taille ou case inconnue', () {
    expectErreur(
      () => echangerEmplacements(base(), 'acc', 'a', 5, 0),
      CodeErreurEdition.emplacementInvalide,
    );
    expectErreur(
      () => echangerEmplacements(base(), 'acc', 'zz', 1, 1),
      CodeErreurEdition.caseIntrouvable,
    );
  });

  test('REQ016_AC1 cibles proposées : toutes sauf la courante', () {
    expect(ciblesProposees(base(), 'acc').map((g) => g.id), ['g2', 'g3']);
    expect(ciblesProposees(base(), 'g2').map((g) => g.id), ['acc', 'g3']);
  });

  test('REQ016_AC1 dossier vers une grille existante', () {
    final dos = Case(
      id: 'd',
      ligne: 0,
      colonne: 0,
      type: TypeCase.dossier,
      libelle: 'Dos',
      cibleId: 'g2',
    );
    final d = ajouterCase(base(), 'acc', dos);
    expect(d.grillePar('acc')!.cases.any((c) => c.id == 'd'), isTrue);
  });

  test('REQ016_AC1 dossier vers la grille courante ou inconnue : refusé', () {
    Case dos(String? cible) => Case(
      id: 'd',
      ligne: 0,
      colonne: 0,
      type: TypeCase.dossier,
      libelle: 'Dos',
      cibleId: cible,
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', dos('acc')),
      CodeErreurEdition.cibleManquante,
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', dos('nope')),
      CodeErreurEdition.cibleManquante,
    );
  });

  test('REQ016_AC2 nouvelle grille nommée comme la case, 4x4, vide', () {
    final g = nouvelleGrillePourDossier('Animaux', 'gn');
    expect((g.id, g.nom, g.lignes, g.colonnes), ('gn', 'Animaux', 4, 4));
    expect(g.cases, isEmpty);
  });

  test('REQ016_AC2 enregistrer avec nouvelle grille : créée et liée', () {
    final dos = Case(
      id: 'd',
      ligne: 0,
      colonne: 0,
      type: TypeCase.dossier,
      libelle: 'Animaux',
    );
    final d = ajouterCase(
      base(),
      'acc',
      dos,
      nouvelleGrille: nouvelleGrillePourDossier('Animaux', 'gn'),
    );
    expect(d.grillePar('gn')!.nom, 'Animaux');
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'd');
    expect(c.cibleId, 'gn');
  });

  test('REQ016_AC2 refus : la nouvelle grille n\'est pas créée', () {
    final dos = Case(id: 'd', ligne: 0, colonne: 0, type: TypeCase.dossier);
    expectErreur(
      () => ajouterCase(
        base(),
        'acc',
        dos,
        nouvelleGrille: nouvelleGrillePourDossier('x', 'gn'),
      ),
      CodeErreurEdition.contenuVide,
    );
  });

  test('REQ016_AC3 dossier sans cible : refusé', () {
    final dos = Case(
      id: 'd',
      ligne: 0,
      colonne: 0,
      type: TypeCase.dossier,
      libelle: 'Dos',
    );
    expectErreur(
      () => ajouterCase(base(), 'acc', dos),
      CodeErreurEdition.cibleManquante,
    );
    expectErreur(
      () => modifierCase(base(), 'acc', dos.copyWith(id: 'a')),
      CodeErreurEdition.cibleManquante,
    );
  });

  test('REQ016 un mot n\'a pas de cible enregistrée', () {
    final m = mot('n', 0, 0).copyWith(cibleId: () => 'g2');
    final d = ajouterCase(base(), 'acc', m);
    final c = d.grillePar('acc')!.cases.firstWhere((c) => c.id == 'n');
    expect(c.cibleId, isNull);
  });

  test('REQ001_AC4 modifier et supprimer une case d\'exemple', () {
    final d = modifierCase(base(), 'acc', mot('a', 0, 0, lib: 'changé'));
    expect(d.grillePar('acc')!.cases.first.libelle, 'changé');
    expect(supprimerCase(d, 'acc', 'a').grillePar('acc')!.cases.length, 1);
  });

  test('les données d\'origine ne sont pas modifiées', () {
    final d = base();
    supprimerCase(d, 'acc', 'a');
    expect(d.grillePar('acc')!.cases.length, 2);
  });
}
