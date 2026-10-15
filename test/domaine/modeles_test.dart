import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';

Grille pleine(int n) => Grille(
  id: 'g',
  nom: 'G',
  lignes: n,
  colonnes: n,
  cases: [
    for (var l = 0; l < n; l++)
      for (var c = 0; c < n; c++)
        Case(id: 'c$l$c', ligne: l, colonne: c, type: TypeCase.mot),
  ],
);

void main() {
  test('REQ018_AC2 4x4 reduite a 3x3 : 9 visibles, 16 conservees', () {
    final g = pleine(4).redimensionner(3, 3);
    expect(g.casesVisibles.length, 9);
    expect(g.cases.length, 16);
    expect(g.casesVisibles.every((c) => c.ligne < 3 && c.colonne < 3), isTrue);
  });

  test('REQ018_AC3 retour en 4x4 : 16 cases aux memes positions', () {
    final avant = pleine(4);
    final g = avant.redimensionner(3, 3).redimensionner(4, 4);
    expect(g.casesVisibles.length, 16);
    expect(g.cases, avant.cases);
  });

  test('REQ018_AC1 taille bornee a 1..8', () {
    final g = pleine(2);
    expect(g.redimensionner(0, 99).lignes, 1);
    expect(g.redimensionner(0, 99).colonnes, 8);
    expect(g.redimensionner(8, 1).lignes, 8);
  });

  test('emplacementLibre : premier libre, null si pleine', () {
    expect(pleine(2).emplacementLibre(), isNull);
    final g = Grille(
      id: 'g',
      nom: 'G',
      lignes: 2,
      colonnes: 2,
      cases: [
        const Case(id: 'a', ligne: 0, colonne: 0, type: TypeCase.mot),
        const Case(id: 'b', ligne: 0, colonne: 1, type: TypeCase.mot),
      ],
    );
    expect(g.emplacementLibre(), (ligne: 1, colonne: 0));
    expect(g.redimensionner(1, 2).emplacementLibre(), isNull);
  });

  test(
    'copyWith conserve et remplace, cible annulable, categorie par defaut',
    () {
      const c = Case(
        id: 'a',
        ligne: 0,
        colonne: 0,
        type: TypeCase.dossier,
        categorie: Categorie.objet,
        cibleId: 'x',
      );
      expect(c.copyWith(libelle: 'L').cibleId, 'x');
      expect(c.copyWith(libelle: 'L').categorie, Categorie.objet);
      expect(
        c.copyWith(categorie: Categorie.social).categorie,
        Categorie.social,
      );
      expect(c.copyWith(cibleId: () => null).cibleId, isNull);
      expect(
        const Case(id: 'n', ligne: 0, colonne: 0, type: TypeCase.mot).categorie,
        Categorie.petitMot,
      );
      final d = Donnees(accueilId: 'g', grilles: [pleine(1)]);
      expect(d.copyWith(reglages: const Reglages(debit: 2)).reglages.debit, 2);
      expect(d.versionFormat, 2);
    },
  );

  test('les listes sont immuables', () {
    expect(() => pleine(1).cases.add(pleine(1).cases.first), throwsA(anything));
  });
}
