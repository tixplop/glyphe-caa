/// Initialisation des données au premier lancement (REQ-001).
library;

import 'dart:convert';

import 'modeles.dart';
import 'serialisation.dart';
import 'stockage.dart';

/// Renvoie les données existantes ; si aucune n'est enregistrée, enregistre
/// puis renvoie les grilles d'exemple décrites par [jsonExemples].
///
/// Lève [FormatInvalide] si les exemples sont invalides (rien n'est écrit).
Future<Donnees> chargerOuInitialiser(
  Stockage stockage,
  String jsonExemples,
) async {
  final existantes = await stockage.charger();
  if (existantes != null) return existantes;
  final Object? decode;
  try {
    decode = jsonDecode(jsonExemples);
  } on FormatException catch (e) {
    throw FormatInvalide('JSON d\'exemples illisible : ${e.message}');
  }
  final exemples = donneesDepuisJson(decode);
  await stockage.enregistrer(exemples);
  return exemples;
}
