import 'modeles.dart';
import 'sauvegarde.dart';

/// Persistance locale. Le code de déverrouillage est stocké à part (AC-012-4).
abstract interface class Stockage {
  /// Null si aucune donnée n'a encore été enregistrée.
  Future<Donnees?> charger();

  Future<void> enregistrer(Donnees donnees);

  Future<String?> lireCode();

  /// Null supprime le code.
  Future<void> ecrireCode(String? code);
}

/// Stockage capable d'installer une sauvegarde importée (REQ-024).
abstract interface class StockageRemplacable implements Stockage {
  /// Remplace atomiquement grilles, réglages et photos ; le code n'est pas
  /// touché (AC-024-6). En cas d'échec, les données d'avant sont intactes.
  Future<void> remplacerTout(SauvegardeValide sauvegarde);
}
