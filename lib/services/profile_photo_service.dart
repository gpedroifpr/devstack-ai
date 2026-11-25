import 'dart:typed_data';
import 'dart:ui' as ui;

class ProfilePhotoService {
  static Future<Uint8List> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Escolha uma imagem de até 20 MB.');
    }
    ui.Codec? codec;
    ui.Image? image;
    ui.Image? resized;
    ui.Picture? picture;
    try {
      // Encoded ImageDescriptor dimensions throw UnsupportedError on Flutter Web.
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 256,
        allowUpscaling: false,
      );
      image = (await codec.getNextFrame()).image;
      final longest = image.width > image.height ? image.width : image.height;
      final scale = longest > 256 ? 256 / longest : 1.0;
      final width = (image.width * scale).round().clamp(1, 256);
      final height = (image.height * scale).round().clamp(1, 256);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      picture = recorder.endRecording();
      resized = await picture.toImage(width, height);
      final data = await resized.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 600 * 1024) {
        throw const FormatException('Não foi possível preparar essa imagem.');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      resized?.dispose();
      picture?.dispose();
      codec?.dispose();
    }
  }
}
