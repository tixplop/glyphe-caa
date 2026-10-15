import 'dart:io';
import 'dart:typed_data';

import 'package:glyphe/plateforme/partage.dart';

/// Partage factice : lit et retient le fichier partagé.
class FauxPartage implements Partage {
  final List<String> chemins = [];
  final List<Uint8List> contenus = [];
  Object? erreur;

  /// Appelé avant de répondre (p. ex. passage de l'appli en arrière-plan).
  Future<void> Function()? pendant;

  @override
  Future<void> partagerFichier(String chemin) async {
    await pendant?.call();
    if (erreur != null) throw erreur!;
    chemins.add(chemin);
    contenus.add(await File(chemin).readAsBytes());
  }
}

/// Choix de fichier factice.
class FauxChoixFichier implements ChoixFichier {
  FauxChoixFichier([this.octets]);

  Uint8List? octets;
  int appels = 0;
  Future<void> Function()? pendant;

  /// Si défini, lève cette erreur.
  Object? erreur;

  @override
  Future<Uint8List?> choisir() async {
    appels++;
    await pendant?.call();
    if (erreur != null) throw erreur!;
    return octets;
  }
}
