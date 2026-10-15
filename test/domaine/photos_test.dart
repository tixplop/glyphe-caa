import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/photos.dart';
import 'package:glyphe/domaine/serialisation.dart';

Donnees donneesAvec(List<String> photos) => Donnees(
  accueilId: 'a',
  grilles: [
    Grille(
      id: 'a',
      nom: 'A',
      lignes: 4,
      colonnes: 4,
      cases: [
        for (var i = 0; i < photos.length; i++)
          Case(
            id: 'c$i',
            ligne: 0,
            colonne: i,
            type: TypeCase.mot,
            libelle: 'x',
            image: ImagePhoto(photos[i]),
          ),
      ],
    ),
  ],
);

void main() {
  late Directory racine;
  late Directory dossierPhotos;
  late Photos photos;

  setUp(() {
    racine = Directory.systemTemp.createTempSync('glyphe_photos_');
    dossierPhotos = Directory('${racine.path}/photos');
    photos = Photos(dossierPhotos);
  });
  tearDown(() => racine.deleteSync(recursive: true));

  group('nom de fichier', () {
    test('noms valides', () {
      expect(nomPhotoValide('abc123.jpg'), isTrue);
      expect(nomPhotoValide('ma photo.jpg'), isTrue);
    });
    test('refuse séparateurs, .. et vide', () {
      for (final n in [
        '',
        '.',
        '..',
        'a..b.jpg',
        '../x.jpg',
        'a/b.jpg',
        '/a.jpg',
        r'a\b',
      ]) {
        expect(nomPhotoValide(n), isFalse, reason: n);
      }
    });
  });

  test('résoudre donne un chemin dans le dossier photos', () {
    expect(photos.resoudre('p.jpg'), '${dossierPhotos.path}/p.jpg');
  });

  test('résoudre refuse un nom hors du dossier', () {
    for (final n in ['../glyphe.json', 'a/b.jpg', r'a\b.jpg', '..', '']) {
      expect(() => photos.resoudre(n), throwsArgumentError, reason: n);
    }
  });

  test('le chargement refuse une photo dont le nom sort du dossier', () {
    for (final n in ['../x.jpg', '/etc/passwd', r'a\b.jpg']) {
      final json = donneesVersJson(donneesAvec(['ok.jpg']));
      final texte = json.toString();
      expect(texte, contains('photo:ok.jpg'));
      final modif = {
        ...json,
        'grilles': [
          {
            ...(json['grilles']! as List).first as Map<String, Object?>,
            'cases': [
              {
                ...((((json['grilles']! as List).first as Map)['cases']!
                            as List)
                        .first
                    as Map<String, Object?>),
                'image': 'photo:$n',
              },
            ],
          },
        ],
      };
      expect(
        () => donneesDepuisJson(modif),
        throwsA(isA<FormatInvalide>()),
        reason: n,
      );
    }
  });

  group('REQ020_AC2 import', () {
    test('copie la photo sous un nom unique .jpg dans photos/', () async {
      final source = File('${racine.path}/source.png')
        ..writeAsBytesSync([1, 2, 3]);
      final a = await photos.importer(source.path);
      final b = await photos.importer(source.path);
      expect(a, isNot(b));
      expect(RegExp(r'^[0-9a-f]{32}\.jpg$').hasMatch(a), isTrue);
      expect(nomPhotoValide(a), isTrue);
      final copie = File('${dossierPhotos.path}/$a');
      expect(copie.readAsBytesSync(), [1, 2, 3]);
      expect(source.existsSync(), isTrue);
    });

    test('source inexistante : erreur explicite, rien de créé', () async {
      await expectLater(
        photos.importer('${racine.path}/absente.jpg'),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        !dossierPhotos.existsSync() || dossierPhotos.listSync().isEmpty,
        isTrue,
      );
    });
  });

  group('REQ020_AC4 nettoyage', () {
    test('supprime les fichiers non référencés, garde les autres', () async {
      dossierPhotos.createSync(recursive: true);
      for (final n in ['garde.jpg', 'garde2.jpg', 'orphelin.jpg']) {
        File('${dossierPhotos.path}/$n').writeAsBytesSync([0]);
      }
      await photos.nettoyerPhotosInutilisees(
        donneesAvec(['garde.jpg', 'garde2.jpg']),
      );
      final restants = dossierPhotos.listSync().map(
        (e) => e.uri.pathSegments.last,
      );
      expect(restants.toSet(), {'garde.jpg', 'garde2.jpg'});
    });

    test(
      'deux grilles : photo utilisée seulement dans la seconde gardée',
      () async {
        dossierPhotos.createSync(recursive: true);
        for (final n in ['g2.jpg', 'orphelin.jpg']) {
          File('${dossierPhotos.path}/$n').writeAsBytesSync([0]);
        }
        final d1 = donneesAvec(['g1.jpg']);
        final seconde = donneesAvec(['g2.jpg']).grilles.first;
        final donnees = Donnees(
          accueilId: 'a',
          grilles: [
            d1.grilles.first,
            Grille(
              id: 'b',
              nom: 'B',
              lignes: 4,
              colonnes: 4,
              cases: seconde.cases,
            ),
          ],
        );
        await photos.nettoyerPhotosInutilisees(donnees);
        final restants = dossierPhotos.listSync().map(
          (e) => e.uri.pathSegments.last,
        );
        expect(restants.toSet(), {'g2.jpg'});
      },
    );

    test('photo partagée par deux cases dont une supprimée : gardée', () async {
      dossierPhotos.createSync(recursive: true);
      File('${dossierPhotos.path}/p.jpg').writeAsBytesSync([0]);
      await photos.nettoyerPhotosInutilisees(donneesAvec(['p.jpg', 'p.jpg']));
      expect(dossierPhotos.listSync(), hasLength(1));
      // Une des deux cases supprimée : l'autre référence encore la photo.
      await photos.nettoyerPhotosInutilisees(donneesAvec(['p.jpg']));
      expect(dossierPhotos.listSync(), hasLength(1));
      await photos.nettoyerPhotosInutilisees(donneesAvec([]));
      expect(dossierPhotos.listSync(), isEmpty);
    });

    test('tout est supprimé si plus aucune photo référencée', () async {
      dossierPhotos.createSync(recursive: true);
      File('${dossierPhotos.path}/a.jpg').writeAsBytesSync([0]);
      await photos.nettoyerPhotosInutilisees(donneesAvec([]));
      expect(dossierPhotos.listSync(), isEmpty);
    });

    test('dossier absent : sans erreur', () async {
      await photos.nettoyerPhotosInutilisees(donneesAvec([]));
    });
  });
}
