import 'package:flutter/material.dart';

import 'ecran_communication.dart';
import 'etat_appli.dart';
import 'textes.dart';
import 'theme.dart';

class GlypheApp extends StatelessWidget {
  const GlypheApp({super.key, this.etat});

  /// État initialisé (`init()` terminé) ; null : écran d'attente.
  final EtatAppli? etat;

  @override
  Widget build(BuildContext context) {
    final e = etat;
    return MaterialApp(
      title: Textes.titreAppli,
      theme: themeGlyphe(),
      home: e != null && e.pret
          ? EcranCommunication(etat: e)
          : const Scaffold(body: Center(child: Text(Textes.titreAppli))),
    );
  }
}
