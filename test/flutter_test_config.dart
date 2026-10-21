import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// Limites : 10 s par test() (dart_test.yaml), 60 s par testWidgets (ici) ; boucle de pump sans fin : `timeout -k` des commandes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(seconds: 60));
  }
  await testMain();
}
