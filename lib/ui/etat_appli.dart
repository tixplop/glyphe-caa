import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../domaine/banque_pictos.dart';
import '../domaine/choix_voix.dart';
import '../domaine/donnees_initiales.dart';
import '../domaine/horloge.dart';
import '../domaine/modeles.dart';
import '../domaine/photos.dart';
import '../domaine/sauvegarde.dart';
import '../domaine/session.dart';
import '../domaine/source_photo.dart';
import '../domaine/stockage.dart';
import '../domaine/verrou.dart';
import '../domaine/voix.dart';
import '../plateforme/partage.dart';

/// Chemin du fichier embarqué des grilles d'exemple.
const String cheminExemples = 'assets/exemples/grilles_exemple.json';

/// Chemin de l'index embarqué de la banque ARASAAC.
const String cheminIndexPictos = 'assets/arasaac/index.json';

/// Chemin du fichier embarqué des phrases de secours.
const String cheminPhrases = 'assets/phrases_secours.json';

/// État de l'appli : charge et persiste les données, porte la [Session].
///
/// La grille courante, la barre et le verrouillage ne sont pas persistés :
/// au lancement, accueil, barre vide, verrouillé (AC-025-3).
class EtatAppli extends ChangeNotifier {
  EtatAppli({
    required this.stockage,
    required this.voix,
    required this.horloge,
    required this.jsonExemples,
    this.jsonPhrases = '[]',
    this.banque,
    this.sourcePhoto,
    this.photos,
    this.partage,
    this.choixFichier,
    Directory? dossierTemporaire,
    Random? aleatoire,
  }) : aleatoire = aleatoire ?? Random(),
       dossierTemporaire = dossierTemporaire ?? Directory.systemTemp;

  /// Charge les exemples depuis les assets embarqués.
  static Future<String> chargerExemples() =>
      rootBundle.loadString(cheminExemples);

  final Stockage stockage;
  final Voix voix;
  final Horloge horloge;
  final String jsonExemples;

  /// Liste JSON des phrases de secours (code oublié).
  final String jsonPhrases;
  final Random aleatoire;

  /// Banque ARASAAC embarquée ; null : recherche de pictos vide.
  final BanquePictos? banque;

  /// Appareil photo et galerie ; null : photos indisponibles.
  final SourcePhoto? sourcePhoto;

  /// Dossier des photos personnelles ; null : photos indisponibles.
  final Photos? photos;

  /// Menu de partage ; null : export indisponible.
  final Partage? partage;

  /// Choix du fichier à importer ; null : import indisponible.
  final ChoixFichier? choixFichier;

  /// Dossier où l'archive d'export est écrite avant partage.
  final Directory dossierTemporaire;

  /// Charge l'index de la banque ARASAAC depuis les assets embarqués.
  static Future<BanquePictos> chargerBanque() async =>
      BanquePictos.depuisJson(await rootBundle.loadString(cheminIndexPictos));

  /// Charge les phrases de secours depuis les assets embarqués.
  static Future<String> chargerPhrases() =>
      rootBundle.loadString(cheminPhrases);

  Session? _session;
  Verrou? _verrou;
  bool _verrouille = true;

  bool get pret => _session != null;

  Session get session {
    final s = _session;
    if (s == null) throw StateError('EtatAppli.init() n\'a pas été appelé');
    return s;
  }

  Verrou get verrou {
    final v = _verrou;
    if (v == null) throw StateError('EtatAppli.init() n\'a pas été appelé');
    return v;
  }

  bool get verrouille => _verrouille;

  /// Mode édition : exactement l'inverse du verrouillage.
  bool get modeEdition => !_verrouille;

  /// Ouvre le mode édition (après appui long et code éventuel).
  void ouvrirEdition() {
    if (!_verrouille) return;
    _verrouille = false;
    notifyListeners();
  }

  /// Retour au mode communication verrouillé (AC-014-1, AC-014-2).
  void verrouiller() {
    if (_verrouille) return;
    _verrouille = true;
    notifyListeners();
  }

  int _activitesSysteme = 0;

