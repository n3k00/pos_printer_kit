import 'dart:typed_data';

class ImagePrintJob {
  const ImagePrintJob({
    required this.imageBytes,
    this.copies = 1,
  });

  final Uint8List imageBytes;
  final int copies;
}
