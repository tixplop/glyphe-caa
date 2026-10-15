import 'modeles.dart';

/// Persistance locale. Le code de déverrouillage est stocké à part (AC-012-4).
abstract interface class Stockage {
  /// Null si aucune donnée n'a encore été enregistrée.
  Future<Donnees?> charger();

  Future<void> enregistrer(Donnees donnees);

  Future<String?> lireCode();

  /// Null supprime le code.
  Future<void> ecrireCode(String? code);
}
