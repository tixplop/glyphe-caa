import 'modeles.dart';

/// Onglet de la barre de navigation (REQ-031) : un par grille atteignable
/// depuis l'accueil, dérivé des données sans rien stocker de plus.
class Onglet {
  const Onglet({
    required this.grilleId,
    required this.libelle,
    required this.estAccueil,
    this.image = const ImageAucune(),
  });

  final String grilleId;
  final String libelle;
  final bool estAccueil;

  /// Image de la case-dossier (AC-031-2) ; [ImageAucune] pour l'accueil.
  final ImageCase image;

  @override
  bool operator ==(Object other) =>
      other is Onglet &&
      other.grilleId == grilleId &&
      other.libelle == libelle &&
      other.estAccueil == estAccueil &&
      other.image == image;

  @override
  int get hashCode => Object.hash(grilleId, libelle, estAccueil, image);
}

/// Onglets : l'accueil, puis un onglet par grille cible existante des
/// cases-dossiers visibles de l'accueil, dans l'ordre ligne puis colonne,
/// une seule fois par grille (AC-031-2).
List<Onglet> ongletsDe(Donnees donnees) {
  final accueil = donnees.grillePar(donnees.accueilId);
  if (accueil == null) return const [];
  final res = <Onglet>[
    Onglet(grilleId: accueil.id, libelle: accueil.nom, estAccueil: true),
  ];
  final dossiers =
      accueil.casesVisibles.where((c) => c.type == TypeCase.dossier).toList()
        ..sort((a, b) {
          final l = a.ligne.compareTo(b.ligne);
          return l != 0 ? l : a.colonne.compareTo(b.colonne);
        });
  final vus = <String>{accueil.id};
  for (final c in dossiers) {
    final cible = c.cibleId == null ? null : donnees.grillePar(c.cibleId!);
    if (cible == null || !vus.add(cible.id)) continue;
    res.add(
      Onglet(
        grilleId: cible.id,
        libelle: c.libelle.isEmpty ? cible.nom : c.libelle,
        estAccueil: false,
        image: c.image,
      ),
    );
  }
  return res;
}

/// Identifiant de la grille de l'onglet actif : première grille du [chemin]
/// après son dernier passage par l'accueil, ou l'accueil lui-même ; null si elle n'a pas d'onglet
/// (AC-031-4).
String? ongletActif(Donnees donnees, List<String> chemin) {
  if (chemin.isEmpty) return null;
  if (chemin.last == donnees.accueilId) return donnees.accueilId;
  final apres = chemin.sublist(chemin.lastIndexOf(donnees.accueilId) + 1);
  final id = apres.isEmpty ? donnees.accueilId : apres.first;
  return ongletsDe(donnees).any((o) => o.grilleId == id) ? id : null;
}
