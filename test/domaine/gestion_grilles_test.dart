import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/edition.dart';
import 'package:glyphe/domaine/modeles.dart';

Case mot(String id, int l, int c) =>
    Case(id: id, ligne: l, colonne: c, type: TypeCase.mot, libelle: id);

Donnees base() => Donnees(
  accueilId: 'acc',
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 4,
      colonnes: 4,
      cases: const [
        Case(
          id: 'd',
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
          for (var c = 0; c < 4; c++) mot('m$l$c', l, c),
      ],
    ),
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
  test('REQ017_AC1 renommer une grille, accueil compris', () {
    var d = renommerGrille(base(), 'man', '  Repas ');
    expect(d.grillePar('man')!.nom, 'Repas');
    expect(d.grillePar('man')!.cases, hasLength(16));
    d = renommerGrille(d, 'acc', 'Maison');
    expect(d.grillePar('acc')!.nom, 'Maison');
    expect(d.accueilId, 'acc');
  });

  test('REQ017_AC1 nom vide ou inconnu refusé', () {
    expectErreur(
      () => renommerGrille(base(), 'man', '   '),
      CodeErreurEdition.nomInvalide,
    );
    expectErreur(
      () => renommerGrille(base(), 'zzz', 'x'),
      CodeErreurEdition.grilleIntrouvable,
    );
  });

  test('REQ017_AC2 supprimer : grille disparue, dossier orphelin', () {
    final d = supprimerGrille(base(), 'man');
    expect(d.grillePar('man'), isNull);
    final dossier = d.grillePar('acc')!.cases.single;
    expect(dossier.cibleId, 'man');
    expect(d.grillePar(dossier.cibleId!), isNull);
  });

  test('REQ017_AC3 la grille d\'accueil n\'est pas supprimable', () {
    expectErreur(
      () => supprimerGrille(base(), 'acc'),
      CodeErreurEdition.accueilNonSupprimable,
    );
    expectErreur(
      () => supprimerGrille(base(), 'zzz'),
      CodeErreurEdition.grilleIntrouvable,
    );
  });

  test('REQ018_AC2/AC3 4x4 -> 3x3 masque 7 cases, retour 4x4 les rend', () {
    final r = redimensionnerGrille(base(), 'man', 3, 3);
    final g = r.grillePar('man')!;
    expect(r.grillePar('acc')!.lignes, 4);
    expect(r.grillePar('acc')!.colonnes, 4);
    expect(r.grillePar('acc')!.cases, base().grillePar('acc')!.cases);
    expect(g.casesVisibles, hasLength(9));
    expect(g.cases, hasLength(16));
    final v = redimensionnerGrille(r, 'man', 4, 4).grillePar('man')!;
    expect(v.casesVisibles, hasLength(16));
    expect(
      v.cases.map((c) => (c.id, c.ligne, c.colonne)),
      base().grillePar('man')!.cases.map((c) => (c.id, c.ligne, c.colonne)),
    );
  });

  test('REQ018_AC1 taille hors 1..8 refusée', () {
    for (final (l, c) in [(0, 3), (3, 0), (9, 3), (3, 9), (-1, 2)]) {
      expectErreur(
        () => redimensionnerGrille(base(), 'man', l, c),
        CodeErreurEdition.tailleInvalide,
      );
    }
    final g = redimensionnerGrille(base(), 'man', 1, 8).grillePar('man')!;
    expect((g.lignes, g.colonnes), (1, 8));
    expectErreur(
      () => redimensionnerGrille(base(), 'zzz', 3, 3),
      CodeErreurEdition.grilleIntrouvable,
    );
  });
}
