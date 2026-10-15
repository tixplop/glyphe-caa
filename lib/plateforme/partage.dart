import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Menu de partage du système (REQ-023, seule sortie des données).
abstract interface class Partage {
  /// Ouvre le menu de partage avec le fichier [chemin].
  Future<void> partagerFichier(String chemin);
}

/// Taille maximale d'un fichier de sauvegarde lu en mémoire (200 Mo) : au-delà,
/// le fichier est refusé sans être lu (protège la mémoire de l'appareil).
const int tailleMaxSauvegarde = 200 * 1024 * 1024;

/// Le fichier choisi dépasse [tailleMaxSauvegarde] ou sa taille est inconnue.
class FichierTropVolumineux implements Exception {
  const FichierTropVolumineux();

  @override
  String toString() => 'FichierTropVolumineux';
}

/// Lit le fichier via [lire] seulement si [taille] est connue et au plus
/// [max]. Lève [FichierTropVolumineux] sinon.
Future<Uint8List> lireBornee({
  required Future<int?> Function() taille,
  required Future<Uint8List> Function() lire,
  int max = tailleMaxSauvegarde,
}) async {
  final t = await taille();
  if (t == null || t > max) throw const FichierTropVolumineux();
  return lire();
}

/// Choix d'un fichier de sauvegarde (REQ-024).
abstract interface class ChoixFichier {
  /// Octets du fichier ZIP choisi ; null si l'utilisateur annule. Lève
  /// [FichierTropVolumineux] au-delà de [tailleMaxSauvegarde].
  Future<Uint8List?> choisir();
}

/// [Partage] fondé sur `share_plus`.
class PartageSharePlus implements Partage {
  const PartageSharePlus();

  @override
  Future<void> partagerFichier(String chemin) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(chemin)]));
  }
}

/// [ChoixFichier] fondé sur `file_picker` (extension zip).
class ChoixFichierPicker implements ChoixFichier {
  const ChoixFichierPicker();

  @override
  Future<Uint8List?> choisir() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (f == null) return null;
    return lireBornee(
      taille: () async => f.lengthSync() ?? await f.length(),
      lire: f.readAsBytes,
    );
  }
}
