import 'dart:io';

import 'package:flutter/services.dart';

/// Charge la police Atkinson Hyperlegible du produit : sans elle, les tests
/// mesurent le texte avec la police carrée par défaut (largeurs fausses).
Future<void> chargerPolice() async {
  final chargeur = FontLoader('AtkinsonHyperlegible');
  for (final f in ['Regular', 'Bold']) {
    final octets = File('assets/fonts/AtkinsonHyperlegible-$f.ttf')
        .readAsBytesSync();
    chargeur.addFont(Future.value(ByteData.sublistView(octets)));
  }
  await chargeur.load();
}
