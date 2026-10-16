/// Opérations d'édition sur [Donnees] (REQ-015, REQ-016). Pur Dart.
///
/// Toutes les fonctions renvoient de nouvelles données ; en cas d'erreur
/// elles lèvent [ErreurEdition] sans rien modifier.
library;

import 'modeles.dart';

/// Taille d'une grille créée pour un dossier (REQ-016).
const int tailleNouvelleGrille = 4;

enum CodeErreurEdition {
  /// Ni image ni libellé (AC-015-2).
  contenuVide,

  /// Dossier sans grille cible valide (AC-016-3).
  cibleManquante,

  /// Aucun emplacement visible libre (AC-015-1).
  grillePleine,

  /// Emplacement hors de la taille visible ou déjà occupé.
  emplacementInvalide,
  grilleIntrouvable,
  caseIntrouvable,
  idDejaUtilise,

  /// Nom de grille vide (REQ-017).
  nomInvalide,

  /// La grille d'accueil ne se supprime pas (AC-017-3).
  accueilNonSupprimable,

  /// Lignes ou colonnes hors de 1..8 (AC-018-1).
  tailleInvalide,
}

class ErreurEdition implements Exception {
  const ErreurEdition(this.code);
  final CodeErreurEdition code;

  @override
  String toString() => 'ErreurEdition($code)';
}

/// Grille 4×4 portant le nom de la case-dossier, dont la seule case est une
/// case-retour en (0, 0) (AC-016-2, AC-037-5). [libelleRetour] est fourni par
/// l'UI (le domaine ne dépend pas de `Textes`).
Grille nouvelleGrillePourDossier(
  String nom,
  String id,
  String idRetour,
  String libelleRetour,
) => Grille(
  id: id,
  nom: nom.trim(),
  lignes: tailleNouvelleGrille,
  colonnes: tailleNouvelleGrille,
  cases: [
    Case(
      id: idRetour,
      ligne: 0,
      colonne: 0,
      type: TypeCase.retour,
      libelle: libelleRetour,
      categorie: Categorie.petitMot,
    ),
  ],
);

/// Grilles proposables comme cible : toutes sauf la courante (AC-016-1).
List<Grille> ciblesProposees(Donnees d, String grilleCouranteId) => [
  for (final g in d.grilles)
    if (g.id != grilleCouranteId) g,
];

Grille _grille(Donnees d, String id) {
  final g = d.grillePar(id);
  if (g == null) throw const ErreurEdition(CodeErreurEdition.grilleIntrouvable);
  return g;
}

/// Valide la case et la normalise (un mot n'a pas de cible). [cibleId]
/// est la cible effective (existante, ou la nouvelle grille).
Case _valider(Case c, Donnees d, String grilleId, Grille? nouvelle) {
  if (c.libelle.trim().isEmpty && c.image is ImageAucune) {
    throw const ErreurEdition(CodeErreurEdition.contenuVide);
  }
  if (c.type != TypeCase.dossier) {
    return c.type == TypeCase.retour
        ? c.copyWith(cibleId: () => null, textePrononce: '')
        : c.copyWith(cibleId: () => null);
  }
  if (nouvelle != null) return c.copyWith(cibleId: () => nouvelle.id);
  final cible = c.cibleId;
  if (cible == null || cible == grilleId || d.grillePar(cible) == null) {
    throw const ErreurEdition(CodeErreurEdition.cibleManquante);
  }
  return c;
}

Donnees _remplacer(
  Donnees d,
  String grilleId,
  List<Case> cases, {
  Grille? nouvelle,
}) {
  if (nouvelle != null && d.grillePar(nouvelle.id) != null) {
    throw const ErreurEdition(CodeErreurEdition.idDejaUtilise);
  }
  return d.copyWith(
    grilles: [
      for (final g in d.grilles)
        g.id == grilleId ? g.copyWith(cases: cases) : g,
      ?nouvelle,
    ],
  );
}

/// Ajoute [c] dans la grille : à ([ligne], [colonne]) s'ils sont donnés
/// (libre et visible), sinon au premier emplacement visible libre.
/// [nouvelleGrille] est ajoutée aux données et devient la cible d'un dossier.
Donnees ajouterCase(
  Donnees d,
  String grilleId,
  Case c, {
  int? ligne,
  int? colonne,
  Grille? nouvelleGrille,
}) {
  final g = _grille(d, grilleId);
  if (g.cases.any((x) => x.id == c.id)) {
    throw const ErreurEdition(CodeErreurEdition.idDejaUtilise);
  }
  final int l;
  final int col;
  if (ligne != null && colonne != null) {
    final visible =
        ligne >= 0 && ligne < g.lignes && colonne >= 0 && colonne < g.colonnes;
    final libre = !g.cases.any((x) => x.ligne == ligne && x.colonne == colonne);
    if (!visible || !libre) {
      throw const ErreurEdition(CodeErreurEdition.emplacementInvalide);
    }
    l = ligne;
    col = colonne;
  } else {
    final libre = g.emplacementLibre();
    if (libre == null) {
      throw const ErreurEdition(CodeErreurEdition.grillePleine);
    }
    l = libre.ligne;
    col = libre.colonne;
  }
  final valide = _valider(c, d, grilleId, nouvelleGrille);
  return _remplacer(d, grilleId, [
    ...g.cases,
    valide.copyWith(ligne: l, colonne: col),
  ], nouvelle: nouvelleGrille);
}

