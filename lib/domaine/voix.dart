/// Voix de synthèse disponible sur l'appareil.
class InfoVoix {
  const InfoVoix({required this.id, required this.nom, required this.locale});

  final String id;
  final String nom;
  final String locale;

  @override
  bool operator ==(Object other) =>
      other is InfoVoix &&
      other.id == id &&
      other.nom == nom &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(id, nom, locale);
}

/// Paramètres de prononciation (débit et hauteur en multiplicateurs 0,5–2,
/// volume 0–1).
class ParametresVoix {
  const ParametresVoix({
    this.voixId,
    this.debit = 1.0,
    this.hauteur = 1.0,
    this.volume = 1.0,
  });

  final String? voixId;
  final double debit;
  final double hauteur;
  final double volume;
}

/// Port de synthèse vocale.
abstract class Voix {
  Future<List<InfoVoix>> voixDisponibles();

  /// Prononce [texte] ; interrompt toute parole en cours. Ne lève jamais.
  Future<void> parler(String texte, ParametresVoix parametres);

  Future<void> arreter();
}
