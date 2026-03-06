import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  group('EscPosRasterEncoder', () {
    test('encodes GS v 0 header and dimensions for 8x1 image', () {
      final image = img.Image(width: 8, height: 1);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      image.setPixel(0, 0, img.ColorRgb8(0, 0, 0));

      final bytes = Uint8List.fromList(img.encodePng(image));
      final encoder = const EscPosRasterEncoder();
      final raster = encoder.encode(
        bytes,
        config: const PrinterPrintConfig(
          width: 8,
          threshold: 128,
          ditherMode: PrinterDitherMode.threshold,
        ),
      );

      expect(raster.length, 9);
      expect(raster.sublist(0, 4), equals([0x1D, 0x76, 0x30, 0x00]));
      expect(raster[4], 0x01); // width bytes low
      expect(raster[5], 0x00); // width bytes high
      expect(raster[6], 0x01); // height low
      expect(raster[7], 0x00); // height high
      expect(raster[8], 0x80); // first pixel is black
    });

    test('supports floyd-steinberg mode and returns valid raster payload', () {
      final image = img.Image(width: 16, height: 16);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final v = ((x / (image.width - 1)) * 255).round();
          image.setPixel(x, y, img.ColorRgb8(v, v, v));
        }
      }

      final bytes = Uint8List.fromList(img.encodePng(image));
      final encoder = const EscPosRasterEncoder();
      final raster = encoder.encode(
        bytes,
        config: const PrinterPrintConfig(
          width: 16,
          threshold: 128,
          ditherMode: PrinterDitherMode.floydSteinberg,
        ),
      );

      // 8-byte header + widthBytes(2) * height(16) = 40 bytes total
      expect(raster.length, 40);
      expect(raster.sublist(0, 4), equals([0x1D, 0x76, 0x30, 0x00]));
      expect(raster[4], 0x02);
      expect(raster[5], 0x00);
      expect(raster[6], 0x10);
      expect(raster[7], 0x00);
      expect(raster.skip(8).any((b) => b != 0), isTrue);
    });
  });
}
