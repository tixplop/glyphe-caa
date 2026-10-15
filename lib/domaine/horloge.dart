/// Port d'horloge (injectable pour les tests).
abstract class Horloge {
  DateTime maintenant();
}

class HorlogeSysteme implements Horloge {
  const HorlogeSysteme();

  @override
  DateTime maintenant() => DateTime.now();
}
