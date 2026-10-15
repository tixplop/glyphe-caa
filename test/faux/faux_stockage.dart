import 'package:glyphe/domaine/modeles.dart';
import 'package:glyphe/domaine/stockage.dart';

/// Stockage en mémoire : compte les écritures.
class FauxStockage implements Stockage {
  FauxStockage([this.donnees]);

  Donnees? donnees;
  String? code;
  int ecritures = 0;

  @override
  Future<Donnees?> charger() async => donnees;

  @override
  Future<void> enregistrer(Donnees d) async {
    donnees = d;
    ecritures++;
  }

  @override
  Future<String?> lireCode() async => code;

  @override
  Future<void> ecrireCode(String? c) async => code = c;
}
