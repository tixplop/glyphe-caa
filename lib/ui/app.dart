import 'package:flutter/material.dart';

import 'textes.dart';

class GlypheApp extends StatelessWidget {
  const GlypheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Textes.titreAppli,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const Scaffold(body: Center(child: Text(Textes.titreAppli))),
    );
  }
}
