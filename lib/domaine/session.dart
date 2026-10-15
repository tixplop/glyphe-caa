import 'package:flutter/foundation.dart';

import 'horloge.dart';
import 'modeles.dart';
import 'voix.dart';

/// Élément de la barre de phrase.
class ElementBarre {
  const ElementBarre({
    required this.image,
    required this.libelle,
    required this.textePrononce,
  });

  final ImageCase image;
  final String libelle;

  /// Texte effectivement dit (texte prononcé de la case, sinon libellé).
  final String textePrononce;
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

  ParametresVoix get _parametres {
    final r = _donnees.reglages;
    return ParametresVoix(
      voixId: r.voixId,
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
    _derniereCaseHeure = _horloge.maintenant();

    final texte = c.textePrononce.isNotEmpty ? c.textePrononce : c.libelle;
    _barre.add(
      ElementBarre(image: c.image, libelle: c.libelle, textePrononce: texte),
    );
    if (_donnees.reglages.retourAccueilApresMot) {
      _grilleId = _donnees.accueilId;
      _historique.clear();
    }
    notifyListeners();
    if (texte.isNotEmpty) await _dire(texte);
  }

  Future<void> _dire(String texte) async {
    try {
      await _voix.arreter();
      await _voix.parler(texte, _parametres);
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
    await _dire(texte);
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

  void accueil() {
    if (_grilleId == _donnees.accueilId && _historique.isEmpty) return;
    _grilleId = _donnees.accueilId;
    _historique.clear();
    notifyListeners();
  }
}
