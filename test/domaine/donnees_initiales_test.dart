import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/donnees_initiales.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/domaine/stockage.dart';

class StockageMemoire implements Stockage {
  Donnees? donnees;
  String? code;
  int ecritures = 0;

  @override
  Future<Donnees?> charger() async => donnees;

  @override
  Future<void> enregistrer(Donnees d) async {
    donnees = d;
    ecritures++;
  }

  @override
  Future<String?> lireCode() async => code;

  @override
  Future<void> ecrireCode(String? c) async => code = c;
}

void main() {
  final json = File('assets/exemples/grilles_exemple.json').readAsStringSync();
  final exemples = donneesDepuisJson(jsonDecode(json));

  Case? cherche(Grille g, String libelle) =>
      g.cases.where((c) => c.libelle == libelle).firstOrNull;

  Grille grilleDossier(Donnees d, Grille depuis, String libelle) {
    final c = cherche(depuis, libelle);
    expect(c, isNotNull, reason: 'case "$libelle" dans ${depuis.nom}');
    expect(c!.type, TypeCase.dossier);
    final cible = d.grillePar(c.cibleId!);
    expect(cible, isNotNull, reason: 'cible de "$libelle"');
    return cible!;
  }

  test(
    'REQ001_AC1 dossiers Besoins, Émotions, Manger, Jouer depuis accueil',
    () {
      final accueil = exemples.grillePar(exemples.accueilId)!;
      for (final nom in ['Besoins', 'Émotions', 'Manger', 'Jouer']) {
        final cible = grilleDossier(exemples, accueil, nom);
        expect(cible.nom, nom);
      }
    },
  );

  test('REQ001_AC2 Manger contient le dossier Fruits avec pomme', () {
    final accueil = exemples.grillePar(exemples.accueilId)!;
    final manger = grilleDossier(exemples, accueil, 'Manger');
    final fruits = grilleDossier(exemples, manger, 'Fruits');
    expect(fruits.nom, 'Fruits');
    final pomme = cherche(fruits, 'pomme');
    expect(pomme, isNotNull);
    expect(pomme!.type, TypeCase.mot);
  });

  test('REQ001_AC3 accueil : mots de base', () {
    final accueil = exemples.grillePar(exemples.accueilId)!;
    for (final m in ['je', 'veux', 'oui', 'non', 'encore', 'fini', 'eau']) {
      final c = cherche(accueil, m);
      expect(c, isNotNull, reason: m);
      expect(c!.type, TypeCase.mot);
    }
  });

  test('REQ001_AC3 chaque case a un libellé et un picto embarqué existant', () {
    final banque = BanquePictos.depuisJson(
      File('assets/arasaac/index.json').readAsStringSync(),
    );
    final ids = {
      for (final m in jsonDecode(
        File('assets/arasaac/index.json').readAsStringSync(),
      ) as List)
        (m as Map)['id'] as int,
    };
    expect(banque.taille, ids.length);
    for (final g in exemples.grilles) {
      expect(g.lignes, 4, reason: g.nom);
      expect(g.colonnes, 4, reason: g.nom);
      expect(g.cases, isNotEmpty);
      for (final c in g.cases) {
        expect(c.libelle.trim(), isNotEmpty, reason: '${g.id}/${c.id}');
        expect(c.image, isA<ImageArasaac>(), reason: '${g.id}/${c.libelle}');
        final id = (c.image as ImageArasaac).id;
        expect(ids, contains(id), reason: '${g.id}/${c.libelle}');
        expect(
          File('assets/arasaac/$id.png').existsSync(),
          isTrue,
          reason: 'PNG $id',
        );
      }
    }
  });

  test(
    'REQ001_AC3 cibles de dossier existantes, grilles toutes atteignables',
    () {
      final atteintes = <String>{exemples.accueilId};
      for (final g in exemples.grilles) {
        for (final c in g.cases) {
          if (c.type == TypeCase.dossier) {
            expect(
              exemples.grillePar(c.cibleId ?? ''),
              isNotNull,
              reason: c.id,
            );
            atteintes.add(c.cibleId!);
          }
        }
      }
      expect(atteintes, {for (final g in exemples.grilles) g.id});
    },
  );

  test('REQ001_AC5 premier lancement : exemples enregistrés', () async {
    final s = StockageMemoire();
    final d = await chargerOuInitialiser(s, json);
    expect(s.donnees, isNotNull);
    expect(d.accueilId, exemples.accueilId);
    expect(d.grilles.length, exemples.grilles.length);
    expect(s.ecritures, 1);
  });

  test('REQ001_AC5 lancement suivant : modifications conservées', () async {
    final s = StockageMemoire();
    final d = await chargerOuInitialiser(s, json);
    final accueil = d.grillePar(d.accueilId)!;
    final modifie = d.copyWith(
      grilles: [
        for (final g in d.grilles)
          if (g.id == accueil.id) g.copyWith(nom: 'Modifié') else g,
      ],
    );
    await s.enregistrer(modifie);
    final ecrit = s.ecritures;
    final d2 = await chargerOuInitialiser(s, json);
    expect(d2.grillePar(d2.accueilId)!.nom, 'Modifié');
    expect(s.ecritures, ecrit);
  });

  test(
    'JSON d\'exemples invalide : erreur explicite, rien enregistré',
    () async {
      final s = StockageMemoire();
      await expectLater(
        chargerOuInitialiser(s, '{"x":1}'),
        throwsA(isA<FormatInvalide>()),
      );
      expect(s.donnees, isNull);
    },
  );
}
