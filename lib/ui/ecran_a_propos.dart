import 'package:flutter/material.dart';

import '../version.dart';
import 'textes.dart';

/// Écran « À propos » en lecture seule : attribution ARASAAC, gratuité,
/// version (REQ-027).
class EcranAPropos extends StatelessWidget {
  const EcranAPropos({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Scaffold(
      appBar: AppBar(title: const Text(Textes.aPropos)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              Textes.titreAppli,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(Textes.gratuitNonCommercial, style: style),
            const SizedBox(height: 12),
            Text('${Textes.versionLabel} $versionAppli', style: style),
            const SizedBox(height: 12),
            Text(Textes.attributionArasaac, style: style),
          ],
        ),
      ),
    );
  }
}
