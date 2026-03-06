import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/printer_print_config.dart';

class EscPosRasterEncoder {
  const EscPosRasterEncoder();

  List<int> encode(
    Uint8List imageBytes, {
    required PrinterPrintConfig config,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Invalid image bytes');
    }

    final safeTarget = config.width <= 0 ? 384 : config.width;
    img.Image converted = decoded;
    if (decoded.width != safeTarget) {
      converted = img.copyResize(decoded, width: safeTarget);
    }
    converted = img.grayscale(converted);

    final width = converted.width;
    final height = converted.height;
    final widthBytes = (width + 7) ~/ 8;
    final data = Uint8List(widthBytes * height);
    final mono = _toMonochrome(
      converted,
      threshold: config.threshold,
      mode: config.ditherMode,
    );
    _packBits(mono, width: width, height: height, out: data);

    return <int>[
      0x1D,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
      ...data,
    ];
  }

  Uint8List _toMonochrome(
    img.Image source, {
    required int threshold,
    required PrinterDitherMode mode,
  }) {
    final width = source.width;
    final height = source.height;
    final total = width * height;
    final thresholdSafe = threshold.clamp(0, 255).toInt();

    final luminance = Float64List(total);
    var i = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        luminance[i++] = source.getPixel(x, y).r.toDouble();
      }
    }

    if (mode == PrinterDitherMode.floydSteinberg) {
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final idx = y * width + x;
          final old = luminance[idx];
          final next = old < thresholdSafe ? 0.0 : 255.0;
          final err = old - next;
          luminance[idx] = next;

          if (x + 1 < width) {
            luminance[idx + 1] += err * (7 / 16);
          }
          if (y + 1 < height) {
            if (x > 0) {
              luminance[idx + width - 1] += err * (3 / 16);
            }
            luminance[idx + width] += err * (5 / 16);
            if (x + 1 < width) {
              luminance[idx + width + 1] += err * (1 / 16);
            }
          }
        }
      }
    }

    final mono = Uint8List(total);
    for (var idx = 0; idx < total; idx++) {
      mono[idx] = luminance[idx] < thresholdSafe ? 1 : 0;
    }
    return mono;
  }

  void _packBits(
    Uint8List mono, {
    required int width,
    required int height,
    required Uint8List out,
  }) {
    final widthBytes = (width + 7) ~/ 8;
    var offset = 0;
    for (var y = 0; y < height; y++) {
      final rowStart = y * width;
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = (xByte * 8) + bit;
          if (x >= width) continue;
          final isBlack = mono[rowStart + x] == 1;
          if (isBlack) {
            byte |= (0x80 >> bit);
          }
        }
        out[offset++] = byte;
      }
    }
  }
}
