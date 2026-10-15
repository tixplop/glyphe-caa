import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'domaine/horloge.dart';
import 'plateforme/stockage_fichier.dart';
import 'plateforme/voix_flutter_tts.dart';
import 'ui/app.dart';
import 'ui/etat_appli.dart';
import 'ui/textes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dossier = Directory(
      '${(await getApplicationSupportDirectory()).path}/glyphe',
    );
    await dossier.create(recursive: true);
    final etat = EtatAppli(
      stockage: StockageFichier(dossier),
      voix: VoixFlutterTts(),
      horloge: const HorlogeSysteme(),
      jsonExemples: await EtatAppli.chargerExemples(),
    );
    await etat.init();
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
