import 'dart:io';

import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';

/// Image d'une case : pictogramme embarqué, photo locale ou rien.
class ImageCaseWidget extends StatelessWidget {
  const ImageCaseWidget(this.image, {super.key});

  final ImageCase image;

  @override
  Widget build(BuildContext context) {
    Widget absente(BuildContext _, Object _, StackTrace? _) =>
        const Icon(Icons.image_not_supported_outlined, color: Colors.black54);
    return switch (image) {
      ImageArasaac(:final id) => Image.asset(
        'assets/arasaac/$id.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: absente,
      ),
      ImagePhoto(:final fichier) => Image.file(
        File(fichier),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: absente,
      ),
      ImageAucune() => const SizedBox.shrink(),
    };
  }
}
