import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/plateforme/orientation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'REQ038_AC1 fixerOrientation demande les deux paysages, une fois',
    () async {
      final appels = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
            appels.add(c);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await fixerOrientation();
      final o = appels.where(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );
      expect(o, hasLength(1));
      expect(o.single.arguments, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    },
  );
}
