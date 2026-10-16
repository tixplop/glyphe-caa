import 'dart:convert';
import 'dart:io';

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
          categorie: Categorie.action,
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

Map<String, Object?> jsonAvecRetour({int version = 3}) {
  final j = json()..['versionFormat'] = version;
  final cases = ((j['grilles']! as List).last as Map)['cases'] as List;
  cases.add({
    'id': 'r1',
    'ligne': 0,
    'colonne': 0,
    'type': 'retour',
    'libelle': 'Retour',
    'textePrononce': '',
    'image': 'aucune',
    'categorie': 'petitMot',
  });
  cases.add({
    'id': 'r2',
    'ligne': 0,
    'colonne': 1,
    'type': 'retour',
    'libelle': '',
    'textePrononce': '',
    'image': 'arasaac:7',
    'categorie': 'petitMot',
  });
  return j;
}

void main() {
  test('REQ037_AC7 aller-retour avec case-retour (avec et sans image)', () {
    final j = jsonAvecRetour();
    final d = donneesDepuisJson(j);
    final cases = d.grillePar('m')!.cases;
    expect(cases.map((c) => c.type), [TypeCase.retour, TypeCase.retour]);
    expect(cases[0].image, const ImageAucune());
    expect(cases[1].image, const ImageArasaac(7));
    expect(cases[0].cibleId, isNull);
    final ecrit = jsonDecode(jsonEncode(donneesVersJson(d))) as Map;
    expect(ecrit['versionFormat'], 3);
    final casesJson = ((ecrit['grilles'] as List).last as Map)['cases'] as List;
    for (final c in casesJson) {
      expect((c as Map).containsKey('cibleId'), isFalse);
    }
    expect(
      jsonEncode(donneesVersJson(donneesDepuisJson(ecrit))),
      jsonEncode(ecrit),
    );
  });

  test('REQ037_AC7 type retour en v1 ou v2 -> FormatInvalide', () {
    for (final v in [1, 2]) {
      expect(
        () => donneesDepuisJson(jsonAvecRetour(version: v)),
        throwsA(isA<FormatInvalide>()),
        reason: 'v$v',
      );
    }
  });

  test('REQ037_AC7 case-retour avec cibleId -> FormatInvalide', () {
    final j = jsonAvecRetour();
    final cases = ((j['grilles']! as List).last as Map)['cases'] as List;
    (cases[0] as Map)['cibleId'] = 'acc';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('REQ037_AC7 case-retour sans categorie -> FormatInvalide', () {
    final j = jsonAvecRetour();
    final cases = ((j['grilles']! as List).last as Map)['cases'] as List;
    (cases[0] as Map).remove('categorie');
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('REQ032_AC4 v2 lue sans perte, versions 0 et 4 refusees', () {
    final v2 = jsonDecode(
      File('test/fixtures/donnees_v2.json').readAsStringSync(),
    );
    final d = donneesDepuisJson(v2);
    expect(d.grilles.expand((g) => g.cases).length, 7);
    expect(
      d.grilles.expand((g) => g.cases).any((c) => c.type == TypeCase.retour),
      isFalse,
    );
    expect(donneesVersJson(d)['versionFormat'], 3);
    for (final v in [0, 4]) {
      expect(
        () => donneesDepuisJson(json()..['versionFormat'] = v),
        throwsA(isA<FormatInvalide>()),
      );
    }
  });

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

  test('REQ032_AC4 categorie ecrite, couleur absente', () {
    final j = json();
    expect(j['versionFormat'], 3);
    expect(caseJson(j, 0)['categorie'], 'action');
    expect(caseJson(j, 0).containsKey('couleur'), isFalse);
  });

  test('REQ032_AC4 toutes les categories font l\'aller-retour', () {
    for (final cat in Categorie.values) {
      final j = json();
      caseJson(j, 0)['categorie'] = cat.name;
      final d = donneesDepuisJson(j);
      expect(d.grilles.first.cases.first.categorie, cat);
    }
  });

  test('REQ032_AC4 categorie absente, inconnue ou non chaine en v2', () {
    var j = json();
    caseJson(j, 0).remove('categorie');
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json();
    caseJson(j, 0)['categorie'] = 'rose';
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
    j = json();
    caseJson(j, 0)['categorie'] = 3;
    expect(() => donneesDepuisJson(j), throwsA(isA<FormatInvalide>()));
  });

  test('REQ032_AC5 table de conversion des couleurs v1', () {
    const attendu = {
      0xFFFFF9C4: Categorie.personne,
      0xFFC8E6C9: Categorie.action,
      0xFFFFCCBC: Categorie.objet,
      0xFFBBDEFB: Categorie.description,
      0xFFB2EBF2: Categorie.description,
      0xFFF8BBD0: Categorie.social,
      0xFFE1BEE7: Categorie.question,
      0xFFD7CCC8: Categorie.petitMot,
      0xFFFFFFFF: Categorie.petitMot,
      0xFF123456: Categorie.petitMot,
    };
    attendu.forEach((couleur, cat) {
      expect(categorieDepuisCouleurV1(couleur), cat, reason: '$couleur');
    });
    expect(categorieDepuisCouleurV1(null), Categorie.petitMot);
  });

  test('REQ032_AC5 lecture v1 : couleurs converties, reste identique', () {
    final v1 = jsonDecode(
      File('test/fixtures/donnees_v1.json').readAsStringSync(),
    );
    final d = donneesDepuisJson(v1);
    expect(d.versionFormat, 3);
    final cases = d.grilles.single.cases;
    expect(cases.map((c) => c.categorie).toList(), [
      Categorie.personne,
      Categorie.action,
      Categorie.objet,
      Categorie.description,
      Categorie.description,
      Categorie.social,
      Categorie.question,
      Categorie.petitMot,
      Categorie.petitMot,
    ]);
    expect(cases[3].libelle, 'm3');
    expect(cases[3].image, const ImageArasaac(2617));
    expect(d.reglages.voixId, 'v1');
    expect(d.reglages.delaiAntiRepetitionMs, 700);
    final reecrit = donneesVersJson(d);
    expect(reecrit['versionFormat'], 3);
  });

  test('v1 : couleur non entiere -> FormatInvalide', () {
    final v1 = jsonDecode(
      File('test/fixtures/donnees_v1.json').readAsStringSync(),
    ) as Map<String, Object?>;
    caseJson(v1, 0)['couleur'] = 'rouge';
    expect(() => donneesDepuisJson(v1), throwsA(isA<FormatInvalide>()));
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
