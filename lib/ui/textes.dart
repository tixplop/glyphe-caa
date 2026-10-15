/// Point unique des textes de l'interface (REQ-029).
class Textes {
  const Textes._();

  static const String titreAppli = 'Glyphe';

  static const String lire = 'Lire';
  static const String effacerDernier = 'Effacer le dernier';
  static const String toutEffacer = 'Tout effacer';
  static const String retour = 'Retour';
  static const String accueil = 'Accueil';
  static const String verrouille = 'Verrouillé';
  static const String phrase = 'Phrase. Appuyer pour lire';
  static const String caseSansNom = 'case sans nom';
  static const String chargementErreur =
      'Impossible de charger les données de l\'appli.';

  static const String terminer = 'Terminer';
  static const String codeVerrouillage = 'Code de verrouillage';
  static const String cadenasAppuiLong = 'Cadenas, maintenir 3 secondes';
  static const String saisirCode = 'Saisissez le code';
  static const String code = 'Code';
  static const String valider = 'Valider';
  static const String annuler = 'Annuler';
  static const String codeIncorrect = 'Code incorrect';
  static const String codeOublie = 'Code oublié';
  static const String recopierPhrase = 'Recopiez cette phrase';
  static const String phraseSaisie = 'Phrase';
  static const String phraseIncorrecte = 'Phrase incorrecte';
  static const String nouveauCode = 'Nouveau code (4 chiffres)';
  static const String confirmerCode = 'Confirmer le code';
  static const String enregistrer = 'Enregistrer';
  static const String supprimerCode = 'Supprimer le code';
  static const String codeFormat = 'Le code doit comporter 4 chiffres';
  static const String codeDifferent = 'Les deux saisies sont différentes';

  // Édition des cases (REQ-015, REQ-016).
  static const String editionCase = 'Modifier la case';
  static const String nouvelleCase = 'Nouvelle case';
  static const String libelle = 'Libellé';
  static const String textePrononce = 'Texte prononcé';
  static const String couleur = 'Couleur';
  static const String couleurDefaut = 'Couleur par défaut';
  static const String type = 'Type';
  static const String typeMot = 'Mot';
  static const String typeDossier = 'Dossier';
  static const String grilleCible = 'Grille cible';
  static const String nouvelleGrille = 'Nouvelle grille';
  static const String nomNouvelleGrille = 'Nouvelle grille';
  static const String image = 'Image';
  static const String imageAucune = 'aucune';
  static const String ouvrir = 'Ouvrir';
  static const String supprimer = 'Supprimer';
  static const String echanger = 'Échanger avec l\'emplacement…';
  static const String choisirEmplacement = 'Choisissez un emplacement';
  static const String confirmerSuppression = 'Supprimer cette case ?';
  static const String ajouterCase = 'Ajouter une case';
  static const String grilleIntrouvable = 'grille introuvable';
  static const String erreurContenuVide = 'Ajoutez une image ou un libellé';
  static const String erreurCible = 'Choisissez une grille pour ce dossier';
  static const String erreurGrillePleine = 'Agrandissez la grille';
  static const String erreurEdition = 'Modification impossible';
  static const String erreurEnregistrement =
      'Impossible d\'enregistrer les modifications';

  static String emplacement(int ligne, int colonne) =>
      'Ligne ${ligne + 1}, colonne ${colonne + 1}';

  static String dossier(String libelle) => 'dossier $libelle';
}
