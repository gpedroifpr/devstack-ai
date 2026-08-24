import 'dart:async';
import 'dart:html' as html;
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
    return html.document.onPaste.listen((event) {
      final files = event.clipboardData?.files;
      if (files == null || files.length == 0) return;

      final file = files[0];
      if (!file.type.startsWith('image/')) return;

      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        Uint8List? bytes;

        if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is Uint8List) {
          bytes = result;
        }

        if (bytes == null) return;

        onImage(
          PastedImageData(
            name: file.name.isEmpty
                ? 'imagem-colada-${DateTime.now().millisecondsSinceEpoch}.png'
                : file.name,
            mimeType: file.type.isEmpty ? 'image/png' : file.type,
            bytes: bytes,
          ),
        );
      });

      reader.readAsArrayBuffer(file);
      event.preventDefault();
    });
  }

  static void cancel(Object? subscription) {
    if (subscription is StreamSubscription) {
      subscription.cancel();
    }
  }
}