  /// Une activité du système (sélecteur de fichier, partage, photo) est en
  /// cours : l'appli passe alors en arrière-plan sans que l'utilisateur la
  /// quitte.
  bool get activiteSystemeEnCours => _activitesSysteme > 0;

  /// Exécute [action] (activité du système au-dessus de l'appli) en
  /// ignorant le reverrouillage par cycle de vie pendant ce temps.
  Future<T> pendantActiviteSysteme<T>(Future<T> Function() action) async {
    _activitesSysteme++;
    try {
      return await action();
    } finally {
      _activitesSysteme--;
      if (_activitesSysteme == 0) verrouillerSiAbsenceLongue();
    }
  }

  /// Durée d'absence (appli en arrière-plan pendant une activité du système)
  /// au-delà de laquelle l'appli se reverrouille (DEC-010, hypothèse).
  static const Duration absenceMaximale = Duration(seconds: 60);

  DateTime? _pauseIgnoreeA;

  /// Contrôle l'absence mémorisée : chaque absence est mesurée séparément
  /// (la pause est oubliée dès qu'elle est contrôlée) et l'appli se
  /// reverrouille seulement si cette absence dépasse [absenceMaximale]
  /// (AC-014-2).
  void verrouillerSiAbsenceLongue() {
    final debut = _pauseIgnoreeA;
    if (debut == null) return;
    _pauseIgnoreeA = null;
    if (horloge.maintenant().difference(debut) > absenceMaximale) {
      verrouiller();
    }
  }

  /// Retour au premier plan : contrôle de l'absence puis revérification de
  /// la voix (AC-022-1).
  Future<void> surRetourPremierPlan() {
    verrouillerSiAbsenceLongue();
    return verifierVoix();
  }

  /// Reverrouillage déclenché par le cycle de vie (arrière-plan, fermeture,
  /// AC-014-2) ; ignoré pendant une activité du système.
  void verrouillerSurCycleDeVie() {
    if (activiteSystemeEnCours) {
      _pauseIgnoreeA ??= horloge.maintenant();
      return;
    }
    verrouiller();
  }

  /// Charge les données (ou crée les exemples) et ouvre une session neuve.
  Future<void> init() async {
    final donnees = await chargerOuInitialiser(stockage, jsonExemples);
    final phrases = (jsonDecode(jsonPhrases) as List<dynamic>).cast<String>();
    _verrou = await Verrou.charger(stockage, phrases);
    _session = Session(donnees, voix, horloge);
    _verrouille = true;
    await verifierVoix();
  }

  List<InfoVoix> _voixDisponibles = const [];
  ChoixVoix _choixVoix = const ChoixVoix(
    voixId: null,
    voixEnregistreeIndisponible: false,
    aucuneVoix: false,
  );

  /// Voix de l'appareil, françaises d'abord (AC-021-1).
  List<InfoVoix> get voixDisponibles => _voixDisponibles;

  /// Aucune voix de synthèse sur l'appareil (AC-005-2).
  bool get aucuneVoix => _choixVoix.aucuneVoix;

  /// La voix enregistrée a disparu (AC-022-1).
  bool get voixEnregistreeIndisponible =>
      _choixVoix.voixEnregistreeIndisponible;

  /// Interroge le moteur de synthèse et recalcule la voix effective (au
  /// lancement et au retour au premier plan). Une erreur du moteur est
  /// traitée comme « aucune voix » : la communication continue (REQ-005).
  Future<void> verifierVoix() async {
    List<InfoVoix> liste;
    try {
      liste = trierVoix(await voix.voixDisponibles());
    } catch (_) {
      liste = const [];
    }
    _voixDisponibles = liste;
    _choixVoix = choisirVoix(liste, session.donnees.reglages.voixId);
    session.choixVoix = _choixVoix;
    notifyListeners();
  }

  /// Enregistre de nouveaux réglages (voix, délai, retour à l'accueil).
  Future<void> modifierReglages(Reglages r) {
    // La partie synchrone de modifierDonnees met déjà les données de session
    // à jour : voix effective et abonnés suivent avant la fin de l'écriture,
    // y compris si celle-ci échoue (la session garde alors les nouvelles
    // valeurs en mémoire).
    final ecriture = modifierDonnees(session.donnees.copyWith(reglages: r));
    _choixVoix = choisirVoix(_voixDisponibles, r.voixId);
    session.choixVoix = _choixVoix;
    notifyListeners();
    return ecriture;
  }

