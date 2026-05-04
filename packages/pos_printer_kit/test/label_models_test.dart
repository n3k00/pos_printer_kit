import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  test('xp326b72x50 preset exposes expected media config', () {
    const preset = LabelPresets.xp326b72x50;
    expect(preset.widthMm, 72);
    expect(preset.heightMm, 50);
    expect(preset.gapMm, 2);
    expect(preset.paperType, LabelPaperType.gap);
    expect(preset.sensorMode, LabelSensorMode.gap);
  });

  test('label print job stores media and layout config', () {
    final job = LabelPrintJob(
      media: LabelPresets.xp326b72x50,
      layout: const LabelContentLayout(
        contentWidthPx: 320,
        contentHeightPx: 320,
        alignment: LabelContentAlignment.center,
      ),
      imageBytes: Uint8List(0),
    );

    expect(job.layout.contentWidthPx, 320);
    expect(job.media.widthPx, 576);
  });
}
