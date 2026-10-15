import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyphe/domaine/source_photo.dart';
import 'package:glyphe/plateforme/source_photo_image_picker.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('REQ020_AC2 compression : 512 px max, qualité 80', () async {
    ImageSource? source;
    double? l, h;
    int? q;
    final s = SourcePhotoImagePicker(
      choisir: (src, {maxWidth, maxHeight, imageQuality}) async {
        source = src;
        l = maxWidth;
        h = maxHeight;
        q = imageQuality;
        return XFile('/tmp/x.jpg');
      },
    );
    expect(await s.prendre(), '/tmp/x.jpg');
    expect(source, ImageSource.camera);
    expect([l, h, q], [512, 512, 80]);
    await s.choisirGalerie();
    expect(source, ImageSource.gallery);
    expect([l, h, q], [512, 512, 80]);
  });

  test('annulation : null', () async {
    final s = SourcePhotoImagePicker(
      choisir: (src, {maxWidth, maxHeight, imageQuality}) async => null,
    );
    expect(await s.prendre(), isNull);
  });

  test('REQ020_AC3 permission refusée traduite', () async {
    final s = SourcePhotoImagePicker(
      choisir: (src, {maxWidth, maxHeight, imageQuality}) async =>
          throw PlatformException(
            code: src == ImageSource.camera
                ? 'camera_access_denied'
                : 'photo_access_denied',
          ),
    );
    await expectLater(
      s.prendre(),
      throwsA(
        isA<PermissionRefusee>().having(
          (e) => e.origine,
          'origine',
          OrigineAcces.camera,
        ),
      ),
    );
    await expectLater(
      s.choisirGalerie(),
      throwsA(
        isA<PermissionRefusee>().having(
          (e) => e.origine,
          'origine',
          OrigineAcces.galerie,
        ),
      ),
    );
  });

  test('autre erreur plateforme : propagée', () async {
    final s = SourcePhotoImagePicker(
      choisir: (src, {maxWidth, maxHeight, imageQuality}) async =>
          throw PlatformException(code: 'autre'),
    );
    await expectLater(s.prendre(), throwsA(isA<PlatformException>()));
  });
}
