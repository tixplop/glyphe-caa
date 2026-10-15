import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domaine/source_photo.dart';

/// Sélection d'une image (injectable pour les tests).
typedef ChoisirImage = Future<XFile?> Function(
  ImageSource source, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
});

Future<XFile?> _choisirParDefaut(
  ImageSource source, {
  double? maxWidth,
  double? maxHeight,
  int? imageQuality,
}) => ImagePicker().pickImage(
  source: source,
  maxWidth: maxWidth,
  maxHeight: maxHeight,
  imageQuality: imageQuality,
);

/// [SourcePhoto] fondée sur `image_picker` : plus grand côté <= 512 px,
/// JPEG qualité 80 (AC-020-2).
class SourcePhotoImagePicker implements SourcePhoto {
  SourcePhotoImagePicker({ChoisirImage? choisir})
    : _choisir = choisir ?? _choisirParDefaut;

  final ChoisirImage _choisir;

  @override
  Future<String?> prendre() => _obtenir(ImageSource.camera);

  @override
  Future<String?> choisirGalerie() => _obtenir(ImageSource.gallery);

  Future<String?> _obtenir(ImageSource source) async {
    try {
      final f = await _choisir(
        source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      return f?.path;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw const PermissionRefusee(OrigineAcces.camera);
      }
      if (e.code == 'photo_access_denied') {
        throw const PermissionRefusee(OrigineAcces.galerie);
      }
      rethrow;
    }
  }
}
