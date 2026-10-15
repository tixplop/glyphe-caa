import 'dart:convert';
import 'dart:io';

import '../domaine/modeles.dart';
import '../domaine/serialisation.dart';
import '../domaine/stockage.dart';

/// Opération de renommage atomique (injectable pour les tests).
typedef Renommer = Future<void> Function(String source, String cible);

/// Stockage dans un dossier local : `glyphe.json`, `code.txt`, `photos/`.
class StockageFichier implements Stockage {
  StockageFichier(this.dossier, {Renommer? renommer})
    : _renommer = renommer ?? _renommerFichier;

  final Directory dossier;
  final Renommer _renommer;

  /// Fin de la dernière écriture en file (sérialise les `enregistrer`).
  Future<void> _file = Future<void>.value();

  static Future<void> _renommerFichier(String source, String cible) async {
    await File(source).rename(cible);
  }

  File get _donnees => File('${dossier.path}/glyphe.json');
  File get _temporaire => File('${dossier.path}/glyphe.json.tmp');
  File get _code => File('${dossier.path}/code.txt');
  Directory get dossierPhotos => Directory('${dossier.path}/photos');

  @override
  Future<Donnees?> charger() async {
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
}
