import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/ui/app.dart';

void main() {
  testWidgets('REQ029_AC1 l\'appli se construit et affiche Glyphe', (
    tester,
  ) async {
    await tester.pumpWidget(const GlypheApp());
    expect(find.text('Glyphe'), findsOneWidget);
  });
}
