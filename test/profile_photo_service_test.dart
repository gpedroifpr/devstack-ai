import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/profile_photo_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects empty and oversized files', () async {
    await expectLater(
      ProfilePhotoService.prepare(Uint8List(0)),
      throwsFormatException,
    );
    await expectLater(
      ProfilePhotoService.prepare(Uint8List(21 * 1024 * 1024)),
      throwsFormatException,
    );
  });

  test('rejects invalid image data', () async {
    await expectLater(
      ProfilePhotoService.prepare(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });

  test('resizes to safe PNG and preserves aspect ratio', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF00FFFF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final original = await picture.toImage(1200, 600);
    final input = await original.toByteData(format: ui.ImageByteFormat.png);
    final output = await ProfilePhotoService.prepare(
      input!.buffer.asUint8List(),
    );
    final codec = await ui.instantiateImageCodec(output);
    final image = (await codec.getNextFrame()).image;
    expect(image.width, 256);
    expect(image.height, 128);
    expect(output.length, lessThan(600 * 1024));
    image.dispose();
    codec.dispose();
    original.dispose();
    picture.dispose();
  });
}
