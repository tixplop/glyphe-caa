import 'dart:math';

import 'stockage.dart';

/// Raison du refus d'un code (AC-012-1).
enum ErreurCode { format, differentes }

/// Code refusé à la définition.
class CodeInvalide implements Exception {
  const CodeInvalide(this.erreur);

  final ErreurCode erreur;

  @override
  String toString() => 'CodeInvalide($erreur)';
}

/// Code de déverrouillage optionnel à 4 chiffres et procédure de secours.
class Verrou {
  Verrou._(this._stockage, this._phrases, this._code);

  /// Lit le code persisté ; [phrases] est la liste embarquée de secours.
  static Future<Verrou> charger(Stockage stockage, List<String> phrases) async {
    final code = await stockage.lireCode();
    return Verrou._(stockage, List.unmodifiable(phrases), code);
  }

  final Stockage _stockage;
  final List<String> _phrases;
  String? _code;
  String? _phraseDemandee;

  bool get aCode => _code != null;

  static final RegExp _quatreChiffres = RegExp(r'^[0-9]{4}$');

  /// Définit ou remplace le code. Lève [CodeInvalide] si [a] n'est pas
  /// composé d'exactement 4 chiffres ASCII, ou si [a] et [b] diffèrent.
  Future<void> definirCode(String a, String b) async {
    if (!_quatreChiffres.hasMatch(a)) {
      throw const CodeInvalide(ErreurCode.format);
    }
    if (a != b) throw const CodeInvalide(ErreurCode.differentes);
    await _stockage.ecrireCode(a);
    _code = a;
  }

  Future<void> supprimerCode() async {
    await _stockage.ecrireCode(null);
    _code = null;
    _phraseDemandee = null;
  }

  bool verifier(String saisie) => _code != null && saisie == _code;

  /// Tire une phrase de la liste et la retient pour [verifierPhrase].
  String phraseSecours(Random aleatoire) {
    if (_phrases.isEmpty) {
      throw StateError('Aucune phrase de secours embarquée');
    }
    return _phraseDemandee = _phrases[aleatoire.nextInt(_phrases.length)];
  }

  /// Compare à la phrase demandée (casse et espaces ignorés, accents
  /// exigés). Si elle est correcte, le code est supprimé.
  Future<bool> verifierPhrase(String saisie) async {
    final attendue = _phraseDemandee;
    if (attendue == null || _plier(saisie) != _plier(attendue)) return false;
    await supprimerCode();
    return true;
  }

  static String _plier(String s) =>
      s.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');
}
