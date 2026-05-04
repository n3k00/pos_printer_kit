import 'dart:convert';

import 'package:image/image.dart' as img;

import '../core/printer_errors.dart';
import 'label_models.dart';
import 'label_printer_driver.dart';

class RawTsplLabelPrinterDriver extends LabelPrinterDriver {
  const RawTsplLabelPrinterDriver();

  @override
  Future<List<int>> buildPrintJobBytes(LabelPrintJob job) async {
    final decoded = img.decodeImage(job.imageBytes);
    if (decoded == null) {
      throw PrinterOperationException(
        code: 'invalid_image',
        message: 'Could not decode image bytes.',
      );
    }

    final targetWidth = job.layout.contentWidthPx > 0
        ? job.layout.contentWidthPx
        : decoded.width;
    final targetHeight = job.layout.contentHeightPx > 0
        ? job.layout.contentHeightPx
        : decoded.height;
    final prepared = img.copyResize(
      decoded,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
    final bytesPerRow = (targetWidth + 7) ~/ 8;
    final bitmap = List<int>.filled(bytesPerRow * targetHeight, 0);

    for (var y = 0; y < targetHeight; y++) {
      for (var x = 0; x < targetWidth; x++) {
        final pixel = prepared.getPixel(x, y);
        final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round();
        final shouldSetBit = job.invertBitmap
            ? luminance >= job.threshold
            : luminance < job.threshold;
        if (shouldSetBit) {
          final index = y * bytesPerRow + (x ~/ 8);
          bitmap[index] |= 0x80 >> (x % 8);
        }
      }
    }

    final safeCopies = job.copies < 1 ? 1 : job.copies;
    final xOffsetPx = _resolveXOffsetPx(
      mediaWidthPx: job.media.widthPx,
      contentWidthPx: targetWidth,
      layout: job.layout,
    );
    final yOffsetPx = job.layout.offsetYPx;
    final bytes = <int>[];

    void addCommand(String command) {
      bytes.addAll(ascii.encode(command));
      bytes.add(10);
    }

    addCommand(
      'SIZE ${job.media.widthMm.toStringAsFixed(0)} mm,'
      '${job.media.heightMm.toStringAsFixed(0)} mm',
    );
    addCommand('GAP ${job.media.gapMm.toStringAsFixed(0)} mm,0 mm');
    if (job.limitFeedMm != null && job.limitFeedMm! > 0) {
      addCommand('LIMITFEED ${job.limitFeedMm!.toStringAsFixed(0)} mm');
    }
    if (job.calibrateBeforePrint) {
      addCommand('GAPDETECT');
    }
    if (job.homeBeforePrint) {
      addCommand('HOME');
    }
    addCommand(
      'DIRECTION '
      '${job.media.direction == LabelPrintDirection.rotated180 ? 1 : 0}',
    );
    addCommand('MIRROR 0');
    if (job.media.tearMode == LabelTearMode.on) {
      addCommand('SET TEAR ON');
    }
    addCommand('REFERENCE 0,0');
    addCommand('CLS');
    bytes.addAll(
      ascii.encode(
        'BITMAP $xOffsetPx,$yOffsetPx,$bytesPerRow,$targetHeight,0,',
      ),
    );
    bytes.addAll(bitmap);
    bytes.add(10);
    addCommand('PRINT $safeCopies,1');
    if (job.advanceToNextGapAfterPrint) {
      addCommand('FORMFEED');
    }
    return bytes;
  }

  int _resolveXOffsetPx({
    required int mediaWidthPx,
    required int contentWidthPx,
    required LabelContentLayout layout,
  }) {
    final base = switch (layout.alignment) {
      LabelContentAlignment.start => 0,
      LabelContentAlignment.center => (mediaWidthPx - contentWidthPx) ~/ 2,
      LabelContentAlignment.end => mediaWidthPx - contentWidthPx,
    };
    final resolved = base + layout.offsetXPx;
    return resolved < 0 ? 0 : resolved;
  }
}
