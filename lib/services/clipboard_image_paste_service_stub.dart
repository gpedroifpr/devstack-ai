import 'dart:typed_data';

class PastedImageData {
  final String name;
  final String mimeType;
  final Uint8List bytes;

  PastedImageData({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

typedef PastedImageHandler = void Function(PastedImageData image);

class ClipboardImagePasteService {
  static Object? listen(PastedImageHandler onImage) {
    return null;
  }

  static void cancel(Object? subscription) {}
}
