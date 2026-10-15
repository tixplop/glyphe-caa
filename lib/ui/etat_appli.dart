import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domaine/donnees_initiales.dart';
import '../domaine/horloge.dart';
import '../domaine/modeles.dart';
import '../domaine/session.dart';
import '../domaine/stockage.dart';
import '../domaine/voix.dart';

/// Chemin du fichier embarqué des grilles d'exemple.
const String cheminExemples = 'assets/exemples/grilles_exemple.json';

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
  });

  /// Charge les exemples depuis les assets embarqués.
  static Future<String> chargerExemples() =>
      rootBundle.loadString(cheminExemples);

  final Stockage stockage;
  final Voix voix;
  final Horloge horloge;
  final String jsonExemples;

  Session? _session;
  bool _verrouille = true;

  bool get pret => _session != null;

  Session get session {
    final s = _session;
    if (s == null) throw StateError('EtatAppli.init() n\'a pas été appelé');
    return s;
  }

  bool get verrouille => _verrouille;

  /// Charge les données (ou crée les exemples) et ouvre une session neuve.
  Future<void> init() async {
    final donnees = await chargerOuInitialiser(stockage, jsonExemples);
    _session = Session(donnees, voix, horloge);
    _verrouille = true;
    notifyListeners();
  }

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
