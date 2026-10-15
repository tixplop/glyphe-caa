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
  static const String choisirImage = 'Choisir une image';
  static const String rechercherPicto = 'Rechercher un pictogramme';
  static const String indiceRecherche =
      'Tapez un mot pour chercher un pictogramme';
  static const String aucunPicto = 'Aucun pictogramme trouvé';
  static const String prendrePhoto = 'Prendre une photo';
  static const String choisirGalerie = 'Choisir dans la galerie';
  static const String cameraRefusee =
      'Accès à l\'appareil photo refusé. Autorisez-le dans les réglages '
      'de l\'appareil ; les pictogrammes restent utilisables.';
  static const String galerieRefusee =
      'Accès aux photos refusé. Autorisez-le dans les réglages de '
      'l\'appareil ; les pictogrammes restent utilisables.';
  static const String erreurPhoto = 'Impossible d\'enregistrer cette photo';
  static String picto(String motCle) => 'Pictogramme $motCle';
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

  // Gestion des grilles et taille (REQ-017, REQ-018).
  static const String plus = 'Plus';
  static const String grilles = 'Grilles';
  static const String tailleGrille = 'Taille de la grille';
  static const String renommer = 'Renommer';
  static const String nomGrille = 'Nom de la grille';
  static const String erreurNomGrille = 'Le nom ne peut pas être vide';
  static const String supprimerGrille = 'Supprimer cette grille ?';
  static const String lignes = 'Lignes';
  static const String colonnes = 'Colonnes';
  static const String moinsLignes = 'Moins de lignes';
  static const String plusLignes = 'Plus de lignes';
  static const String moinsColonnes = 'Moins de colonnes';
  static const String plusColonnes = 'Plus de colonnes';
  static String ouvrirGrille(String nom) => 'Ouvrir la grille $nom';
  static String renommerGrille(String nom) => 'Renommer la grille $nom';
  static String supprimerLaGrille(String nom) => 'Supprimer la grille $nom';
  static String confirmationSuppressionGrille(String nom) =>
      'La grille « $nom » sera supprimée. Les dossiers qui y mènent '
      'deviendront orphelins.';

  static String emplacement(int ligne, int colonne) =>
      'Ligne ${ligne + 1}, colonne ${colonne + 1}';

  static String dossier(String libelle) => 'dossier $libelle';

  // Réglages (REQ-004, REQ-005, REQ-010, REQ-021, REQ-022).
  static const String reglages = 'Réglages';
  static const String sectionVoix = 'Voix';
  static const String voixParDefaut = 'Voix par défaut du système';
  static const String aucuneVoix = 'Aucune voix de synthèse disponible';
  static const String installerVoix =
      'Installez une voix dans les réglages de l\'appareil (synthèse '
      'vocale), puis revenez dans Glyphe.';
  static const String voixIndisponible =
      'La voix choisie n\'est plus disponible';
  static const String debit = 'Débit';
  static const String hauteur = 'Hauteur';
  static const String volume = 'Volume';
  static String valeurMultiple(double v) =>
      '${v.toStringAsFixed(1).replaceAll('.', ',')}×';
  static String valeurPourcent(double v) => '${(v * 100).round()} %';
  static const String tester = 'Tester';
  static const String phraseTest = 'Bonjour, je m\'appelle Glyphe';
  static const String delaiAntiRepetition = 'Délai anti-répétition';
  static const String delaiDesactive = 'Désactivé';
  static String delaiSecondes(int ms) =>
      '${(ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 1).replaceAll('.', ',')} s';
  static const String retourAccueilApresMot =
      'Revenir à l\'accueil après un mot';
  static const String codeDeverrouillage = 'Code de déverrouillage';
  static const String sectionSauvegarde = 'Sauvegarde';
  static const String exporter = 'Exporter';
  static const String importer = 'Importer';
  static const String confirmationImport =
      'Toutes les données actuelles seront remplacées';
  static const String remplacer = 'Remplacer';
  static const String sauvegardeInvalide = 'Fichier de sauvegarde invalide';
  static const String sauvegardeTropRecente =
      'Sauvegarde créée par une version plus récente de Glyphe';
  static const String exportImpossible = 'Export impossible';
  static const String importImpossible = 'Import impossible';

  // À propos (REQ-027).
  static const String aPropos = 'À propos';
  static const String attributionArasaac =
      'Les symboles pictographiques utilisés sont la propriété du '
      'Gouvernement d\'Aragon et ont été créés par Sergio Palao pour '
      'ARASAAC (http://www.arasaac.org), qui les distribue sous licence '
      'Creative Commons BY-NC-SA.';
  static const String gratuitNonCommercial =
      'Glyphe est gratuit et non commercial.';
  static const String versionLabel = 'Version';
}
