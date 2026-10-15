import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../textes.dart';
import '../tokens.dart';

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
  bool _focus = false;

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
        child: Focus(
          onFocusChange: (v) {
            if (!v) _annuler();
            setState(() => _focus = v);
          },
          onKeyEvent: (_, e) {
            const touches = [
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.numpadEnter,
              LogicalKeyboardKey.space,
            ];
            if (!touches.contains(e.logicalKey)) return KeyEventResult.ignored;
            if (e is KeyDownEvent) {
              _commencer();
            } else if (e is KeyUpEvent) {
              _annuler();
            }
            return KeyEventResult.handled;
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedBuilder(
              animation: _controleur,
              builder: (context, _) => Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (_controleur.isAnimating)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: _controleur.value,
                        strokeWidth: 4,
                      ),
                    ),
                  Icon(
                    Icons.lock_outline,
                    size: 24,
                    color: GlypheTokens.of(context).ink,
                  ),
                  if (_focus)
                    Positioned(
                      left: -2,
                      top: -2,
                      right: -2,
                      bottom: -2,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const Key('anneau-focus'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GlypheTokens.of(context).focus,
                              width: GlypheTokens.anneauFocus,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
