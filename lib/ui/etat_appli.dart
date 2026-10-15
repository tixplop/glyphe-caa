import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domaine/donnees_initiales.dart';
import '../domaine/horloge.dart';
import '../domaine/modeles.dart';
import '../domaine/session.dart';
import '../domaine/stockage.dart';
import '../domaine/verrou.dart';
import '../domaine/voix.dart';

/// Chemin du fichier embarqué des grilles d'exemple.
const String cheminExemples = 'assets/exemples/grilles_exemple.json';

/// Chemin du fichier embarqué des phrases de secours.
const String cheminPhrases = 'assets/phrases_secours.json';

/// État de l'appli : charge et persiste les données, porte la [Session].
///
/// La grille courante, la barre et le verrouillage ne sont pas persistés :
/// au lancement, accueil, barre vide, verrouillé (AC-025-3).
class EtatAppli extends ChangeNotifier {
  EtatAppli({
    required this.stockage,
    required this.voix,
    required this.horloge,
    required this.jsonExemples,
    this.jsonPhrases = '[]',
    Random? aleatoire,
  }) : aleatoire = aleatoire ?? Random();

  /// Charge les exemples depuis les assets embarqués.
  static Future<String> chargerExemples() =>
      rootBundle.loadString(cheminExemples);

  final Stockage stockage;
  final Voix voix;
  final Horloge horloge;
  final String jsonExemples;

  /// Liste JSON des phrases de secours (code oublié).
  final String jsonPhrases;
  final Random aleatoire;

  /// Charge les phrases de secours depuis les assets embarqués.
  static Future<String> chargerPhrases() =>
      rootBundle.loadString(cheminPhrases);

  Session? _session;
  Verrou? _verrou;
  bool _verrouille = true;

  bool get pret => _session != null;

  Session get session {
    final s = _session;
    if (s == null) throw StateError('EtatAppli.init() n\'a pas été appelé');
    return s;
  }

  Verrou get verrou {
    final v = _verrou;
    if (v == null) throw StateError('EtatAppli.init() n\'a pas été appelé');
    return v;
  }

  bool get verrouille => _verrouille;

  /// Mode édition : exactement l'inverse du verrouillage.
  bool get modeEdition => !_verrouille;

  /// Ouvre le mode édition (après appui long et code éventuel).
  void ouvrirEdition() {
    if (!_verrouille) return;
    _verrouille = false;
    notifyListeners();
  }

  /// Retour au mode communication verrouillé (AC-014-1, AC-014-2).
  void verrouiller() {
    if (_verrouille) return;
    _verrouille = true;
    notifyListeners();
  }

  /// Charge les données (ou crée les exemples) et ouvre une session neuve.
  Future<void> init() async {
    final donnees = await chargerOuInitialiser(stockage, jsonExemples);
    final phrases = (jsonDecode(jsonPhrases) as List<dynamic>).cast<String>();
    _verrou = await Verrou.charger(stockage, phrases);
    _session = Session(donnees, voix, horloge);
    _verrouille = true;
    notifyListeners();
  }

  /// Nouvel identifiant unique pour une case ou une grille.
  String nouvelId(String prefixe) =>
      '$prefixe-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${aleatoire.nextInt(1 << 32).toRadixString(36)}';

  /// Remplace les données et les enregistre. Lève [ArgumentError] (rien
  /// n'est écrit) si la grille d'accueil n'existe pas.
  Future<void> modifierDonnees(Donnees d) async {
    if (d.grillePar(d.accueilId) == null) {
      throw ArgumentError.value(
        d.accueilId,
        'accueilId',
        'grille d\'accueil introuvable',
      );
    }
    session.donnees = d;
    await stockage.enregistrer(d);
  }
}