  /// Nouvel identifiant unique pour une case ou une grille.
  String nouvelId(String prefixe) =>
      '$prefixe-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${aleatoire.nextInt(1 << 32).toRadixString(36)}';

  /// Remplace les données et les enregistre. Lève [ArgumentError] (rien
  /// n'est écrit) si la grille d'accueil n'existe pas.
  Future<void> modifierDonnees(Donnees d) async {
    if (d.grillePar(d.accueilId) == null) {
      throw ArgumentError.value(
        d.accueilId,
        'accueilId',
        'grille d\'accueil introuvable',
      );
    }
    session.donnees = d;
    await stockage.enregistrer(d);
    await nettoyerPhotos();
  }

  /// Supprime les photos qu'aucune case ne référence plus (AC-020-4).
  /// Meilleur effort : une erreur d'entrée-sortie n'est pas remontée.
  Future<void> nettoyerPhotos() async {
    try {
      await photos?.nettoyerPhotosInutilisees(session.donnees);
    } on FileSystemException {
      // Les fichiers restants seront supprimés au prochain nettoyage.
    }
  }

  /// Écrit l'archive de sauvegarde dans le dossier temporaire puis ouvre le
  /// menu de partage (AC-023-1). Lève une exception si l'export échoue.
  Future<void> exporterSauvegarde() async {
    final p = partage;
    if (p == null) throw StateError('Partage indisponible');
    final dossierPhotos =
        photos?.dossier ?? Directory('${dossierTemporaire.path}/sans-photos');
    final octets = exporter(session.donnees, dossierPhotos);
    await dossierTemporaire.create(recursive: true);
    await supprimerArchivesExportees();
    final fichier = File(
      '${dossierTemporaire.path}/${nomFichierExport(horloge.maintenant())}',
    );
    await fichier.writeAsBytes(octets, flush: true);
    await pendantActiviteSysteme(() => p.partagerFichier(fichier.path));
  }

  /// Supprime les archives d'export restées dans le dossier temporaire
  /// (appelé au démarrage par `main` et avant chaque export). Meilleur effort.
  Future<void> supprimerArchivesExportees() async {
    try {
      if (!await dossierTemporaire.exists()) return;
      await for (final f in dossierTemporaire.list()) {
        if (f is File && estNomFichierExport(f.uri.pathSegments.last)) {
          await f.delete();
        }
      }
    } on FileSystemException {
      // Elles seront supprimées à un prochain passage.
    }
  }

  /// Demande un fichier de sauvegarde et l'analyse sans rien modifier.
  /// Null : l'utilisateur a annulé le choix.
  Future<ResultatAnalyse?> choisirSauvegarde() async {
    final choix = choixFichier;
    if (choix == null) throw StateError('Choix de fichier indisponible');
    final Uint8List? octets;
    try {
      octets = await pendantActiviteSysteme(choix.choisir);
    } on FichierTropVolumineux {
      return const ErreurSauvegarde(MotifErreur.invalide, 'fichier trop gros');
    }
    if (octets == null) return null;
    return analyserSauvegarde(octets);
  }

  /// Remplace toutes les données par [sauvegarde] (atomique, AC-024-7) puis
  /// remet la session à l'accueil et revérifie la voix. Le code n'est pas
  /// touché (AC-024-6). En cas d'échec, l'état d'avant est conservé.
  Future<void> appliquerSauvegarde(SauvegardeValide sauvegarde) async {
    final s = stockage;
    if (s is! StockageRemplacable) {
      throw StateError('Ce stockage ne sait pas importer');
    }
    await s.remplacerTout(sauvegarde);
    session.donnees = sauvegarde.donnees;
    session.toutEffacer();
    session.accueil();
    // Un nom de photo peut désigner un autre contenu qu'avant.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await verifierVoix();
    } catch (_) {
      // Les données sont déjà remplacées : l'import a réussi.
    }
  }
}
