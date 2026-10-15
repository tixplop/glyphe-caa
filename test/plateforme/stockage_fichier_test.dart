import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/plateforme/stockage_fichier.dart';

Donnees pleine4() => Donnees(
  accueilId: 'g',
  grilles: [
    Grille(
      id: 'g',
      nom: 'G',
      lignes: 4,
      colonnes: 4,
      cases: [
        for (var l = 0; l < 4; l++)
          for (var c = 0; c < 4; c++)
            Case(
              id: 'c$l$c',
              ligne: l,
              colonne: c,
              type: TypeCase.mot,
              libelle: 'm$l$c',
            ),
      ],
    ),
  ],
);

void main() {
  late Directory tmp;
  late StockageFichier stockage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('glyphe_test');
    stockage = StockageFichier(Directory('${tmp.path}/data'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('charger sans fichier -> null', () async {
    expect(await stockage.charger(), isNull);
  });

  test('REQ025_AC1 aller-retour via fichier, nouveau stockage', () async {
    await stockage.enregistrer(pleine4());
    final relu = await StockageFichier(stockage.dossier).charger();
    expect(relu, isNotNull);
    expect(relu!.grilles.single.cases.length, 16);
    expect(relu.grilles.single.cases[5].libelle, 'm11');
    expect(Directory('${stockage.dossier.path}/photos').existsSync(), isTrue);
  });

  test(
    'REQ025_AC2 ecriture via .tmp puis renommage, orphelin ignore',
    () async {
      await stockage.enregistrer(pleine4());
      final dir = stockage.dossier.path;
      expect(File('$dir/glyphe.json.tmp').existsSync(), isFalse);
      File('$dir/glyphe.json.tmp').writeAsStringSync('{ corrompu');
      final relu = await stockage.charger();
      expect(relu!.grilles.single.cases.length, 16);
      // Une nouvelle écriture remplace l'orphelin.
      await stockage.enregistrer(pleine4());
      expect(File('$dir/glyphe.json.tmp').existsSync(), isFalse);
    },
  );

  test(
    'REQ025_AC2 echec d\'ecriture du .tmp : le fichier principal reste',
    () async {
      final a = pleine4();
      await stockage.enregistrer(a);
      final avant = File('${stockage.dossier.path}/glyphe.json')
          .readAsStringSync();
      // Un DOSSIER glyphe.json.tmp fait échouer l'écriture temporaire.
      Directory('${stockage.dossier.path}/glyphe.json.tmp').createSync();
      final b = a.copyWith(
        accueilId: 'g',
        grilles: [a.grilles.single.copyWith(nom: 'B')],
      );
      await expectLater(
        stockage.enregistrer(b),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        File('${stockage.dossier.path}/glyphe.json').readAsStringSync(),
        avant,
      );
      final relu = await stockage.charger();
      expect(relu!.grilles.single.nom, 'G');
    },
  );

  test(
    'REQ025_AC2 glyphe.json existe (contenu A) au moment du renommage',
    () async {
      final a = pleine4();
      await stockage.enregistrer(a);
      final avant = File('${stockage.dossier.path}/glyphe.json')
          .readAsStringSync();
      final appels = <String>[];
      final s = StockageFichier(
        stockage.dossier,
        renommer: (source, cible) async {
          appels.add(cible);
          expect(File(cible).readAsStringSync(), avant);
          expect(File(source).existsSync(), isTrue);
          expect(File(source).readAsStringSync(), isNot(avant));
          await File(source).rename(cible);
        },
      );
      await s.enregistrer(
        a.copyWith(grilles: [a.grilles.single.copyWith(nom: 'B')]),
      );
      expect(appels, hasLength(1));
      expect((await s.charger())!.grilles.single.nom, 'B');
    },
  );

  test('ecritures concurrentes serialisees : le dernier gagne', () async {
    final a = pleine4();
    final futurs = [
      for (var i = 0; i < 5; i++)
        stockage.enregistrer(
          a.copyWith(grilles: [a.grilles.single.copyWith(nom: 'N$i')]),
        ),
    ];
    await Future.wait(futurs);
    expect((await stockage.charger())!.grilles.single.nom, 'N4');
    expect(
      File('${stockage.dossier.path}/glyphe.json.tmp').existsSync(),
      isFalse,
    );
  });

  test('une ecriture en echec ne bloque pas les suivantes', () async {
    final a = pleine4();
    await stockage.enregistrer(a);
    Directory('${stockage.dossier.path}/glyphe.json.tmp').createSync();
    final rate = stockage.enregistrer(a);
    await expectLater(rate, throwsA(isA<FileSystemException>()));
    Directory('${stockage.dossier.path}/glyphe.json.tmp').deleteSync();
    await stockage.enregistrer(a);
    expect(await stockage.charger(), isNotNull);
  });

  test('fichier principal illisible -> FormatInvalide', () async {
    await stockage.dossier.create(recursive: true);
    File('${stockage.dossier.path}/glyphe.json').writeAsStringSync('{ pas');
    await expectLater(stockage.charger(), throwsA(isA<FormatInvalide>()));
  });

  test('REQ018_AC4 4x4 -> 3x3 -> 4x4 par persistance', () async {
    await stockage.enregistrer(pleine4());
    var d = (await stockage.charger())!;
    var g = d.grilles.single.redimensionner(3, 3);
    await stockage.enregistrer(d.copyWith(grilles: [g]));
    d = (await stockage.charger())!;
    g = d.grilles.single;
    expect(g.lignes, 3);
    expect(g.casesVisibles.length, 9);
    expect(g.cases.length, 16);
    await stockage.enregistrer(d.copyWith(grilles: [g.redimensionner(4, 4)]));
    g = (await stockage.charger())!.grilles.single;
    expect(g.casesVisibles.length, 16);
    expect(
      g.cases.map((c) => (c.id, c.ligne, c.colonne)),
      pleine4().grilles.single.cases.map((c) => (c.id, c.ligne, c.colonne)),
    );
  });

  test('REQ012_AC4 code dans un fichier distinct', () async {
    expect(await stockage.lireCode(), isNull);
    await stockage.ecrireCode('1234');
    await stockage.enregistrer(pleine4());
    expect(await StockageFichier(stockage.dossier).lireCode(), '1234');
    expect(
      File('${stockage.dossier.path}/glyphe.json').readAsStringSync(),
      isNot(contains('1234')),
    );
    await stockage.ecrireCode(null);
    expect(await stockage.lireCode(), isNull);
    await stockage.ecrireCode(null);
  });

  test('code.txt vide ou blanc -> null', () async {
    await stockage.dossier.create(recursive: true);
    File('${stockage.dossier.path}/code.txt').writeAsStringSync('  \n');
    expect(await stockage.lireCode(), isNull);
  });
}
