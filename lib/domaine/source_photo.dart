/// Origine d'une photo, pour distinguer les permissions (REQ-020).
enum OrigineAcces { camera, galerie }

/// L'accès à l'appareil photo ou à la galerie a été refusé (AC-020-3).
class PermissionRefusee implements Exception {
  const PermissionRefusee(this.origine);

  final OrigineAcces origine;

  @override
  String toString() => 'PermissionRefusee($origine)';
}

/// Source de photos : renvoie le chemin d'un fichier image, ou null si
/// l'utilisateur annule. Lève [PermissionRefusee] si l'accès est refusé.
abstract interface class SourcePhoto {
  Future<String?> prendre();

  Future<String?> choisirGalerie();
}
