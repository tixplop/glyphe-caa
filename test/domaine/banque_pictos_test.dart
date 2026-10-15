import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/banque_pictos.dart';
import 'package:glyphe/domaine/texte_normalise.dart';

void main() {
  final banque = BanquePictos.depuisJson(
    jsonEncode([
      {
        'id': 1,
        'motsCles': ['école'],
      },
      {
        'id': 2,
        'motsCles': ['petite école maternelle'],
      },
      {
        'id': 3,
        'motsCles': ['écoles'],
      },
      {
        'id': 4,
        'motsCles': ['chien', 'toutou'],
      },
      {
        'id': 5,
        'motsCles': ['Chien de berger'],
      },
    ]),
  );
  List<int> ids(String t) => [for (final p in banque.rechercher(t)) p.id];

  test('normalisation', () {
    expect(normaliserTexte('  Été   À  l\'ÉCOLE '), 'ete a l\'ecole');
  });

  test('REQ019_AC2 ecole trouve école', () {
    expect(ids('ecole'), contains(1));
    expect(ids('ÉCOLE'), contains(1));
  });

  test('REQ019_AC2 ordre exact, préfixe, contient', () {
    expect(ids('ecole'), [1, 3, 2]);
  });

  test('REQ019_AC2 un picto n apparaît qu une fois, au meilleur rang', () {
    expect(ids('chien'), [4, 5]);
  });

  test('REQ019_AC2 terme vide ou sans résultat', () {
    expect(ids(''), isEmpty);
    expect(ids('   '), isEmpty);
    expect(ids('zzz'), isEmpty);
  });

  test('index invalide -> FormatException', () {
    expect(() => BanquePictos.depuisJson('{}'), throwsFormatException);
    expect(
      () => BanquePictos.depuisJson('[{"id":"a"}]'),
      throwsFormatException,
    );
  });

  test('REQ019_AC1 l index embarqué contient un picto pour chien', () {
    final b = BanquePictos.depuisJson(
      File('assets/arasaac/index.json').readAsStringSync(),
    );
    final r = b.rechercher('chien');
    expect(r, isNotEmpty);
    expect(File('assets/arasaac/${r.first.id}.png').existsSync(), isTrue);
  });

  test('REQ019_AC4 l index est cohérent avec les PNG embarqués', () {
    final b = BanquePictos.depuisJson(
      File('assets/arasaac/index.json').readAsStringSync(),
    );
    expect(b.taille, greaterThan(100));
    final png = Directory('assets/arasaac')
        .listSync()
        .where((f) => f.path.endsWith('.png'))
        .length;
    expect(png, b.taille);
  });

  test('REQ019_AC4 pubspec déclare assets/arasaac/', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/arasaac/'),
    );
  });
}
