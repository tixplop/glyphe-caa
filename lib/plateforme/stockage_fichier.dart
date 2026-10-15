import 'dart:convert';
import 'dart:io';

import '../domaine/modeles.dart';
import '../domaine/sauvegarde.dart';
import '../domaine/photos.dart';
import '../domaine/serialisation.dart';
import '../domaine/stockage.dart';

/// Opération de renommage atomique (injectable pour les tests).
typedef Renommer = Future<void> Function(String source, String cible);

/// Écriture durable d'un fichier (injectable pour les tests).
typedef EcrireFichier = Future<void> Function(String chemin, List<int> octets);

/// Stockage dans un dossier local : `glyphe.json`, `code.txt`, `photos/`.
class StockageFichier implements StockageRemplacable {
  StockageFichier(this.dossier, {Renommer? renommer, EcrireFichier? ecrire})
    : _renommer = renommer ?? _renommerFichier,
      _ecrireFichier = ecrire ?? _ecrireReel;

  final Directory dossier;
  final Renommer _renommer;
  final EcrireFichier _ecrireFichier;

  static Future<void> _ecrireReel(String chemin, List<int> octets) =>
      File(chemin).writeAsBytes(octets, flush: true);

  /// Fin de la dernière écriture en file (sérialise les `enregistrer`).
  Future<void> _file = Future<void>.value();

  static Future<void> _renommerFichier(String source, String cible) async {
    if (await FileSystemEntity.isDirectory(source)) {
      await Directory(source).rename(cible);
    } else {
      await File(source).rename(cible);
    }
  }

  File get _donnees => File('${dossier.path}/glyphe.json');
  File get _temporaire => File('${dossier.path}/glyphe.json.tmp');
  File get _code => File('${dossier.path}/code.txt');
  Directory get dossierPhotos => Directory('${dossier.path}/photos');

  /// Exécute [action] à la suite des écritures en cours.
  Future<T> _enFile<T>(Future<T> Function() action) {
    final resultat = _file.then((_) => action());
    _file = resultat.then((_) {}, onError: (Object _) {});
    return resultat;
  }

  @override
  Future<Donnees?> charger() => _enFile(() async {
    await _reprendreBascule();
    return _lire();
  });

  Future<Donnees?> _lire() async {
    if (!await _donnees.exists()) return null;
    final Object? json;
    try {
      json = jsonDecode(await _donnees.readAsString());
    } on FormatException catch (e) {
      throw FormatInvalide('JSON illisible : ${e.message}');
    }
    return donneesDepuisJson(json);
  }

  @override
  Future<void> enregistrer(Donnees donnees) {
    final texte = jsonEncode(donneesVersJson(donnees));
    final resultat = _file.then((_) => _ecrire(texte));
    // La file continue même si cette écriture échoue.
    _file = resultat.then((_) {}, onError: (Object _) {});
    return resultat;
  }

  Future<void> _ecrire(String texte) async {
    await dossier.create(recursive: true);
    await _reprendreBascule();
    await dossierPhotos.create(recursive: true);
    await _temporaire.writeAsString(texte, flush: true);
    await _renommer(_temporaire.path, _donnees.path);
  }

  @override
  Future<String?> lireCode() async {
    if (!await _code.exists()) return null;
    final texte = (await _code.readAsString()).trim();
    return texte.isEmpty ? null : texte;
  }

  @override
  Future<void> ecrireCode(String? code) async {
    if (code == null) {
      if (await _code.exists()) await _code.delete();
      return;
    }
    await dossier.create(recursive: true);
    await _code.writeAsString(code, flush: true);
  }

  String _chemin(String nom) => '${dossier.path}/$nom';

  /// Remplace toutes les données (grilles, réglages, photos) par
  /// [sauvegarde], de façon atomique (AC-024-7). Le code n'est pas touché
  /// (AC-024-6). Écrit d'abord dans `import.tmp/`, puis bascule par
  /// renommages en gardant l'ancien état (`*.old`) jusqu'à la réussite ;
  /// en cas d'échec, l'ancien état est restauré et l'erreur propagée.
  @override
  Future<void> remplacerTout(SauvegardeValide sauvegarde) =>
      _enFile(() => _remplacer(sauvegarde));

