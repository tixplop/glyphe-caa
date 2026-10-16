/// Verrouillage de l'orientation en paysage (REQ-038).
library;

import 'package:flutter/services.dart';

const orientationsGlyphe = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Limite l'application aux deux orientations paysage.
Future<void> fixerOrientation() =>
    SystemChrome.setPreferredOrientations(orientationsGlyphe);
