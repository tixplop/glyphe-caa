import 'dart:async';

import 'package:flutter/material.dart';

import '../textes.dart';

/// Durée de l'appui long de déverrouillage (AC-011-2).
const Duration dureeAppuiLong = Duration(seconds: 3);

/// Cadenas : un appui maintenu [dureeAppuiLong] appelle [onDeverrouille] ;
/// relâcher avant annule (AC-011-1, AC-011-3).
class Cadenas extends StatefulWidget {
  const Cadenas({super.key, required this.onDeverrouille});

  final VoidCallback onDeverrouille;

  @override
  State<Cadenas> createState() => _CadenasState();
}

class _CadenasState extends State<Cadenas> with SingleTickerProviderStateMixin {
  // L'animation n'est que visuelle ; le délai exact vient du minuteur,
  // armé dès l'appui.
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: dureeAppuiLong,
  );
  Timer? _minuteur;

  @override
  void dispose() {
    _minuteur?.cancel();
    _controleur.dispose();
    super.dispose();
  }

  void _commencer() {
    _minuteur?.cancel();
    _minuteur = Timer(dureeAppuiLong, () {
      _minuteur = null;
      _controleur.reset();
      widget.onDeverrouille();
    });
    _controleur.forward(from: 0);
  }

  void _annuler() {
    // Le cadenas peut avoir disparu (mode édition) avant le relâchement.
    if (!mounted) return;
    _minuteur?.cancel();
    _minuteur = null;
    _controleur.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: Textes.verrouille,
      hint: Textes.cadenasAppuiLong,
      child: Listener(
        key: const Key('cadenas'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _commencer(),
        onPointerUp: (_) => _annuler(),
        onPointerCancel: (_) => _annuler(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: AnimatedBuilder(
            animation: _controleur,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                if (_controleur.isAnimating)
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: _controleur.value,
                      strokeWidth: 5,
                    ),
                  ),
                const Icon(Icons.lock),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
