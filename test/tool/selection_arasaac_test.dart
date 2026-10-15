import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/selection_arasaac.dart';

void main() {
  final pictos = jsonDecode(
    File('test/fixtures/arasaac_all_fr_extrait.json').readAsStringSync(),
  ) as List<dynamic>;
  List<int> ids(List<Map<String, Object>> r) => [
    for (final e in r) e['id']! as int,
  ];

  test('REQ019_AC4 exclut violence et sex, retient aac', () {
    final r = selectionnerPictos(pictos);
    expect(ids(r), [1, 6, 7]);
  });

  test('REQ019_AC4 produit id et motsCles', () {
    final r = selectionnerPictos(pictos);
    expect(r.first, {
      'id': 1,
      'motsCles': ['chien', 'toutou'],
    });
  });

  test(
    'REQ019_AC4 les mots obligatoires forcent l inclusion (sans accent)',
    () {
      final r = selectionnerPictos(pictos, motsObligatoires: {'ecole'});
      expect(ids(r), [1, 4, 6, 7]);
    },
  );

  test('REQ019_AC4 un mot obligatoire ne réintroduit pas violence/sex', () {
    final r = selectionnerPictos(pictos, motsObligatoires: {'chien', 'nu'});
    expect(ids(r), [1, 6, 7]);
  });

  test('REQ019_AC4 le plafond limite, obligatoires prioritaires', () {
    final r = selectionnerPictos(pictos, plafond: 2);
    expect(ids(r), [1, 6]);
    final r2 = selectionnerPictos(
      pictos,
      motsObligatoires: {'ecole'},
      plafond: 2,
    );
    expect(ids(r2), [4, 6]);
  });

  test('entrées malformées ignorées', () {
    expect(
      selectionnerPictos([
        null,
        3,
        {'_id': 'x'},
        {'_id': 9, 'aac': true},
      ]),
      isEmpty,
    );
  });
}
