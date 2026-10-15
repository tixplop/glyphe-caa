import 'package:glyphe/domaine/texte_normalise.dart';

/// Sélection des pictos ARASAAC à embarquer (pur Dart, sans réseau).
///
/// [pictos] : JSON décodé de `GET /v1/pictograms/all/fr`.
/// [motsObligatoires] : mots dont les pictos sont toujours retenus.
/// Retourne l'index `[{id, motsCles: [...]}]`.
List<Map<String, Object>> selectionnerPictos(
  List<dynamic> pictos, {
  Set<String> motsObligatoires = const {},
  int plafond = 3000,
}) {
  final obligatoires = motsObligatoires.map(normaliserTexte).toSet();
  final forces = <_Candidat>[];
  final aac = <_Candidat>[];
  for (final p in pictos) {
    if (p is! Map) continue;
    if (p['violence'] == true || p['sex'] == true) continue;
    final id = p['_id'];
    if (id is! int) continue;
    final mots = <String>[];
    for (final k in (p['keywords'] as List? ?? const [])) {
      final mot = k is Map ? k['keyword'] : null;
      if (mot is String && mot.trim().isNotEmpty) mots.add(mot.trim());
    }
    if (mots.isEmpty) continue;
    final c = _Candidat(id, mots, (p['downloads'] as num?)?.toInt() ?? 0);
    if (mots.any((m) => obligatoires.contains(normaliserTexte(m)))) {
      forces.add(c);
    } else if (p['aac'] == true) {
      aac.add(c);
    }
  }
  int ordre(_Candidat a, _Candidat b) {
    final d = b.telechargements.compareTo(a.telechargements);
    return d != 0 ? d : a.id.compareTo(b.id);
  }

  forces.sort(ordre);
  aac.sort(ordre);
  final retenus = [
    ...forces,
    ...aac.take((plafond - forces.length).clamp(0, plafond)),
  ];
  retenus.sort((a, b) => a.id.compareTo(b.id));
  return [
    for (final c in retenus) {'id': c.id, 'motsCles': c.mots},
  ];
}

class _Candidat {
  _Candidat(this.id, this.mots, this.telechargements);

  final int id;
  final List<String> mots;
  final int telechargements;
}
