import 'dart:async';

import 'package:glyphe/domaine/voix.dart';

/// Voix factice : journal ordonné des appels. `parler` n'écrit que
/// `parler:<texte>` ; seul `arreter` écrit `stop`.
class FauxVoix implements Voix {
  FauxVoix({this.voix = const [], this.parolePilotee = false});

  /// Si vrai, `parler` ne se termine que sur [terminerParole] (le moteur ne
  /// signale pas la fin de lui-même).
  bool parolePilotee;
  final List<Completer<void>> _enCours = [];

  /// Termine les prononciations en attente (mode [parolePilotee]).
  void terminerParole() {
    for (final c in _enCours) {
      if (!c.isCompleted) c.complete();
    }
    _enCours.clear();
  }

  /// Termine seulement la plus ancienne prononciation en attente.
  void terminerPremiereParole() {
    if (_enCours.isEmpty) return;
    final c = _enCours.removeAt(0);
    if (!c.isCompleted) c.complete();
  }

  List<InfoVoix> voix;
  final List<String> journal = [];
  final List<ParametresVoix> parametresAppels = [];

  List<String> get textesPrononces => [
    for (final e in journal)
      if (e.startsWith('parler:')) e.substring(7),
  ];

  @override
  Future<List<InfoVoix>> voixDisponibles() async => voix;

  @override
  Future<void> parler(String texte, ParametresVoix parametres) async {
    journal.add('parler:$texte');
    parametresAppels.add(parametres);
    if (parolePilotee) {
      final c = Completer<void>();
      _enCours.add(c);
      await c.future;
    }
  }

  @override
  Future<void> arreter() async => journal.add('stop');
}
