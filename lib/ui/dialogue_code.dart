import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domaine/verrou.dart';
import 'textes.dart';

/// Demande le code (avec procédure « Code oublié »). Renvoie true si
/// l'édition doit être ouverte : bon code, ou recopie de secours correcte.
Future<bool> demanderCode(
  BuildContext context,
  Verrou verrou,
  Random aleatoire,
) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogueCode(verrou: verrou, aleatoire: aleatoire),
  );
  return r ?? false;
}

class _DialogueCode extends StatefulWidget {
  const _DialogueCode({required this.verrou, required this.aleatoire});

  final Verrou verrou;
  final Random aleatoire;

  @override
  State<_DialogueCode> createState() => _DialogueCodeState();
}

class _DialogueCodeState extends State<_DialogueCode> {
  final TextEditingController _saisie = TextEditingController();
  String? _phrase;
  String? _erreur;

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_phrase == null) {
      if (widget.verrou.verifier(_saisie.text)) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _erreur = Textes.codeIncorrect);
      }
      return;
    }
    final ok = await widget.verrou.verifierPhrase(_saisie.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _erreur = Textes.phraseIncorrecte);
    }
  }

  void _oublie() {
    setState(() {
      _phrase = widget.verrou.phraseSecours(widget.aleatoire);
      _saisie.clear();
      _erreur = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _phrase;
    return AlertDialog(
      title: Text(phrase == null ? Textes.saisirCode : Textes.recopierPhrase),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phrase != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                phrase,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          TextField(
            key: Key(phrase == null ? 'champ-code' : 'champ-phrase'),
            controller: _saisie,
            autofocus: true,
            obscureText: phrase == null,
            keyboardType: phrase == null
                ? TextInputType.number
                : TextInputType.text,
            inputFormatters: phrase == null
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ]
                : null,
            decoration: InputDecoration(
              labelText: phrase == null ? Textes.code : Textes.phraseSaisie,
              errorText: _erreur,
            ),
            onSubmitted: (_) => _valider(),
          ),
          if (phrase == null)
            TextButton(
              onPressed: _oublie,
              child: const Text(Textes.codeOublie),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(Textes.annuler),
        ),
        FilledButton(onPressed: _valider, child: const Text(Textes.valider)),
      ],
    );
  }
}
