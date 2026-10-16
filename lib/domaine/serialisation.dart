/// Conversion `Donnees` <-> JSON, avec validation de cohérence.
library;

import 'modeles.dart';
import 'photos.dart';

class FormatInvalide implements Exception {
  FormatInvalide(this.message);
  final String message;

  @override
  String toString() => 'FormatInvalide: $message';
}

Map<String, Object?> donneesVersJson(Donnees d) => {
  'versionFormat': d.versionFormat,
  'accueilId': d.accueilId,
  'grilles': [for (final g in d.grilles) _grilleVersJson(g)],
  'reglages': _reglagesVersJson(d.reglages),
};

Donnees donneesDepuisJson(Object? json) {
  try {
    final m = _map(json, 'racine');
    final version = _int(m, 'versionFormat');
    if (version < 1 || version > versionFormatCourant) {
      throw FormatInvalide('version de format non gérée : $version');
    }
    final grilles = [
      for (final g in _liste(m, 'grilles')) _grilleDepuis(g, version),
    ];
    final accueilId = _str(m, 'accueilId');
    final ids = <String>{};
    for (final g in grilles) {
      if (!ids.add(g.id)) throw FormatInvalide('grille en double : ${g.id}');
    }
    if (!ids.contains(accueilId)) {
      throw FormatInvalide('grille d\'accueil absente : $accueilId');
    }
    return Donnees(
      accueilId: accueilId,
      grilles: grilles,
      reglages: _reglagesDepuis(m['reglages']),
    );
  } on FormatInvalide {
    rethrow;
  } on TypeError catch (e) {
    throw FormatInvalide('type inattendu : $e');
  }
}

Map<String, Object?> _grilleVersJson(Grille g) => {
  'id': g.id,
  'nom': g.nom,
  'lignes': g.lignes,
  'colonnes': g.colonnes,
  'cases': [for (final c in g.cases) _caseVersJson(c)],
};

Map<String, Object?> _caseVersJson(Case c) => {
  'id': c.id,
  'ligne': c.ligne,
  'colonne': c.colonne,
  'type': c.type.name,
  'libelle': c.libelle,
  'textePrononce': c.textePrononce,
  'image': _imageVersChaine(c.image),
  'categorie': c.categorie.name,
  if (c.type != TypeCase.retour) 'cibleId': c.cibleId,
};

String _imageVersChaine(ImageCase i) => switch (i) {
  ImageArasaac(:final id) => 'arasaac:$id',
  ImagePhoto(:final fichier) => 'photo:$fichier',
  ImageAucune() => 'aucune',
};

ImageCase _imageDepuisChaine(String s) {
  if (s == 'aucune') return const ImageAucune();
  if (s.startsWith('arasaac:')) {
    final id = int.tryParse(s.substring(8));
    if (id != null) return ImageArasaac(id);
  } else if (s.startsWith('photo:') && nomPhotoValide(s.substring(6))) {
    return ImagePhoto(s.substring(6));
  }
  throw FormatInvalide('image inconnue : $s');
}

Map<String, Object?> _reglagesVersJson(Reglages r) => {
  'voixId': r.voixId,
  'debit': r.debit,
  'hauteur': r.hauteur,
  'volume': r.volume,
  'delaiAntiRepetitionMs': r.delaiAntiRepetitionMs,
  'retourAccueilApresMot': r.retourAccueilApresMot,
};

Reglages _reglagesDepuis(Object? json) {
  final m = _map(json, 'reglages');
  final voix = m['voixId'];
  if (voix != null && voix is! String) {
    throw FormatInvalide('voixId doit être une chaîne');
  }
  final retour = m['retourAccueilApresMot'];
  if (retour is! bool) {
    throw FormatInvalide('retourAccueilApresMot doit être un booléen');
  }
  return Reglages(
    voixId: voix as String?,
    debit: _num(m, 'debit'),
    hauteur: _num(m, 'hauteur'),
    volume: _num(m, 'volume'),
    delaiAntiRepetitionMs: _int(m, 'delaiAntiRepetitionMs'),
    retourAccueilApresMot: retour,
  );
}

