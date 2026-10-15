import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domaine/verrou.dart';
import 'textes.dart';
import 'widgets/bouton_retour.dart';

/// Définir, modifier ou supprimer le code de 4 chiffres (REQ-012).
class EcranCode extends StatefulWidget {
  const EcranCode({super.key, required this.verrou});

  final Verrou verrou;

  @override
  State<EcranCode> createState() => _EcranCodeState();
}

class _EcranCodeState extends State<EcranCode> {
  final TextEditingController _nouveau = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    try {
      await widget.verrou.definirCode(_nouveau.text, _confirmation.text);
    } on CodeInvalide catch (e) {
      if (!mounted) return;
      setState(() {
        _erreur = e.erreur == ErreurCode.format
            ? Textes.codeFormat
            : Textes.codeDifferent;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _supprimer() async {
    await widget.verrou.supprimerCode();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _champ(Key cle, TextEditingController c, String libelle) => TextField(
    key: cle,
    controller: c,
    obscureText: true,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(labelText: libelle),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BoutonRetour(),
        title: const Text(Textes.codeVerrouillage),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _champ(const Key('champ-nouveau'), _nouveau, Textes.nouveauCode),
            const SizedBox(height: 12),
            _champ(
              const Key('champ-confirmation'),
              _confirmation,
              Textes.confirmerCode,
            ),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erreur!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enregistrer,
              child: const Text(Textes.enregistrer),
            ),
            if (widget.verrou.aCode) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _supprimer,
                child: const Text(Textes.supprimerCode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
