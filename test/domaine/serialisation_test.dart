import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/serialisation.dart';

Donnees exemple() => Donnees(
  accueilId: 'acc',
  reglages: const Reglages(
    voixId: 'fr-1',
    debit: 0.7,
    hauteur: 1.2,
    volume: 0.5,
    delaiAntiRepetitionMs: 0,
    retourAccueilApresMot: true,
  ),
  grilles: [
    Grille(
      id: 'acc',
      nom: 'Accueil',
      lignes: 3,
      colonnes: 2,
      cases: const [
        Case(
          id: 'a',
          ligne: 0,
          colonne: 0,
          type: TypeCase.mot,
          libelle: 'WC',
          textePrononce: 'je veux aller aux toilettes',
          image: ImageArasaac(42),
          couleur: 0xFF00FF00,
        ),
        Case(
          id: 'b',
          ligne: 5,
          colonne: 6,
          type: TypeCase.dossier,
          libelle: 'Manger',
          image: ImagePhoto('p1.jpg'),
          cibleId: 'm',
        ),
        Case(id: 'c', ligne: 1, colonne: 1, type: TypeCase.mot),
      ],
    ),
    Grille(id: 'm', nom: 'Manger', lignes: 4, colonnes: 4),
  ],
);

Map<String, Object?> json() =>
    jsonDecode(jsonEncode(donneesVersJson(exemple()))) as Map<String, Object?>;

void main() {
  test('REQ025_AC1 aller-retour a l\'identique', () {
    final texte = jsonEncode(donneesVersJson(exemple()));
    final relu = donneesDepuisJson(jsonDecode(texte));
    expect(jsonEncode(donneesVersJson(relu)), texte);
    final c = relu.grilles.first.cases.first;
    expect(c, exemple().grilles.first.cases.first);
    expect(relu.grilles.first.cases[1].image, const ImagePhoto('p1.jpg'));
    expect(relu.reglages.voixId, 'fr-1');
    expect(relu.grilles.first.lignes, 3);
    expect(relu.grilles.first.cases.length, 3);
  });

  test('REQ018_AC4 la taille est serialisee par grille', () {
    final relu = donneesDepuisJson(json());
    expect(relu.grillePar('acc')!.colonnes, 2);
    expect(relu.grillePar('m')!.lignes, 4);
  });

  test('id d\'accueil absent -> FormatInvalide', () {
    final j = json()..['accueilId'] = 'inconnu';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('positions en double -> FormatInvalide', () {
    final j = json();
    final cases = ((j['grilles']! as List).first as Map)['cases'] as List;
    (cases[2] as Map)['ligne'] = 0;
    (cases[2] as Map)['colonne'] = 0;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('type de case inconnu -> FormatInvalide', () {
    final j = json();
    final cases = ((j['grilles']! as List).first as Map)['cases'] as List;
    (cases[0] as Map)['type'] = 'bizarre';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('image inconnue, version inconnue, taille hors bornes, types faux', () {
    var j = json();
    (((j['grilles']! as List).first as Map)['cases'] as List)[0]['image'] = 'x';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json()..['versionFormat'] = 99;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json();
    ((j['grilles']! as List).first as Map)['lignes'] = 9;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json()..['grilles'] = 'oops';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    expect(() => donneesDepuisJson(42), throwsA(isA<FormatInvalide>()));
    expect(() => donneesDepuisJson(null), throwsA(isA<FormatInvalide>()));
  });

  test('REQ018_AC1 bornes de taille et image arasaac invalide rejetees', () {
    for (final (cle, v) in [('lignes', 0), ('colonnes', 0), ('colonnes', 9)]) {
      final j = json();
      ((j['grilles']! as List).first as Map)[cle] = v;
      expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    }
    final j = json();
    (((j['grilles']! as List).first as Map)['cases'] as List)[0]['image'] =
        'arasaac:abc';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  Map<dynamic, dynamic> caseJson(Map<String, Object?> j, int i) =>
      (((j['grilles']! as List).first as Map)['cases'] as List)[i] as Map;

  test('id de case en double -> FormatInvalide', () {
    final j = json();
    caseJson(j, 2)['id'] = 'a';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('position negative -> FormatInvalide', () {
    var j = json();
    caseJson(j, 2)['ligne'] = -1;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json();
    caseJson(j, 2)['colonne'] = -3;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('couleur non entiere -> FormatInvalide', () {
    final j = json();
    caseJson(j, 0)['couleur'] = 'rouge';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('photo vide -> FormatInvalide', () {
    final j = json();
    caseJson(j, 1)['image'] = 'photo:';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('grille en double -> FormatInvalide', () {
    final j = json();
    ((j['grilles']! as List)[1] as Map)['id'] = 'acc';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });
}
