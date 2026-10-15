import 'dart:io';

import 'package:flutter/material.dart';

import '../../domaine/modeles.dart';
import '../../domaine/photos.dart';
import '../tokens.dart';

/// Rend le dossier des photos accessible aux images de cases.
class PhotosScope extends InheritedWidget {
  const PhotosScope({super.key, required this.photos, required super.child});

  final Photos? photos;

  static Photos? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotosScope>()?.photos;

  @override
  bool updateShouldNotify(PhotosScope old) => old.photos != photos;
}

/// Image d'une case : pictogramme embarqué, photo locale ou rien.
class ImageCaseWidget extends StatelessWidget {
  const ImageCaseWidget(this.image, {super.key});

  final ImageCase image;

  @override
  Widget build(BuildContext context) {
    Widget absente(BuildContext _, Object _, StackTrace? _) => Icon(
      Icons.image_not_supported_outlined,
      color: GlypheTokens.of(context).inkMuted,
    );
    return switch (image) {
      ImageArasaac(:final id) => Image.asset(
        'assets/arasaac/$id.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: absente,
      ),
      ImagePhoto(:final fichier) => _photo(context, fichier, absente),
      ImageAucune() => const SizedBox.shrink(),
    };
  }

  Widget _photo(
    BuildContext context,
    String fichier,
    ImageErrorWidgetBuilder absente,
  ) {
    final String chemin;
    try {
      final photos = PhotosScope.of(context);
      if (photos == null) return absente(context, fichier, null);
      chemin = photos.resoudre(fichier);
    } on ArgumentError {
      return absente(context, fichier, null);
    }
    return Image.file(
      File(chemin),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: absente,
    );
  }
}
