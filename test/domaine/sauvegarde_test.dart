import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/sauvegarde.dart';
import 'package:glyphe/domaine/serialisation.dart';
import 'package:glyphe/plateforme/stockage_fichier.dart';

Donnees donneesAvecPhoto(String grille, String photo, {String libelle = 'x'}) =>
    Donnees(
      accueilId: grille,
      grilles: [
        Grille(
          id: grille,
          nom: 'Grille $grille',
          lignes: 2,
          colonnes: 2,
          cases: [
            Case(
              id: 'c1',
              ligne: 0,
              colonne: 0,
              type: TypeCase.mot,
              libelle: libelle,
              image: ImagePhoto(photo),
            ),
            Case(
              id: 'c2',
              ligne: 0,
              colonne: 1,
              type: TypeCase.mot,
              libelle: 'arasaac',
              image: const ImageArasaac(42),
            ),
          ],
        ),
      ],
      reglages: const Reglages(
        voixId: 'v1',
        delaiAntiRepetitionMs: 900,
        retourAccueilApresMot: false,
      ),
    );

Uint8List zip(List<ArchiveFile> fichiers) {
  final a = Archive();
  fichiers.forEach(a.addFile);
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

ArchiveFile entree(String nom, List<int> contenu) =>
    ArchiveFile(nom, contenu.length, contenu);

ArchiveFile json(Donnees d) =>
    entree('glyphe.json', utf8.encode(jsonEncode(donneesVersJson(d))));

ArchiveFile jsonBrut(Object o) =>
    entree('glyphe.json', utf8.encode(jsonEncode(o)));

void expectInvalide(ResultatAnalyse r) {
  expect(r, isA<ErreurSauvegarde>());
  expect((r as ErreurSauvegarde).motif, MotifErreur.invalide);
}

/// Applique [f] a chaque en-tete du repertoire central de [z].
void patcherCentral(Uint8List z, void Function(ByteData bd, int debut) f) {
  final bd = ByteData.view(z.buffer);
  for (var i = 0; i + 46 < z.length; i++) {
    if (bd.getUint32(i, Endian.little) == 0x02014b50) f(bd, i);
  }
}

/// Instantané du dossier de données (chemins relatifs -> contenu).
Map<String, String> instantane(Directory d) {
  final m = <String, String>{};
  for (final e in d.listSync(recursive: true, followLinks: false)) {
    final rel = e.path.substring(d.path.length);
    m[rel] = e is File ? base64Encode(e.readAsBytesSync()) : '<dir>';
  }
  return m;
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('glyphe_sauv'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('export', () {
    test('REQ023_AC1 archive avec glyphe.json et photos/', () {
      final photos = Directory('${tmp.path}/photos')..createSync();
      File('${photos.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
      File('${photos.path}/inutile.jpg').writeAsBytesSync([9]);
      final octets = exporter(donneesAvecPhoto('g', 'a.jpg'), photos);
      final noms = ZipDecoder().decodeBytes(octets).files.map((f) => f.name);
      expect(noms, unorderedEquals(['glyphe.json', 'photos/a.jpg']));
    });

    test('REQ023_AC1 les reglages sont dans le fichier', () {
      final photos = Directory('${tmp.path}/photos')..createSync();
      File('${photos.path}/a.jpg').writeAsBytesSync([1]);
      final octets = exporter(donneesAvecPhoto('g', 'a.jpg'), photos);
      final r = analyserSauvegarde(octets) as SauvegardeValide;
      expect(r.donnees.reglages.voixId, 'v1');
      expect(r.donnees.reglages.delaiAntiRepetitionMs, 900);
      expect(r.donnees.reglages.retourAccueilApresMot, isFalse);
    });

    test('REQ023_AC2 numero de version de format present', () {
      final photos = Directory('${tmp.path}/photos')..createSync();
      File('${photos.path}/a.jpg').writeAsBytesSync([1]);
      final a = ZipDecoder().decodeBytes(
        exporter(donneesAvecPhoto('g', 'a.jpg'), photos),
      );
      final j = jsonDecode(
        utf8.decode(a.files.firstWhere((f) => f.name == 'glyphe.json').content),
      );
      expect(j['versionFormat'], 3);
      expect(versionFormatCourant, 3);
    });

    test('REQ023_AC3 le code de deverrouillage est absent de l\'archive', () {
      final dossier = Directory('${tmp.path}/data')..createSync();
      File('${dossier.path}/code.txt').writeAsStringSync('48151623');
      final photos = Directory('${dossier.path}/photos')..createSync();
      File('${photos.path}/a.jpg').writeAsBytesSync([1]);
      final octets = exporter(donneesAvecPhoto('g', 'a.jpg'), photos);
      final a = ZipDecoder().decodeBytes(octets);
      expect(a.files.any((f) => f.name.contains('code')), isFalse);
      for (final f in a.files) {
        expect(
          utf8.decode(f.content, allowMalformed: true),
          isNot(contains('48151623')),
        );
      }
    });

    test('photo referencee absente : erreur explicite', () {
      final photos = Directory('${tmp.path}/photos')..createSync();
      expect(
        () => exporter(donneesAvecPhoto('g', 'absente.jpg'), photos),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('REQ023_AC1 nom du fichier d\'export', () {
      expect(
        nomFichierExport(DateTime(2026, 3, 7)),
        'glyphe-sauvegarde-20260307.zip',
      );
      expect(
        nomFichierExport(DateTime(2026, 12, 31)),
        'glyphe-sauvegarde-20261231.zip',
      );
    });
  });

  group('analyse : cas invalides (AC-024-4)', () {
    final d = donneesAvecPhoto('g', 'a.jpg');
    test('REQ024_AC4 pas un ZIP', () {
      expectInvalide(analyserSauvegarde(utf8.encode('ceci n\'est pas un zip')));
      expectInvalide(analyserSauvegarde(<int>[]));
    });
    test('REQ024_AC4 ZIP tronque', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', [1, 2, 3]),
      ]);
      expectInvalide(analyserSauvegarde(z.sublist(0, z.length ~/ 2)));
    });
    test('REQ024_AC4 JSON illisible', () {
      expectInvalide(
        analyserSauvegarde(
          zip([entree('glyphe.json', utf8.encode('{ pas du json'))]),
        ),
      );
      expectInvalide(
        analyserSauvegarde(
          zip([
            entree('glyphe.json', [0xff, 0xfe, 0xfd]),
          ]),
        ),
      );
    });
    test('REQ024_AC4 glyphe.json absent', () {
      expectInvalide(
        analyserSauvegarde(
          zip([
            entree('photos/a.jpg', [1]),
          ]),
        ),
      );
    });
    test('REQ024_AC4 donnees incoherentes', () {
      final j = donneesVersJson(d);
      j['accueilId'] = 'inconnue';
      expectInvalide(
        analyserSauvegarde(
          zip([
            jsonBrut(j),
            entree('photos/a.jpg', [1]),
          ]),
        ),
      );
      expectInvalide(
        analyserSauvegarde(
          zip([
            jsonBrut([1, 2]),
          ]),
        ),
      );
      expectInvalide(
        analyserSauvegarde(
          zip([
            jsonBrut({'versionFormat': 'un'}),
          ]),
        ),
      );
    });
    test('REQ024_AC4 version de format inferieure a 1 ou absente', () {
      final j = donneesVersJson(d)..['versionFormat'] = 0;
      expectInvalide(
        analyserSauvegarde(
          zip([
            jsonBrut(j),
            entree('photos/a.jpg', [1]),
          ]),
        ),
      );
    });
    test('REQ024_AC4 photo referencee absente', () {
      expectInvalide(analyserSauvegarde(zip([json(d)])));
      expectInvalide(
        analyserSauvegarde(
          zip([
            json(d),
            entree('photos/autre.jpg', [1]),
          ]),
        ),
      );
    });
    test('CRC corrompu : un octet des donnees compressees modifie', () {
      final z = zip([json(d), entree('photos/a.jpg', List.filled(50, 7))]);
      final nom = utf8.encode('photos/a.jpg');
      var debut = -1;
      for (var i = 0; i + nom.length <= z.length && debut < 0; i++) {
        if (z[i] == 0x50 &&
            z[i + 1] == 0x4b &&
            z[i + 2] == 3 &&
            z[i + 3] == 4) {
          final bd = ByteData.view(z.buffer);
          final n = bd.getUint16(i + 26, Endian.little);
          if (utf8.decode(z.sublist(i + 30, i + 30 + n)) == 'photos/a.jpg') {
            debut = i + 30 + n + bd.getUint16(i + 28, Endian.little);
          }
        }
      }
      expect(debut, greaterThan(0));
      z[debut] ^= 0xFF;
      expectInvalide(analyserSauvegarde(z));
    });
    test('REQ024_AC8 une sauvegarde v1 est importee, couleurs converties', () {
      final v1 = jsonDecode(
        File('test/fixtures/donnees_v1.json').readAsStringSync(),
      );
      final r = analyserSauvegarde(zip([jsonBrut(v1 as Object)]));
      expect(r, isA<SauvegardeValide>());
      final cases = (r as SauvegardeValide).donnees.grilles.single.cases;
      expect(cases[0].categorie, Categorie.personne);
      expect(cases[5].categorie, Categorie.social);
      expect(cases[7].categorie, Categorie.petitMot);
      expect(cases[2].libelle, 'm2');
    });
    test('REQ024_AC8 une sauvegarde v2 est importee a l\'identique', () {
      final v2 = jsonDecode(
        File('test/fixtures/donnees_v2.json').readAsStringSync(),
      );
      final r = analyserSauvegarde(
        zip([
          jsonBrut(v2 as Object),
          entree('photos/a.jpg', [1]),
        ]),
      );
      expect(r, isA<SauvegardeValide>());
      final donnees = (r as SauvegardeValide).donnees;
      final cases = donnees.grilles.expand((g) => g.cases).toList();
      expect(cases.length, 7);
      expect(cases.any((c) => c.type == TypeCase.retour), isFalse);
      final sortie = donneesVersJson(donnees);
      final attendu = Map<String, Object?>.of(v2 as Map<String, Object?>)
        ..['versionFormat'] = 3;
      expect(jsonEncode(sortie), jsonEncode(attendu));
    });
    test('REQ024_AC5 version 4 refusee, version 3 acceptee', () {
      final j = donneesVersJson(d);
      expect(j['versionFormat'], 3);
      expect(
        analyserSauvegarde(
          zip([
            jsonBrut(j),
            entree('photos/a.jpg', [1]),
          ]),
        ),
        isA<SauvegardeValide>(),
      );
      j['versionFormat'] = 4;
      final r = analyserSauvegarde(zip([jsonBrut(j)]));
      expect((r as ErreurSauvegarde).motif, MotifErreur.tropRecente);
    });
    test('REQ024_AC5 version trop recente', () {
      final j = donneesVersJson(d)
        ..['versionFormat'] = versionFormatCourant + 1;
      final r = analyserSauvegarde(
        zip([
          jsonBrut(j),
          entree('photos/a.jpg', [1]),
        ]),
      );
      expect((r as ErreurSauvegarde).motif, MotifErreur.tropRecente);
    });
    test('version trop recente meme si le reste du JSON est inconnu', () {
      final r = analyserSauvegarde(
        zip([
          jsonBrut({'versionFormat': 99, 'futur': true}),
        ]),
      );
      expect((r as ErreurSauvegarde).motif, MotifErreur.tropRecente);
    });
  });

  group('analyse : securite de l\'archive', () {
    final d = donneesAvecPhoto('g', 'a.jpg');
    ResultatAnalyse avecEntree(ArchiveFile extra) => analyserSauvegarde(
      zip([
        json(d),
        entree('photos/a.jpg', [1]),
        extra,
      ]),
    );

    test('base : archive saine valide', () {
      expect(
        analyserSauvegarde(
          zip([
            json(d),
            entree('photos/a.jpg', [1]),
          ]),
        ),
        isA<SauvegardeValide>(),
      );
    });
    test('chemin absolu', () {
      expectInvalide(avecEntree(entree('/etc/passwd', [1])));
      expectInvalide(avecEntree(entree('/photos/b.jpg', [1])));
    });
    test('traversee ..', () {
      expectInvalide(avecEntree(entree('photos/../glyphe.json', [1])));
      expectInvalide(avecEntree(entree('../evil.jpg', [1])));
      expectInvalide(avecEntree(entree('photos/..', [1])));
      expectInvalide(avecEntree(entree('photos/../../x', [1])));
    });
    test('antislash', () {
      final f = entree('photos/b.jpg', [1])..name = r'photos\b.jpg';
      expectInvalide(avecEntree(f));
      final g = entree('photos/b.jpg', [1])..name = r'photos\..\x.jpg';
      expectInvalide(avecEntree(g));
    });
    test('nom de photo invalide', () {
      expectInvalide(avecEntree(entree('photos/a/b.jpg', [1])));
      expectInvalide(avecEntree(entree('photos/a..jpg', [1])));
      expectInvalide(avecEntree(entree('photos/.', [1])));
    });
    test('entree hors glyphe.json et photos/', () {
      expectInvalide(avecEntree(entree('code.txt', [1])));
      expectInvalide(avecEntree(entree('autre/b.jpg', [1])));
    });
    test('entree en double', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', [1]),
        entree('photos/b.jpg', [2]),
      ]);
      // Renomme b.jpg en a.jpg (meme longueur) dans tous les en-tetes.
      final cible = utf8.encode('photos/b.jpg');
      for (var i = 0; i + cible.length <= z.length; i++) {
        var egal = true;
        for (var j = 0; j < cible.length && egal; j++) {
          egal = z[i + j] == cible[j];
        }
        if (egal) z[i + 7] = 'a'.codeUnitAt(0);
      }
      expectInvalide(analyserSauvegarde(z));
    });

    test('lien symbolique', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', [1]),
        entree('photos/lien.jpg', utf8.encode('/etc/passwd')),
      ]);
      // Marque la derniere entree comme lien symbolique Unix (mode 0120777).
      patcherCentral(z, (bd, i) {
        final longNom = bd.getUint16(i + 28, Endian.little);
        final nom = utf8.decode(z.sublist(i + 46, i + 46 + longNom));
        if (nom == 'photos/lien.jpg') {
          bd.setUint16(i + 4, 0x031e, Endian.little);
          bd.setUint32(i + 38, 0xA1FF << 16, Endian.little);
        }
      });
      expect(
        ZipDecoder().decodeBytes(z).files.any((x) => x.isSymbolicLink),
        isTrue,
      );
      expectInvalide(analyserSauvegarde(z));
    });

    test('nom contenant un octet nul', () {
      expectInvalide(avecEntree(entree('photos/b\u0000.jpg', [1])));
    });
    test('zip bomb : trop d\'entrees', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', [1]),
        for (var i = 0; i < 20; i++) entree('photos/p$i.jpg', [1]),
      ]);
      expectInvalide(
        analyserSauvegarde(z, limites: const LimitesSauvegarde(maxEntrees: 10)),
      );
      expect(
        analyserSauvegarde(z, limites: const LimitesSauvegarde(maxEntrees: 30)),
        isA<SauvegardeValide>(),
      );
    });
    test('zip bomb : entree trop volumineuse (taille declaree)', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', Uint8List(2 * 1024 * 1024)),
      ]);
      expect(z.length, lessThan(100 * 1024));
      expectInvalide(
        analyserSauvegarde(
          z,
          limites: const LimitesSauvegarde(maxTailleEntree: 1024 * 1024),
        ),
      );
    });
    test('zip bomb : taille totale', () {
      final z = zip([
        json(d),
        entree('photos/a.jpg', Uint8List(600 * 1024)),
        entree('photos/b.jpg', Uint8List(600 * 1024)),
      ]);
      expectInvalide(
        analyserSauvegarde(
          z,
          limites: const LimitesSauvegarde(maxTailleTotale: 1024 * 1024),
        ),
      );
    });
    test('limites par defaut bornees', () {
      const l = LimitesSauvegarde();
      expect(l.maxEntrees, lessThanOrEqualTo(10000));
      expect(l.maxTailleTotale, lessThanOrEqualTo(512 * 1024 * 1024));
    });
    test('taille declaree falsifiee (central != local)', () {
      final z = zip([json(d), entree('photos/a.jpg', Uint8List(5000))]);
      // Reduit la taille declaree dans le repertoire central.
      final bd = ByteData.view(z.buffer);
      var i = 0;
      var modifie = false;
      while (i + 4 < z.length) {
        if (bd.getUint32(i, Endian.little) == 0x02014b50) {
          final taille = bd.getUint32(i + 24, Endian.little);
          if (taille == 5000) {
            bd.setUint32(i + 24, 10, Endian.little);
            modifie = true;
          }
        }
        i++;
      }
      expect(modifie, isTrue);
      expectInvalide(analyserSauvegarde(z));
    });

    /// Archive d'une entree de [taille] octets nuls, dont la taille est
    /// falsifiee a [declaree] dans le repertoire central, et dans l'en-tete
    /// local si [aussiLocale]. Avec [differe], l'en-tete local annonce un
    /// descripteur de donnees (tailles locales a 0).
    Uint8List bombe(
      int taille,
      int declaree, {
      bool aussiLocale = false,
      bool differe = false,
    }) {
      final z = zip([json(d), entree('photos/a.jpg', Uint8List(taille))]);
      final bd = ByteData.view(z.buffer);
      for (var i = 0; i + 46 < z.length; i++) {
        final sig = bd.getUint32(i, Endian.little);
        if (sig == 0x02014b50 &&
            bd.getUint32(i + 24, Endian.little) == taille) {
          bd.setUint32(i + 24, declaree, Endian.little);
        }
        if (sig == 0x04034b50 &&
            bd.getUint32(i + 22, Endian.little) == taille) {
          if (aussiLocale) bd.setUint32(i + 22, declaree, Endian.little);
          if (differe) {
            bd.setUint16(
              i + 6,
              bd.getUint16(i + 6, Endian.little) | 8,
              Endian.little,
            );
            bd.setUint32(
              i + 18,
              bd.getUint32(i + 18, Endian.little),
              Endian.little,
            );
            bd.setUint32(i + 22, 0, Endian.little);
          }
        }
      }
      return z;
    }

    final taillJson = (json(d).content as List<int>).length;
    test('taille locale falsifiee : refus avant toute decompression', () {
      final z = bombe(5000, 10);
      var sortie = 0;
      expectInvalide(analyserSauvegarde(z, espion: (n) => sortie += n));
      expect(sortie, 0);
    });
    test('taille centrale falsifiee (aussi locale) : sortie bornee', () {
      final z = bombe(20 * 1024 * 1024, 10, aussiLocale: true);
      expect(z.length, lessThan(200 * 1024));
      var sortie = 0;
      expectInvalide(analyserSauvegarde(z, espion: (n) => sortie += n));
      expect(sortie, lessThanOrEqualTo(taillJson + 10 + 1));
    });
    test(
      'taille centrale falsifiee, descripteur de donnees : sortie bornee',
      () {
        final z = bombe(20 * 1024 * 1024, 10, differe: true);
        var sortie = 0;
        expectInvalide(analyserSauvegarde(z, espion: (n) => sortie += n));
        expect(sortie, lessThanOrEqualTo(taillJson + 10 + 1));
      },
    );
    test('taille declaree grande mais sortie reelle plus petite', () {
      final z = bombe(5000, 6000, aussiLocale: true);
      expectInvalide(analyserSauvegarde(z));
    });
    test('borne du total restant respectee pendant la decompression', () {
      final z = zip([json(d), entree('photos/a.jpg', Uint8List(600 * 1024))]);
      var sortie = 0;
      final r = analyserSauvegarde(
        z,
        limites: const LimitesSauvegarde(maxTailleTotale: 300 * 1024),
        espion: (n) => sortie += n,
      );
      expectInvalide(r);
      expect(sortie, 0); // refusee des les en-tetes
    });
    test('photos non referencees non retenues', () {
      final r = analyserSauvegarde(
        zip([
          json(d),
          entree('photos/a.jpg', [1]),
          entree('photos/zzz.jpg', [2]),
        ]),
      );
      expect((r as SauvegardeValide).photos.keys, ['a.jpg']);
    });
    test('entree dossier photos/ acceptee', () {
      final dossier = ArchiveFile('photos/', 0, <int>[])..isFile = false;
      expect(avecEntree(dossier), isA<SauvegardeValide>());
    });
    test('SauvegardeValide refuse un nom de photo dangereux', () {
      expect(
        () => SauvegardeValide(d, {'../x': Uint8List(1)}),
        throwsArgumentError,
      );
    });
  });

  group('aller-retour', () {
    test('REQ024_AC2 export A puis import B identique', () async {
      final a = Directory('${tmp.path}/A')..createSync();
      final photosA = Directory('${a.path}/photos')..createSync();
      File('${photosA.path}/a.jpg').writeAsBytesSync([5, 6, 7]);
      final donnees = donneesAvecPhoto('g', 'a.jpg', libelle: 'été');
      final octets = exporter(donnees, photosA);

      final b = Directory('${tmp.path}/B');
      final stockageB = StockageFichier(b);
      final r = analyserSauvegarde(octets) as SauvegardeValide;
      await stockageB.remplacerTout(r);

      final relu = (await stockageB.charger())!;
      expect(
        jsonEncode(donneesVersJson(relu)),
        jsonEncode(donneesVersJson(donnees)),
      );
      expect(File('${b.path}/photos/a.jpg').readAsBytesSync(), [5, 6, 7]);
      expect(Directory('${b.path}/import.tmp').existsSync(), isFalse);
    });
  });

  group('remplacerTout : atomicite', () {
    late Directory dossier;
    late SauvegardeValide nouvelle;

    // Renommeur fautif : échoue au n-ième appel après l'armement.
    var arme = false;
    var appels = 0;
    int? echecA;

    Future<void> renommerReel(String a, String b) async {
      if (FileSystemEntity.isDirectorySync(a)) {
        await Directory(a).rename(b);
      } else {
        await File(a).rename(b);
      }
    }

    Future<void> renommerFautif(String a, String b) async {
      if (arme) {
        appels++;
        if (appels == echecA) throw const FileSystemException('echec simule');
      }
      await renommerReel(a, b);
    }

    Future<StockageFichier> etatInitial() async {
      arme = false;
      appels = 0;
      echecA = null;
      dossier = Directory('${tmp.path}/data');
      final s = StockageFichier(dossier, renommer: renommerFautif);
      await s.enregistrer(donneesAvecPhoto('ancienne', 'vieille.jpg'));
      File('${dossier.path}/photos/vieille.jpg').writeAsBytesSync([1, 1]);
      File('${dossier.path}/photos/orpheline.jpg').writeAsBytesSync([2]);
      File('${dossier.path}/code.txt').writeAsStringSync('1234');
      arme = true;
      return s;
    }

    setUp(() {
      nouvelle = analyserSauvegarde(
        zip([
          json(donneesAvecPhoto('nouvelle', 'neuve.jpg')),
          entree('photos/neuve.jpg', [9, 9, 9]),
        ]),
      ) as SauvegardeValide;
    });

    test(
      'REQ024_AC2 remplace donnees et photos, supprime les anciennes',
      () async {
        final s = await etatInitial();
        await s.remplacerTout(nouvelle);
        final relu = (await StockageFichier(dossier).charger())!;
        expect(relu.accueilId, 'nouvelle');
        final photos = Directory('${dossier.path}/photos')
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .toList();
        expect(photos, ['neuve.jpg']);
        expect(
          instantane(dossier).keys
              .where((k) => k.contains('.old') || k.contains('.tmp')),
          isEmpty,
        );
      },
    );

    test('REQ024_AC6 le code est inchange', () async {
      final s = await etatInitial();
      await s.remplacerTout(nouvelle);
      expect(await s.lireCode(), '1234');
    });

    test('import sur dossier vide', () async {
      final s = StockageFichier(Directory('${tmp.path}/vide'));
      await s.remplacerTout(nouvelle);
      expect((await s.charger())!.accueilId, 'nouvelle');
      expect(File('${tmp.path}/vide/photos/neuve.jpg').existsSync(), isTrue);
    });

    test('un import.tmp residuel est ecarte', () async {
      final s = await etatInitial();
      Directory('${dossier.path}/import.tmp/photos')
          .createSync(recursive: true);
      File('${dossier.path}/import.tmp/photos/vieux.jpg').writeAsBytesSync([0]);
      await s.remplacerTout(nouvelle);
      expect(Directory('${dossier.path}/import.tmp').existsSync(), isFalse);
      expect(File('${dossier.path}/photos/vieux.jpg').existsSync(), isFalse);
    });

    test(
      'REQ024_AC7 echec simule a chaque renommage : etat d\'avant identique',
      () async {
        // 1. Compte les renommages d'un import reussi.
        var s = await etatInitial();
        await s.remplacerTout(nouvelle);
        final total = appels;
        expect(total, greaterThanOrEqualTo(4));

        // 2. Echec a chaque rang k : l'etat est strictement celui d'avant.
        for (var k = 1; k <= total; k++) {
          if (dossier.existsSync()) dossier.deleteSync(recursive: true);
          s = await etatInitial();
          echecA = k;
          final avant = instantane(dossier);
          await expectLater(
            s.remplacerTout(nouvelle),
            throwsA(isA<FileSystemException>()),
            reason: 'k=$k',
          );
          expect(instantane(dossier), avant, reason: 'k=$k');
          final relu = (await StockageFichier(dossier).charger())!;
          expect(relu.accueilId, 'ancienne', reason: 'k=$k');
          expect(File('${dossier.path}/photos/vieille.jpg').readAsBytesSync(), [
            1,
            1,
          ], reason: 'k=$k');
          // Un nouvel essai sans panne aboutit.
          await StockageFichier(dossier).remplacerTout(nouvelle);
          expect(
            (await StockageFichier(dossier).charger())!.accueilId,
            'nouvelle',
            reason: 'k=$k',
          );
        }
      },
    );

    test('un fichier import.tmp residuel est supprime', () async {
      final s = await etatInitial();
      File('${dossier.path}/import.tmp').writeAsStringSync('residu');
      await s.remplacerTout(nouvelle);
      expect(
        FileSystemEntity.typeSync('${dossier.path}/import.tmp'),
        FileSystemEntityType.notFound,
      );
      expect((await s.charger())!.accueilId, 'nouvelle');
    });

    test(
      'REQ024_AC7 arret brutal apres chaque renommage : charger() restaure',
      () async {
        final s = await etatInitial();
        await s.remplacerTout(nouvelle);
        final total = appels;
        for (var k = 1; k <= total; k++) {
          final instantanes = <Directory>[];
          // Le « crash » fige le disque juste avant (avant=true) ou juste
          // apres le k-ieme renommage ; le processus ne fait plus rien.
          for (final avant in [true, false]) {
            if (dossier.existsSync()) dossier.deleteSync(recursive: true);
            await etatInitial();
            var n = 0;
            final copie = Directory('${tmp.path}/crash_${k}_$avant');
            Future<void> renommerEspion(String a, String b) async {
              n++;
              if (avant && n == k) _copier(dossier, copie);
              await renommerReel(a, b);
              if (!avant && n == k) _copier(dossier, copie);
            }

            await StockageFichier(
              dossier,
              renommer: renommerEspion,
            ).remplacerTout(nouvelle);
            if (!copie.existsSync()) continue; // k au-dela du dernier rang
            instantanes.add(copie);
          }
          for (final copie in instantanes) {
            final nouvelleInstance = StockageFichier(copie);
            final relu = (await nouvelleInstance.charger())!;
            // Meme apres le dernier renommage (marqueur de validation
            // absent) l'etat revient a « ancienne ».
            expect(relu.accueilId, 'ancienne', reason: copie.path);
            expect(File('${copie.path}/photos/vieille.jpg').readAsBytesSync(), [
              1,
              1,
            ], reason: copie.path);
            expect(
              File('${copie.path}/photos/neuve.jpg').existsSync(),
              isFalse,
              reason: copie.path,
            );
            expect(
              instantane(copie).keys.where(
                (x) =>
                    x.contains('.old') ||
                    x.contains('.tmp') ||
                    x.contains('bascule'),
              ),
              isEmpty,
              reason: copie.path,
            );
            expect(await nouvelleInstance.lireCode(), '1234');
          }
        }
      },
    );

    test('arret brutal sur dossier vide : charger() revient a vide', () async {
      final vide = Directory('${tmp.path}/videcrash');
      var n = 0;
      final copie = Directory('${tmp.path}/videcrash_copie');
      await StockageFichier(
        vide,
        renommer: (a, b) async {
          if (++n == 1) _copier(vide, copie);
          await renommerReel(a, b);
        },
      ).remplacerTout(nouvelle);
      expect(copie.existsSync(), isTrue);
      expect(File('${copie.path}/bascule.debut').existsSync(), isTrue);
      expect(await StockageFichier(copie).charger(), isNull);
      expect(Directory('${copie.path}/photos').existsSync(), isFalse);
    });

    test(
      'bascule reussie mais nettoyage interrompu : charger() garde le nouveau',
      () async {
        await etatInitial();
        await StockageFichier(dossier).remplacerTout(nouvelle);
        // Rejoue l'etat « apres le point de non-retour » : olds + marqueurs.
        Directory('${dossier.path}/photos.old').createSync();
        File('${dossier.path}/glyphe.json.old').writeAsStringSync('{}');
        File('${dossier.path}/bascule.debut').writeAsStringSync('{}');
        File('${dossier.path}/bascule.ok').writeAsStringSync('{}');
        final relu = (await StockageFichier(dossier).charger())!;
        expect(relu.accueilId, 'nouvelle');
        expect(File('${dossier.path}/photos/neuve.jpg').existsSync(), isTrue);
        expect(
          instantane(dossier).keys.any((k) => k.contains('.old')),
          isFalse,
        );
      },
    );

    test('echec sans ancien glyphe.json : rien n\'est cree', () async {
      var n = 0;
      final neuf = Directory('${tmp.path}/neuf');
      final s = StockageFichier(
        neuf,
        renommer: (a, b) async {
          if (++n == 2) throw const FileSystemException('echec simule');
          await renommerReel(a, b);
        },
      );
      await expectLater(
        s.remplacerTout(nouvelle),
        throwsA(isA<FileSystemException>()),
      );
      expect(await s.charger(), isNull);
      expect(Directory('${neuf.path}/photos').existsSync(), isFalse);
      expect(Directory('${neuf.path}/import.tmp').existsSync(), isFalse);
    });

    test('reprise apres arret brutal en pleine bascule', () async {
      final s = await etatInitial();
      // Etat laisse par un arret apres la mise de cote de l'ancien etat.
      Directory('${dossier.path}/photos')
          .renameSync('${dossier.path}/photos.old');
      File('${dossier.path}/glyphe.json')
          .renameSync('${dossier.path}/glyphe.json.old');
      await s.remplacerTout(nouvelle);
      expect((await s.charger())!.accueilId, 'nouvelle');
      expect(instantane(dossier).keys.any((k) => k.endsWith('.old')), isFalse);
    });

    test(
      'echec apres un arret brutal precedent : l\'ancien etat est garde',
      () async {
        final s = await etatInitial();
        Directory('${dossier.path}/photos')
            .renameSync('${dossier.path}/photos.old');
        File('${dossier.path}/glyphe.json')
            .renameSync('${dossier.path}/glyphe.json.old');
        echecA = 1;
        await expectLater(
          s.remplacerTout(nouvelle),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          (await StockageFichier(dossier).charger())!.accueilId,
          'ancienne',
        );
        expect(File('${dossier.path}/photos/vieille.jpg').existsSync(), isTrue);
      },
    );

    group('marqueur bascule.debut illisible', () {
      final cas = <String, List<int>>{
        'vide': [],
        'non UTF-8': [0xff, 0xfe, 0x80, 0xc3],
        'JSON non-Map': utf8.encode('[1,2]'),
      };
      for (final MapEntry(key: nom, value: octets) in cas.entries) {
        test('sans *.old ($nom) : demarrage et donnees gardees', () async {
          final s = await etatInitial();
          File('${dossier.path}/bascule.debut').writeAsBytesSync(octets);
          final relu = (await StockageFichier(dossier).charger())!;
          expect(relu.accueilId, 'ancienne');
          expect(
            File('${dossier.path}/photos/vieille.jpg').existsSync(),
            isTrue,
          );
          expect(File('${dossier.path}/bascule.debut').existsSync(), isFalse);
          expect(await s.lireCode(), '1234');
        });

        test('avec *.old ($nom) : ancien etat restaure', () async {
          await etatInitial();
          File('${dossier.path}/bascule.debut').writeAsBytesSync(octets);
          Directory('${dossier.path}/photos')
              .renameSync('${dossier.path}/photos.old');
          File('${dossier.path}/glyphe.json')
              .renameSync('${dossier.path}/glyphe.json.old');
          Directory('${dossier.path}/photos').createSync();
          File('${dossier.path}/glyphe.json').writeAsStringSync('{}');
          final relu = (await StockageFichier(dossier).charger())!;
          expect(relu.accueilId, 'ancienne');
          expect(
            File('${dossier.path}/photos/vieille.jpg').existsSync(),
            isTrue,
          );
          expect(
            instantane(dossier).keys
                .where((k) => k.contains('.old') || k.contains('bascule')),
            isEmpty,
          );
        });
      }
    });

    test(
      'echec d\'ecriture dans import.tmp : etat identique, erreur',
      () async {
        // Rang d'ecriture a faire echouer : 1re photo, puis le JSON.
        for (final cible in ['neuve.jpg', 'glyphe.json']) {
          if (Directory('${tmp.path}/data').existsSync()) {
            Directory('${tmp.path}/data').deleteSync(recursive: true);
          }
          await etatInitial();
          final avant = instantane(dossier);
          final s = StockageFichier(
            dossier,
            ecrire: (chemin, octets) async {
              if (chemin.endsWith('import.tmp/photos/$cible') ||
                  chemin.endsWith('import.tmp/$cible')) {
                await File(chemin).writeAsBytes(octets.take(1).toList());
                throw const FileSystemException('disque plein');
              }
              await File(chemin).writeAsBytes(octets);
            },
          );
          await expectLater(
            s.remplacerTout(nouvelle),
            throwsA(isA<FileSystemException>()),
            reason: cible,
          );
          expect(instantane(dossier), avant, reason: cible);
          expect(Directory('${dossier.path}/import.tmp').existsSync(), isFalse);
        }
      },
    );

    test('echec d\'ecriture de bascule.ok : ancien etat restaure', () async {
      await etatInitial();
      final avant = instantane(dossier);
      final s = StockageFichier(
        dossier,
        ecrire: (chemin, octets) async {
          if (chemin.contains('bascule.ok')) {
            throw const FileSystemException('disque plein');
          }
          await File(chemin).writeAsBytes(octets);
        },
      );
      await expectLater(
        s.remplacerTout(nouvelle),
        throwsA(isA<FileSystemException>()),
      );
      expect(instantane(dossier), avant);
      expect((await StockageFichier(dossier).charger())!.accueilId, 'ancienne');
    });

    test('reprise dans enregistrer : crash mi-bascule puis ecriture', () async {
      await etatInitial();
      // Crash apres la mise de cote de l'ancien etat et l'import.tmp.
      Directory('${dossier.path}/photos')
          .renameSync('${dossier.path}/photos.old');
      File('${dossier.path}/glyphe.json')
          .renameSync('${dossier.path}/glyphe.json.old');
      File('${dossier.path}/bascule.debut')
          .writeAsStringSync('{"photos":true,"json":true}');
      Directory('${dossier.path}/import.tmp').createSync();
      final s = StockageFichier(dossier);
      await s.enregistrer(donneesAvecPhoto('X', 'vieille.jpg'));
      expect((await s.charger())!.accueilId, 'X');
      expect(File('${dossier.path}/photos/vieille.jpg').existsSync(), isTrue);
      expect(
        instantane(dossier).keys.where(
          (k) =>
              k.contains('.old') || k.contains('.tmp') || k.contains('bascule'),
        ),
        isEmpty,
      );
    });

    test('plusieurs ecritures concurrentes restent serialisees', () async {
      final s = await etatInitial();
      final f1 = s.remplacerTout(nouvelle);
      final f2 = s.enregistrer(donneesAvecPhoto('apres', 'neuve.jpg'));
      await Future.wait([f1, f2]);
      expect((await s.charger())!.accueilId, 'apres');
    });
  });
}

void _copier(Directory source, Directory cible) {
  cible.createSync(recursive: true);
  for (final e in source.listSync(followLinks: false)) {
    final nom = e.uri.pathSegments.where((x) => x.isNotEmpty).last;
    if (e is Directory) {
      _copier(e, Directory('${cible.path}/$nom'));
    } else if (e is File) {
      e.copySync('${cible.path}/$nom');
    }
  }
}
