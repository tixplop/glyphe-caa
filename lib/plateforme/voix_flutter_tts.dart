import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domaine/choix_voix.dart';
import '../domaine/voix.dart';

/// Adaptateur [Voix] au-dessus de `flutter_tts`.
///
/// Échelle de débit : l'appli utilise 0,5×–2× (1× = normal). `flutter_tts`
/// attend 0–1 : sur Android 1× correspond à 0,5 ; sur iOS 0,5 correspond à
/// `AVSpeechUtteranceDefaultSpeechRate`, donc 1× -> 0,5 aussi. La conversion
/// est linéaire (x/2) : 0,5× -> 0,25 ; 1× -> 0,5 ; 2× -> 1,0.
///
/// L'identifiant d'une voix est `nom|locale` (les deux sont nécessaires à
/// `setVoice`).
class VoixFlutterTts implements Voix {
  VoixFlutterTts([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialise = false;

  /// `speak` ne se termine alors qu'à la fin de la prononciation.
  Future<void> _initialiser() async {
    if (_initialise) return;
    _initialise = true;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('Voix : fin de prononciation non suivie ($e)');
    }
  }

  static double debitPlateforme(double debit) =>
      (borneDebit(debit) / 2).clamp(0.0, 1.0).toDouble();

  static String idVoix(String nom, String locale) => '$nom|$locale';

  static ({String nom, String locale})? _decoderId(String id) {
    final i = id.lastIndexOf('|');
    if (i < 0) return null;
    return (nom: id.substring(0, i), locale: id.substring(i + 1));
  }

  @override
  Future<List<InfoVoix>> voixDisponibles() async {
    try {
      final brut = await _tts.getVoices;
      if (brut is! List) return const [];
      final voix = <InfoVoix>[];
      for (final e in brut) {
        if (e is! Map) continue;
        final nom = e['name'];
        final locale = e['locale'];
        if (nom is! String || nom.isEmpty) continue;
        final loc = locale is String ? locale : '';
        voix.add(InfoVoix(id: idVoix(nom, loc), nom: nom, locale: loc));
      }
      return voix;
    } catch (e) {
      debugPrint('Voix : liste indisponible ($e)');
      return const [];
    }
  }

  @override
  Future<void> parler(String texte, ParametresVoix parametres) async {
    try {
      await _initialiser();
      await _tts.stop();
      final voix = parametres.voixId == null
          ? null
          : _decoderId(parametres.voixId!);
      if (voix != null) {
        await _tts.setVoice({'name': voix.nom, 'locale': voix.locale});
      } else {
        // Pas de voix choisie (ou identifiant indécodable) : défaut système.
        await _tts.clearVoice();
      }
      await _tts.setSpeechRate(debitPlateforme(parametres.debit));
      await _tts.setPitch(borneHauteur(parametres.hauteur));
      await _tts.setVolume(borneVolume(parametres.volume));
      await _tts.speak(texte);
    } catch (e) {
      debugPrint('Voix : échec de la prononciation ($e)');
    }
  }

  @override
  Future<void> arreter() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Voix : échec de l\'arrêt ($e)');
    }
  }
}