  Future<void> _remplacer(SauvegardeValide sauvegarde) async {
    await dossier.create(recursive: true);
    await _reprendreBascule();
    final tmp = Directory(_chemin('import.tmp'));
    final nouveauxPhotos = '${tmp.path}/photos';
    final nouveauJson = '${tmp.path}/glyphe.json';
    try {
      await _supprimerChemin(tmp.path);
      await Directory(nouveauxPhotos).create(recursive: true);
      for (final e in sauvegarde.photos.entries) {
        if (!nomPhotoValide(e.key)) {
          throw FormatInvalide('nom de photo invalide : ${e.key}');
        }
        await _ecrireFichier('$nouveauxPhotos/${e.key}', e.value);
      }
      await _ecrireFichier(
        nouveauJson,
        utf8.encode(jsonEncode(donneesVersJson(sauvegarde.donnees))),
      );
    } on Object {
      await _supprimerChemin(tmp.path);
      rethrow;
    }

    // (ancien, courant, nouveau) : chaque étape déplace l'ancien de côté
    // puis installe le nouveau.
    final photos = _chemin('photos');
    final json = _chemin('glyphe.json');
    final etapes = <(String, String, String)>[
      ('$photos.old', photos, nouveauxPhotos),
      ('$json.old', json, nouveauJson),
    ];
    try {
      await _ecrireMarqueur(_debut.path, {
        'photos': await _existe(photos),
        'json': await _existe(json),
      });
      for (final (ancien, courant, nouveau) in etapes) {
        await _supprimerChemin(ancien);
        if (await FileSystemEntity.type(courant) !=
            FileSystemEntityType.notFound) {
          await _renommer(courant, ancien);
        }
        await _renommer(nouveau, courant);
      }
      // Point de non-retour : les deux étapes ont réussi.
      // Écrit puis renommé : bascule.ok n'existe jamais à moitié écrit.
      final provisoire = '${_fin.path}.tmp';
      await _ecrireMarqueur(provisoire, null);
      await _renommerReel(provisoire, _fin.path);
    } on Object {
      try {
        await _reprendreBascule();
      } on Object {
        // Le marqueur de début reste : la reprise aura lieu au prochain accès.
      }
      rethrow;
    }
    // Les nouvelles données sont en place : un échec de nettoyage n'est pas
    // une erreur d'import, la reprise l'achèvera au prochain accès.
    try {
      await _reprendreBascule();
    } on Object {
      // Ignoré volontairement.
    }
  }

  File get _debut => File(_chemin('bascule.debut'));
  File get _fin => File(_chemin('bascule.ok'));

  Future<bool> _existe(String chemin) async =>
      await FileSystemEntity.type(chemin) != FileSystemEntityType.notFound;

  Future<void> _ecrireMarqueur(String chemin, Map<String, bool>? contenu) =>
      _ecrireFichier(chemin, utf8.encode(jsonEncode(contenu ?? {})));

  Future<void> _renommerReel(String source, String cible) =>
      _renommerFichier(source, cible);

  /// Reprise d'une bascule interrompue (arrêt brutal ou échec), traitée
  /// comme un tout (AC-024-7). N'utilise pas le renommeur injectable : la
  /// restauration doit toujours être tentée pour de bon.
  ///
  /// - marqueur `bascule.ok` : la bascule avait réussi, on finit le nettoyage ;
  /// - marqueur `bascule.debut` seul : retour à l'ancien état, photos et JSON
  ///   ensemble ;
  /// - sans marqueur, des `*.old` isolés sont l'ancien état (reprise de
  ///   secours) : ils sont remis en place.
  Future<void> _reprendreBascule() async {
    final photos = _chemin('photos');
    final json = _chemin('glyphe.json');
    final composants = {'photos': photos, 'json': json};
    final aMarqueurDebut = await _debut.exists();
    if (await _fin.exists()) {
      // Bascule réussie : seul le nettoyage reste à faire.
    } else if (aMarqueurDebut ||
        await _existe('$json.old') ||
        await _existe('$photos.old')) {
      Map<String, bool> existait = {};
      if (aMarqueurDebut) {
        try {
          final brut = jsonDecode(
            utf8.decode(await _debut.readAsBytes(), allowMalformed: true),
          );
          if (brut is Map) {
            existait = {
              for (final e in brut.entries)
                if (e.value is bool) '${e.key}': e.value as bool,
            };
          }
        } on FormatException {
          // Marqueur illisible : on ne s'appuie que sur les *.old.
        }
      }
      for (final e in composants.entries) {
        final ancien = '${e.value}.old';
        if (await _existe(ancien)) {
          await _supprimerChemin(e.value);
          await _renommerReel(ancien, e.value);
        } else if (existait[e.key] == false) {
          // Rien n'existait avant : ce qui est là vient de la bascule.
          await _supprimerChemin(e.value);
        }
      }
    } else {
      await _supprimerChemin('${_fin.path}.tmp');
      return;
    }
    await _supprimerChemin('${_fin.path}.tmp');
    for (final ancien in ['$photos.old', '$json.old']) {
      await _supprimerChemin(ancien);
    }
    await _supprimerChemin(_chemin('import.tmp'));
    await _supprimerChemin(_debut.path);
    await _supprimerChemin(_fin.path);
  }

  Future<void> _supprimerChemin(String chemin) async {
    switch (await FileSystemEntity.type(chemin)) {
      case FileSystemEntityType.directory:
        await Directory(chemin).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(chemin).delete();
    }
  }
}
