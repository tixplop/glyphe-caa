import 'package:flutter/material.dart';

import '../../domaine/session.dart';
import '../textes.dart';
import 'image_case.dart';

/// Barre de phrase : éléments ajoutés, défilement horizontal, appui = lire.
class BarrePhrase extends StatefulWidget {
  const BarrePhrase({super.key, required this.elements, required this.onLire});

  final List<ElementBarre> elements;
  final VoidCallback onLire;

  @override
  State<BarrePhrase> createState() => _BarrePhraseState();
}

class _BarrePhraseState extends State<BarrePhrase> {
  final ScrollController _controleur = ScrollController();

  @override
  void didUpdateWidget(BarrePhrase ancien) {
    super.didUpdateWidget(ancien);
    if (widget.elements.length > ancien.elements.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controleur.hasClients) {
          _controleur.jumpTo(_controleur.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: Textes.phrase,
      excludeSemantics: true,
      onTap: widget.onLire,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black54),
        ),
        child: InkWell(
          key: const Key('zone-barre'),
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onLire,
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: SingleChildScrollView(
              controller: _controleur,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.elements.length; i++)
                    SizedBox(
                      key: Key('element-barre-$i'),
                      width: 72,
                      height: 80,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          children: [
                            Expanded(
                              child: ImageCaseWidget(widget.elements[i].image),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.elements[i].libelle,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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
