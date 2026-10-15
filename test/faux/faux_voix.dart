import 'package:glyphe/domaine/voix.dart';

/// Voix factice : journal ordonné des appels. `parler` n'écrit que
/// `parler:<texte>` ; seul `arreter` écrit `stop`.
class FauxVoix implements Voix {
  FauxVoix({this.voix = const []});

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
  }

  @override
  Future<void> arreter() async => journal.add('stop');
}
