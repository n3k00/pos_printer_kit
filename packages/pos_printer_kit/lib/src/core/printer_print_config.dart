enum PrinterDitherMode {
  threshold,
  floydSteinberg,
}

enum PrinterCutMode {
  none,
  full,
  partial,
}

class PrinterPrintConfig {
  const PrinterPrintConfig({
    this.width = 384,
    this.threshold = 160,
    this.copies = 1,
    this.ditherMode = PrinterDitherMode.threshold,
    this.feedLinesAfterPrint = 2,
    this.cutMode = PrinterCutMode.none,
  });

  final int width;
  final int threshold;
  final int copies;
  final PrinterDitherMode ditherMode;
  final int feedLinesAfterPrint;
  final PrinterCutMode cutMode;
}
