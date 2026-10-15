import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/onglets.dart';
import 'package:glyphe/domaine/serialisation.dart';

Case dossier(String id, String lib, int l, int c, String? cible) => Case(
  id: id,
  ligne: l,
  colonne: c,
  type: TypeCase.dossier,
  libelle: lib,
  cibleId: cible,
);

Grille grille(String id, String nom, [List<Case> cases = const []]) =>
    Grille(id: id, nom: nom, lignes: 4, colonnes: 4, cases: cases);

Donnees exemples() => donneesDepuisJson(
  jsonDecode(File('assets/exemples/grilles_exemple.json').readAsStringSync()),
);

List<String> ids(Donnees d) => [for (final o in ongletsDe(d)) o.grilleId];

void main() {
  test('REQ031_AC2 onglets des grilles d\'exemple', () {
    final o = ongletsDe(exemples());
    expect(
      [for (final x in o) x.libelle],
      ['Accueil', 'Besoins', 'Émotions', 'Manger', 'Jouer'],
    );
    expect(o.first.estAccueil, isTrue);
    expect(o.skip(1).any((x) => x.estAccueil), isFalse);
  });

  test('REQ031_AC2 ordre ligne puis colonne, sans doublon, cibles valides', () {
    final d = Donnees(
      accueilId: 'a',
      grilles: [
        grille('a', 'Maison', [
          dossier('d3', 'Z', 2, 0, 'z'),
          dossier('d1', 'B', 0, 3, 'b'),
          dossier('d2', 'A', 1, 0, 'a2'),
          dossier('d4', 'Bis', 1, 1, 'b'),
          dossier('d5', 'Perdu', 1, 2, 'nulle'),
          dossier('d6', 'SansCible', 1, 3, null),
          dossier('d7', 'Hors', 0, 9, 'z'),
        ]),
        grille('b', 'Grille B'),
        grille('a2', 'Grille A'),
        grille('z', 'Grille Z'),
      ],
    );
    expect(ids(d), ['a', 'b', 'a2', 'z']);
    expect(ongletsDe(d).first.libelle, 'Maison');
  });

  test('REQ031_AC2 libellé vide : nom de la grille cible', () {
    final d = Donnees(
      accueilId: 'a',
      grilles: [
        grille('a', 'Acc', [dossier('d', '', 0, 0, 'b')]),
        grille('b', 'Boire'),
      ],
    );
    expect(ongletsDe(d)[1].libelle, 'Boire');
  });

  test('REQ031_AC2 une case-dossier pointant vers l\'accueil est ignorée', () {
    final d = Donnees(
      accueilId: 'a',
      grilles: [
        grille('a', 'Acc', [dossier('d', 'Moi', 0, 0, 'a')]),
      ],
    );
    expect(ids(d), ['a']);
  });

  test('REQ031_AC4 onglet actif selon le chemin', () {
    final d = exemples();
    expect(ongletActif(d, ['accueil']), 'accueil');
    expect(ongletActif(d, ['accueil', 'manger']), 'manger');
    expect(ongletActif(d, ['accueil', 'manger', 'fruits']), 'manger');
    expect(ongletActif(d, ['accueil', 'fruits']), isNull);
    expect(ongletActif(d, []), isNull);
  });

  test('REQ031_AC4 chemin finissant sur l\'accueil : onglet Accueil actif', () {
    final d = exemples();
    expect(ongletActif(d, ['accueil', 'manger', 'accueil']), 'accueil');
  });

  test('REQ031_AC4 seul le dernier passage par l\'accueil compte', () {
    final d = exemples();
    expect(
      ongletActif(d, ['accueil', 'manger', 'accueil', 'besoins']),
      'besoins',
    );
    expect(ongletActif(d, ['accueil', 'manger', 'accueil', 'fruits']), isNull);
  });

  test('REQ031_AC6 supprimer la grille cible retire l\'onglet', () {
    final d = exemples();
    final sans = d.copyWith(
      grilles: [
        for (final g in d.grilles)
          if (g.id != 'jouer') g,
      ],
    );
    expect(ids(sans), ['accueil', 'besoins', 'emotions', 'manger']);
  });
}
