import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'domaine/horloge.dart';
import 'domaine/photos.dart';
import 'plateforme/orientation.dart';
import 'plateforme/partage.dart';
import 'plateforme/source_photo_image_picker.dart';
import 'plateforme/stockage_fichier.dart';
import 'plateforme/voix_flutter_tts.dart';
import 'ui/app.dart';
import 'ui/etat_appli.dart';
import 'ui/textes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fixerOrientation();
  try {
    final dossier = Directory(
      '${(await getApplicationSupportDirectory()).path}/glyphe',
    );
    await dossier.create(recursive: true);
    final stockage = StockageFichier(dossier);
    final etat = EtatAppli(
      stockage: stockage,
      voix: VoixFlutterTts(),
      horloge: const HorlogeSysteme(),
      jsonExemples: await EtatAppli.chargerExemples(),
      jsonPhrases: await EtatAppli.chargerPhrases(),
      banque: await EtatAppli.chargerBanque(),
      sourcePhoto: SourcePhotoImagePicker(),
      photos: Photos(stockage.dossierPhotos),
      partage: const PartageSharePlus(),
      choixFichier: const ChoixFichierPicker(),
      dossierTemporaire: await getTemporaryDirectory(),
    );
    await etat.init();
    await etat.supprimerArchivesExportees();
    runApp(GlypheApp(etat: etat));
  } catch (e, pile) {
    FlutterError.reportError(FlutterErrorDetails(exception: e, stack: pile));
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text(Textes.chargementErreur))),
      ),
    );
  }
}
