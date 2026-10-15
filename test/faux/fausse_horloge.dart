import 'package:glyphe/domaine/horloge.dart';

/// Horloge factice avançant à la demande.
class FausseHorloge implements Horloge {
  FausseHorloge([DateTime? debut]) : _t = debut ?? DateTime(2026, 1, 1);

  DateTime _t;

  void avancer(Duration d) => _t = _t.add(d);

  @override
  DateTime maintenant() => _t;
}
