/// Stockage des photos personnelles (REQ-020).
///
/// Les photos sont désignées par leur seul nom de fichier, relatif au
/// dossier `photos/` du stockage privé ; le chemin est résolu à l'affichage.
library;

import 'dart:io';
import 'dart:math';

import 'modeles.dart';

/// Nom de fichier simple : non vide, sans `/`, `\`, `..` ni octet nul.
bool nomPhotoValide(String nom) =>
    nom.isNotEmpty &&
    nom != '.' &&
    !nom.contains('/') &&
    !nom.contains(r'\') &&
    !nom.contains('..') &&
    !nom.contains('\u0000');

class Photos {
  Photos(this.dossier, {Random? aleatoire})
    : _aleatoire = aleatoire ?? Random.secure();

  final Directory dossier;
  final Random _aleatoire;

  /// Chemin du fichier [nom] ; [ArgumentError] si le nom sort du dossier.
  String resoudre(String nom) {
    if (!nomPhotoValide(nom)) {
      throw ArgumentError.value(nom, 'nom', 'nom de photo invalide');
    }
    return '${dossier.path}/$nom';
  }

  String _nouveauNom() {
    final octets = List.generate(16, (_) => _aleatoire.nextInt(256));
    return '${octets.map((o) => o.toRadixString(16).padLeft(2, '0')).join()}.jpg';
  }

  /// Copie le fichier [source] dans le dossier sous un nom unique et renvoie
  /// ce nom. Lève [FileSystemException] si la source est illisible.
  Future<String> importer(String source) async {
    final fichier = File(source);
    if (!await fichier.exists()) {
      throw FileSystemException('Photo introuvable', source);
    }
    await dossier.create(recursive: true);
    final nom = _nouveauNom();
    await fichier.copy(resoudre(nom));
    return nom;
  }

  /// Supprime les fichiers du dossier qu'aucune case de [donnees] ne
  /// référence (AC-020-4).
  Future<void> nettoyerPhotosInutilisees(Donnees donnees) async {
    if (!await dossier.exists()) return;
    final utilisees = {
      for (final g in donnees.grilles)
        for (final c in g.cases)
          if (c.image case ImagePhoto(:final fichier)) fichier,
    };
    await for (final e in dossier.list(followLinks: false)) {
      if (e is! File) continue;
      final nom = e.uri.pathSegments.last;
      if (!utilisees.contains(nom)) {
        try {
          await e.delete();
        } on FileSystemException {
          // Meilleur effort : un fichier non supprimé le sera au prochain tour.
        }
      }
    }
  }
}
