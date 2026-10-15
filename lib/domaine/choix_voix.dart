import 'voix.dart';

const double debitMin = 0.5;
const double debitMax = 2.0;
const double hauteurMin = 0.5;
const double hauteurMax = 2.0;
const double volumeMin = 0.0;
const double volumeMax = 1.0;
const double pasReglage = 0.1;

double _borner(double v, double min, double max) =>
    v.isNaN ? min : v.clamp(min, max).toDouble();

/// Borne et arrondit au pas de 0,1.
double _aligner(double v, double min, double max) {
  final b = _borner(v, min, max);
  return _borner((b * 10).roundToDouble() / 10, min, max);
}

double borneDebit(double v) => _aligner(v, debitMin, debitMax);
double borneHauteur(double v) => _aligner(v, hauteurMin, hauteurMax);
double borneVolume(double v) => _borner(v, volumeMin, volumeMax);

bool _estFrancaise(InfoVoix v) {
  final l = v.locale.toLowerCase();
  return l == 'fr' || l.startsWith('fr-') || l.startsWith('fr_');
}

/// Voix `fr*` d'abord, puis ordre alphabétique (AC-021-1).
List<InfoVoix> trierVoix(Iterable<InfoVoix> voix) {
  final liste = voix.toList();
  liste.sort((a, b) {
    final fa = _estFrancaise(a) ? 0 : 1;
    final fb = _estFrancaise(b) ? 0 : 1;
    if (fa != fb) return fa - fb;
    final c = a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return liste;
}

class ChoixVoix {
  const ChoixVoix({
    required this.voixId,
    required this.voixEnregistreeIndisponible,
    required this.aucuneVoix,
  });

  /// Voix à utiliser ; `null` = défaut du système.
  final String? voixId;
  final bool voixEnregistreeIndisponible;
  final bool aucuneVoix;
}

/// Voix effective : enregistrée si présente, sinon première voix française,
/// sinon défaut système (AC-022-1, AC-005-1).
ChoixVoix choisirVoix(List<InfoVoix> disponibles, String? voixEnregistreeId) {
  if (disponibles.isEmpty) {
    return ChoixVoix(
      voixId: null,
      voixEnregistreeIndisponible: voixEnregistreeId != null,
      aucuneVoix: true,
    );
  }
  if (voixEnregistreeId != null &&
      disponibles.any((v) => v.id == voixEnregistreeId)) {
    return ChoixVoix(
      voixId: voixEnregistreeId,
      voixEnregistreeIndisponible: false,
      aucuneVoix: false,
    );
  }
  final triees = trierVoix(disponibles);
  return ChoixVoix(
    voixId: _estFrancaise(triees.first) ? triees.first.id : null,
    voixEnregistreeIndisponible: voixEnregistreeId != null,
    aucuneVoix: false,
  );
}