/// Remplace la case de même identifiant, en conservant son emplacement.
Donnees modifierCase(
  Donnees d,
  String grilleId,
  Case c, {
  Grille? nouvelleGrille,
}) {
  final g = _grille(d, grilleId);
  final i = g.cases.indexWhere((x) => x.id == c.id);
  if (i < 0) throw const ErreurEdition(CodeErreurEdition.caseIntrouvable);
  final valide = _valider(
    c,
    d,
    grilleId,
    nouvelleGrille,
  ).copyWith(ligne: g.cases[i].ligne, colonne: g.cases[i].colonne);
  final cases = [...g.cases]..[i] = valide;
  return _remplacer(d, grilleId, cases, nouvelle: nouvelleGrille);
}

Donnees supprimerCase(Donnees d, String grilleId, String caseId) {
  final g = _grille(d, grilleId);
  if (!g.cases.any((x) => x.id == caseId)) {
    throw const ErreurEdition(CodeErreurEdition.caseIntrouvable);
  }
  return _remplacer(d, grilleId, [
    for (final x in g.cases)
      if (x.id != caseId) x,
  ]);
}

/// Déplace la case vers l'emplacement visible ([ligne], [colonne]) ; s'il
/// est occupé, les deux cases échangent leurs emplacements (AC-015-6).
Donnees echangerEmplacements(
  Donnees d,
  String grilleId,
  String caseId,
  int ligne,
  int colonne,
) {
  final g = _grille(d, grilleId);
  final src = g.cases.where((x) => x.id == caseId).firstOrNull;
  if (src == null) throw const ErreurEdition(CodeErreurEdition.caseIntrouvable);
  if (ligne < 0 || ligne >= g.lignes || colonne < 0 || colonne >= g.colonnes) {
    throw const ErreurEdition(CodeErreurEdition.emplacementInvalide);
  }
  return _remplacer(d, grilleId, [
    for (final x in g.cases)
      if (x.id == caseId)
        x.copyWith(ligne: ligne, colonne: colonne)
      else if (x.ligne == ligne && x.colonne == colonne)
        x.copyWith(ligne: src.ligne, colonne: src.colonne)
      else
        x,
  ]);
}

/// Renomme la grille (AC-017-1) ; le nom est rogné et ne peut être vide.
Donnees renommerGrille(Donnees d, String grilleId, String nom) {
  final g = _grille(d, grilleId);
  final propre = nom.trim();
  if (propre.isEmpty) throw const ErreurEdition(CodeErreurEdition.nomInvalide);
  return d.copyWith(
    grilles: [
      for (final x in d.grilles) x.id == g.id ? x.copyWith(nom: propre) : x,
    ],
  );
}

/// Supprime la grille (AC-017-2). Les dossiers qui y pointaient gardent leur
/// cible et deviennent orphelins (REQ-008). L'accueil est refusé (AC-017-3).
Donnees supprimerGrille(Donnees d, String grilleId) {
  _grille(d, grilleId);
  if (grilleId == d.accueilId) {
    throw const ErreurEdition(CodeErreurEdition.accueilNonSupprimable);
  }
  return d.copyWith(
    grilles: [
      for (final x in d.grilles)
        if (x.id != grilleId) x,
    ],
  );
}

/// Règle la taille (1..8 chacune) sans supprimer de case : les cases hors
/// taille sont masquées, pas perdues (AC-018-1 à AC-018-3).
Donnees redimensionnerGrille(
  Donnees d,
  String grilleId,
  int lignes,
  int colonnes,
) {
  final g = _grille(d, grilleId);
  if (lignes < tailleMin ||
      lignes > tailleMax ||
      colonnes < tailleMin ||
      colonnes > tailleMax) {
    throw const ErreurEdition(CodeErreurEdition.tailleInvalide);
  }
  final r = g.redimensionner(lignes, colonnes);
  return d.copyWith(grilles: [for (final x in d.grilles) x.id == g.id ? r : x]);
}