Grille _grilleDepuis(Object? json, int version) {
  final m = _map(json, 'grille');
  final lignes = _int(m, 'lignes');
  final colonnes = _int(m, 'colonnes');
  final id = _str(m, 'id');
  if (lignes < tailleMin ||
      lignes > tailleMax ||
      colonnes < tailleMin ||
      colonnes > tailleMax) {
    throw FormatInvalide('taille hors bornes pour la grille $id');
  }
  final cases = [for (final c in _liste(m, 'cases')) _caseDepuis(c, version)];
  final positions = <(int, int)>{};
  final ids = <String>{};
  for (final c in cases) {
    if (!positions.add((c.ligne, c.colonne))) {
      throw FormatInvalide(
        'position en double (${c.ligne}, ${c.colonne}) dans $id',
      );
    }
    if (!ids.add(c.id)) throw FormatInvalide('case en double : ${c.id}');
  }
  return Grille(
    id: id,
    nom: _str(m, 'nom'),
    lignes: lignes,
    colonnes: colonnes,
    cases: cases,
  );
}

Case _caseDepuis(Object? json, int version) {
  final m = _map(json, 'case');
  final nomType = _str(m, 'type');
  final type = TypeCase.values.where((t) => t.name == nomType).firstOrNull;
  if (type == null) throw FormatInvalide('type de case inconnu : $nomType');
  final ligne = _int(m, 'ligne');
  final colonne = _int(m, 'colonne');
  if (ligne < 0 || colonne < 0) {
    throw FormatInvalide('position négative');
  }
  final Categorie categorie;
  if (type == TypeCase.retour && version < 3) {
    throw FormatInvalide('case-retour interdite avant la version 3');
  }
  if (version == 1) {
    final couleur = m['couleur'];
    if (couleur != null && couleur is! int) {
      throw FormatInvalide('couleur doit être un entier');
    }
    categorie = categorieDepuisCouleurV1(couleur as int?);
  } else {
    final nomCategorie = _str(m, 'categorie');
    final trouvee = Categorie.values
        .where((c) => c.name == nomCategorie)
        .firstOrNull;
    if (trouvee == null) {
      throw FormatInvalide('catégorie inconnue : $nomCategorie');
    }
    categorie = trouvee;
  }
  final cible = m['cibleId'];
  if (cible != null && cible is! String) {
    throw FormatInvalide('cibleId doit être une chaîne');
  }
  if (type == TypeCase.retour && cible != null) {
    throw FormatInvalide('une case-retour n\'a pas de cibleId');
  }
  return Case(
    id: _str(m, 'id'),
    ligne: ligne,
    colonne: colonne,
    type: type,
    libelle: _str(m, 'libelle'),
    textePrononce: _str(m, 'textePrononce'),
    image: _imageDepuisChaine(_str(m, 'image')),
    categorie: categorie,
    cibleId: cible as String?,
  );
}

Map<String, Object?> _map(Object? v, String ou) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  throw FormatInvalide('objet attendu : $ou');
}

List<Object?> _liste(Map<String, Object?> m, String cle) {
  final v = m[cle];
  if (v is List) return v.cast<Object?>();
  throw FormatInvalide('liste attendue : $cle');
}

String _str(Map<String, Object?> m, String cle) {
  final v = m[cle];
  if (v is String) return v;
  throw FormatInvalide('chaîne attendue : $cle');
}

int _int(Map<String, Object?> m, String cle) {
  final v = m[cle];
  if (v is int) return v;
  throw FormatInvalide('entier attendu : $cle');
}

double _num(Map<String, Object?> m, String cle) {
  final v = m[cle];
  if (v is num) return v.toDouble();
  throw FormatInvalide('nombre attendu : $cle');
}

/// Conversion d'une couleur de case de la version 1 (ARGB) en catégorie
/// (AC-032-5). Toute valeur inconnue ou absente donne « petits mots ».
Categorie categorieDepuisCouleurV1(int? couleur) => switch (couleur) {
  0xFFFFF9C4 => Categorie.personne,
  0xFFC8E6C9 => Categorie.action,
  0xFFFFCCBC => Categorie.objet,
  0xFFBBDEFB || 0xFFB2EBF2 => Categorie.description,
  0xFFF8BBD0 => Categorie.social,
  0xFFE1BEE7 => Categorie.question,
  _ => Categorie.petitMot,
};
