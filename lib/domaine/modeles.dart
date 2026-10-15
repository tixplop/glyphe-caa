/// Modèle de données immuable (DEC-008). Pur Dart.
library;

const int versionFormatCourant = 2;
const int tailleMin = 1;
const int tailleMax = 8;

enum TypeCase { mot, dossier }

/// Catégorie grammaticale d'une case (clé de Fitzgerald modifiée, REQ-032).
enum Categorie {
  personne,
  action,
  objet,
  description,
  social,
  question,
  petitMot,
}

/// Image d'une case : pictogramme ARASAAC, photo locale ou aucune.
sealed class ImageCase {
  const ImageCase();
}

class ImageArasaac extends ImageCase {
  const ImageArasaac(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is ImageArasaac && other.id == id;

  @override
  int get hashCode => Object.hash('arasaac', id);
}

class ImagePhoto extends ImageCase {
  const ImagePhoto(this.fichier);
  final String fichier;

  @override
  bool operator ==(Object other) =>
      other is ImagePhoto && other.fichier == fichier;

  @override
  int get hashCode => Object.hash('photo', fichier);
}

class ImageAucune extends ImageCase {
  const ImageAucune();

  @override
  bool operator ==(Object other) => other is ImageAucune;

  @override
  int get hashCode => 0;
}

class Case {
  const Case({
    required this.id,
    required this.ligne,
    required this.colonne,
    required this.type,
    this.libelle = '',
    this.textePrononce = '',
    this.image = const ImageAucune(),
    this.categorie = Categorie.petitMot,
    this.cibleId,
  });

  final String id;
  final int ligne;
  final int colonne;
  final TypeCase type;
  final String libelle;
  final String textePrononce;
  final ImageCase image;

  /// Catégorie grammaticale (détermine les couleurs de la case).
  final Categorie categorie;

  /// Pour un dossier : identifiant de la grille cible.
  final String? cibleId;

  Case copyWith({
    String? id,
    int? ligne,
    int? colonne,
    TypeCase? type,
    String? libelle,
    String? textePrononce,
    ImageCase? image,
    Categorie? categorie,
    String? Function()? cibleId,
  }) => Case(
    id: id ?? this.id,
    ligne: ligne ?? this.ligne,
    colonne: colonne ?? this.colonne,
    type: type ?? this.type,
    libelle: libelle ?? this.libelle,
    textePrononce: textePrononce ?? this.textePrononce,
    image: image ?? this.image,
    categorie: categorie ?? this.categorie,
    cibleId: cibleId != null ? cibleId() : this.cibleId,
  );

  @override
  bool operator ==(Object other) =>
      other is Case &&
      other.id == id &&
      other.ligne == ligne &&
      other.colonne == colonne &&
      other.type == type &&
      other.libelle == libelle &&
      other.textePrononce == textePrononce &&
      other.image == image &&
      other.categorie == categorie &&
      other.cibleId == cibleId;

  @override
  int get hashCode => Object.hash(
    id,
    ligne,
    colonne,
    type,
    libelle,
    textePrononce,
    image,
    categorie,
    cibleId,
  );
}

class Grille {
  Grille({
    required this.id,
    required this.nom,
    required this.lignes,
    required this.colonnes,
    List<Case> cases = const [],
  }) : cases = List.unmodifiable(cases);

  final String id;
  final String nom;
  final int lignes;
  final int colonnes;
  final List<Case> cases;

  /// Cases dont la position est dans la taille courante (REQ-018).
  List<Case> get casesVisibles => cases
      .where((c) => c.ligne < lignes && c.colonne < colonnes)
      .toList(growable: false);

  /// Change la taille (bornée à 1..8) sans supprimer aucune case.
  Grille redimensionner(int nouvLignes, int nouvColonnes) => copyWith(
    lignes: nouvLignes.clamp(tailleMin, tailleMax),
    colonnes: nouvColonnes.clamp(tailleMin, tailleMax),
  );

  /// Premier emplacement (ligne, colonne) libre dans la taille courante,
  /// en ordre ligne par ligne ; null si la grille visible est pleine.
  ({int ligne, int colonne})? emplacementLibre() {
    final pris = {for (final c in cases) (c.ligne, c.colonne)};
    for (var l = 0; l < lignes; l++) {
      for (var c = 0; c < colonnes; c++) {
        if (!pris.contains((l, c))) return (ligne: l, colonne: c);
      }
    }
    return null;
  }

  Grille copyWith({
    String? id,
    String? nom,
    int? lignes,
    int? colonnes,
    List<Case>? cases,
  }) => Grille(
    id: id ?? this.id,
    nom: nom ?? this.nom,
    lignes: lignes ?? this.lignes,
    colonnes: colonnes ?? this.colonnes,
    cases: cases ?? this.cases,
  );
}

class Reglages {
  const Reglages({
    this.voixId,
    this.debit = 1.0,
    this.hauteur = 1.0,
    this.volume = 1.0,
    this.delaiAntiRepetitionMs = 0,
    this.retourAccueilApresMot = false,
  });

  final String? voixId;
  final double debit;
  final double hauteur;
  final double volume;
  final int delaiAntiRepetitionMs;
  final bool retourAccueilApresMot;

  Reglages copyWith({
    String? Function()? voixId,
    double? debit,
    double? hauteur,
    double? volume,
    int? delaiAntiRepetitionMs,
    bool? retourAccueilApresMot,
  }) => Reglages(
    voixId: voixId != null ? voixId() : this.voixId,
    debit: debit ?? this.debit,
    hauteur: hauteur ?? this.hauteur,
    volume: volume ?? this.volume,
    delaiAntiRepetitionMs: delaiAntiRepetitionMs ?? this.delaiAntiRepetitionMs,
    retourAccueilApresMot: retourAccueilApresMot ?? this.retourAccueilApresMot,
  );
}

class Donnees {
  Donnees({
    this.versionFormat = versionFormatCourant,
    required this.accueilId,
    List<Grille> grilles = const [],
    this.reglages = const Reglages(),
  }) : grilles = List.unmodifiable(grilles);

  final int versionFormat;
  final String accueilId;
  final List<Grille> grilles;
  final Reglages reglages;

  Grille? grillePar(String id) {
    for (final g in grilles) {
      if (g.id == id) return g;
    }
    return null;
  }

  Donnees copyWith({
    String? accueilId,
    List<Grille>? grilles,
    Reglages? reglages,
  }) => Donnees(
    versionFormat: versionFormat,
    accueilId: accueilId ?? this.accueilId,
    grilles: grilles ?? this.grilles,
    reglages: reglages ?? this.reglages,
  );
}
