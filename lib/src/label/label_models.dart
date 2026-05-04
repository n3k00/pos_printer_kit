import 'dart:typed_data';

enum LabelPaperType { continuous, gap, blackMark }

enum LabelPrintDirection { normal, rotated180 }

enum LabelTearMode { off, on }

enum LabelSensorMode { gap, blackMark, continuous }

enum LabelBackground { white, transparent }

enum LabelContentAlignment { start, center, end }

class LabelMediaConfig {
  const LabelMediaConfig({
    required this.widthMm,
    required this.heightMm,
    this.gapMm = 0,
    this.paperType = LabelPaperType.gap,
    this.direction = LabelPrintDirection.normal,
    this.tearMode = LabelTearMode.off,
    this.density = 8,
    this.sensorMode = LabelSensorMode.gap,
  });

  final double widthMm;
  final double heightMm;
  final double gapMm;
  final LabelPaperType paperType;
  final LabelPrintDirection direction;
  final LabelTearMode tearMode;
  final int density;
  final LabelSensorMode sensorMode;

  int get widthPx => (widthMm * 8).round();
  int get heightPx => (heightMm * 8).round();
}

class LabelContentLayout {
  const LabelContentLayout({
    this.contentWidthPx = 0,
    this.contentHeightPx = 0,
    this.offsetXPx = 0,
    this.offsetYPx = 0,
    this.alignment = LabelContentAlignment.center,
    this.background = LabelBackground.white,
  });

  final int contentWidthPx;
  final int contentHeightPx;
  final int offsetXPx;
  final int offsetYPx;
  final LabelContentAlignment alignment;
  final LabelBackground background;
}

class LabelPrintJob {
  const LabelPrintJob({
    required this.media,
    required this.layout,
    required this.imageBytes,
    this.copies = 1,
    this.threshold = 160,
    this.invertBitmap = true,
    this.calibrateBeforePrint = false,
    this.advanceToNextGapAfterPrint = false,
    this.homeBeforePrint = false,
    this.limitFeedMm,
  });

  final LabelMediaConfig media;
  final LabelContentLayout layout;
  final Uint8List imageBytes;
  final int copies;
  final int threshold;
  final bool invertBitmap;
  final bool calibrateBeforePrint;
  final bool advanceToNextGapAfterPrint;
  final bool homeBeforePrint;
  final double? limitFeedMm;
}
