import 'package:glyphe/domaine/source_photo.dart';

/// Source de photos factice : renvoie un chemin, null (annulation) ou refuse.
class FausseSourcePhoto implements SourcePhoto {
  FausseSourcePhoto({this.cheminCamera, this.cheminGalerie});

  String? cheminCamera;
  String? cheminGalerie;
  bool refusCamera = false;
  bool refusGalerie = false;
  int appelsCamera = 0;
  int appelsGalerie = 0;
  Future<void> Function()? pendant;

  @override
  Future<String?> prendre() async {
    appelsCamera++;
    await pendant?.call();
    if (refusCamera) throw const PermissionRefusee(OrigineAcces.camera);
    return cheminCamera;
  }

  @override
  Future<String?> choisirGalerie() async {
    appelsGalerie++;
    await pendant?.call();
    if (refusGalerie) throw const PermissionRefusee(OrigineAcces.galerie);
    return cheminGalerie;
  }
}
