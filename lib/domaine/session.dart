import 'package:flutter/foundation.dart';

import 'choix_voix.dart';
import 'horloge.dart';
import 'modeles.dart';
import 'voix.dart';

/// Élément de la barre de phrase.
class ElementBarre {
  const ElementBarre({
    required this.image,
    required this.libelle,
    required this.textePrononce,
    this.categorie = Categorie.petitMot,
  });

  final ImageCase image;
  final String libelle;

  /// Texte effectivement dit (texte prononcé de la case, sinon libellé).
  final String textePrononce;

  /// Catégorie de la case au moment de l'appui (AC-032-6).
  final Categorie categorie;
}

/// État de la session de communication : grille courante, historique de
/// navigation, barre de phrase, parole et anti-répétition.
class Session extends ChangeNotifier {
  Session(this._donnees, this._voix, this._horloge)
    : _grilleId = _donnees.accueilId;

  Donnees _donnees;
  final Voix _voix;
  final Horloge _horloge;
  String _grilleId;
  final List<String> _historique = [];
  final List<ElementBarre> _barre = [];
  String? _derniereCaseId;
  DateTime? _derniereCaseHeure;
  bool _enLecture = false;
  int _jetonLecture = 0;

  /// Vrai pendant la lecture de la barre (REQ-034). Remis à faux à la fin de
  /// la prononciation, à l'arrêt et à l'appui d'une case, même si le moteur
  /// ne signale pas la fin.
  bool get enLecture => _enLecture;

  Donnees get donnees => _donnees;

  /// Remplace les données (ex. après édition) ; si la grille courante a
  /// disparu, retour à l'accueil. Lève [ArgumentError] si la grille d'accueil
  /// des nouvelles données n'existe pas (l'état reste inchangé).
  set donnees(Donnees d) {
    if (d.grillePar(d.accueilId) == null) {
      throw ArgumentError.value(
        d.accueilId,
        'accueilId',
        'grille d\'accueil introuvable',
      );
    }
    _donnees = d;
    _historique.removeWhere((id) => d.grillePar(id) == null);
    if (d.grillePar(_grilleId) == null) {
      _grilleId = d.accueilId;
      _historique.clear();
    }
    notifyListeners();
  }

  Grille get grilleCourante =>
      _donnees.grillePar(_grilleId) ?? _donnees.grillePar(_donnees.accueilId)!;

  List<ElementBarre> get barre => List.unmodifiable(_barre);

  /// Voix effective vérifiée par l'état de l'appli ; null : voix enregistrée
  /// utilisée telle quelle.
  ChoixVoix? choixVoix;

  /// Paramètres de prononciation courants : si la voix enregistrée est
  /// indisponible, la voix par défaut est utilisée (AC-022-2).
  ParametresVoix get parametres {
    final r = _donnees.reglages;
    final choix = choixVoix;
    return ParametresVoix(
      voixId: choix != null && choix.voixEnregistreeIndisponible
          ? choix.voixId
          : r.voixId,
      debit: r.debit,
      hauteur: r.hauteur,
      volume: r.volume,
    );
  }

  bool _repetition(Case c) {
    final delai = _donnees.reglages.delaiAntiRepetitionMs;
    final avant = _derniereCaseHeure;
    return delai > 0 &&
        avant != null &&
        _derniereCaseId == c.id &&
        _horloge.maintenant().difference(avant).inMilliseconds < delai;
  }

  Future<void> appuyerCase(Case c) async {
    if (c.type == TypeCase.dossier) {
      final cible = c.cibleId;
      if (cible == null || _donnees.grillePar(cible) == null) return;
      _historique.add(_grilleId);
      _grilleId = cible;
      notifyListeners();
      return;
    }
    if (_repetition(c)) return;
    _derniereCaseId = c.id;
    _interrompreLecture();
    _derniereCaseHeure = _horloge.maintenant();

    final texte = c.textePrononce.isNotEmpty ? c.textePrononce : c.libelle;
    _barre.add(
      ElementBarre(
        image: c.image,
        libelle: c.libelle,
        textePrononce: texte,
        categorie: c.categorie,
      ),
    );
    if (_donnees.reglages.retourAccueilApresMot) {
      _grilleId = _donnees.accueilId;
      _historique.clear();
    }
    notifyListeners();
    if (texte.isNotEmpty) await _dire(texte);
  }

  /// Prononce [texte] avec les réglages courants (essai de la voix).
  Future<void> essayerVoix(String texte) {
    _interrompreLecture();
    notifyListeners();
    return _dire(texte);
  }

  /// Invalide la lecture en cours (sa fin éventuelle sera ignorée).
  void _interrompreLecture() {
    _jetonLecture++;
    _enLecture = false;
  }

  Future<void> _dire(String texte) async {
    try {
      await _voix.arreter();
      await _voix.parler(texte, parametres);
    } catch (_) {
      // La voix ne doit jamais empêcher la communication (REQ-005).
    }
  }

  /// Prononce toute la barre en une fois ; la barre est inchangée.
  Future<void> lireBarre() async {
    final texte = _barre
        .map((e) => e.textePrononce)
        .where((t) => t.isNotEmpty)
        .join(' ');
    if (texte.isEmpty) return;
    final jeton = ++_jetonLecture;
    _enLecture = true;
    notifyListeners();
    await _dire(texte);
    if (jeton == _jetonLecture) {
      _enLecture = false;
      notifyListeners();
    }
  }

  /// Arrête la parole en cours (bouton « Arrêter »).
  Future<void> arreterLecture() async {
    _interrompreLecture();
    notifyListeners();
    try {
      await _voix.arreter();
    } catch (_) {
      // La voix ne doit jamais empêcher la communication (REQ-005).
    }
  }

  void effacerDernier() {
    if (_barre.isEmpty) return;
    _barre.removeLast();
    notifyListeners();
  }

  void toutEffacer() {
    if (_barre.isEmpty) return;
    _barre.clear();
    notifyListeners();
  }

  void retour() {
    if (_historique.isEmpty) return;
    _grilleId = _historique.removeLast();
    notifyListeners();
  }

  /// Ouvre la grille [id] (édition) : l'accueil devient le point de retour.
  /// Sans effet si la grille n'existe pas.
  void ouvrirGrille(String id) {
    if (_donnees.grillePar(id) == null) return;
    _historique.clear();
    if (id != _donnees.accueilId) _historique.add(_donnees.accueilId);
    _grilleId = id;
    notifyListeners();
  }

  void accueil() {
    if (_grilleId == _donnees.accueilId && _historique.isEmpty) return;
    _grilleId = _donnees.accueilId;
    _historique.clear();
    notifyListeners();
  }
}
