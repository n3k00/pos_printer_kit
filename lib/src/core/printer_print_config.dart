import 'printer_capability_profile.dart';
import 'printer_print_enums.dart';

export 'printer_print_enums.dart';

class PrinterPrintConfig {
  const PrinterPrintConfig({
    this.width = 384,
    this.threshold = 160,
    this.copies = 1,
    this.ditherMode = PrinterDitherMode.threshold,
    this.feedLinesAfterPrint = 2,
    this.cutMode = PrinterCutMode.none,
    this.allowCutCommands = true,
  });

  factory PrinterPrintConfig.fromProfile(
    PrinterCapabilityProfile profile, {
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode? ditherMode,
    PrinterCutMode? cutMode,
    int? feedLinesAfterPrint,
  }) {
    return PrinterPrintConfig(
      width: profile.paperWidthPx,
      threshold: threshold,
      copies: copies,
      ditherMode: ditherMode ?? profile.defaultDitherMode,
      feedLinesAfterPrint:
          feedLinesAfterPrint ?? profile.defaultFeedLinesAfterPrint,
      cutMode: cutMode ?? (profile.supportsCut ? PrinterCutMode.partial : PrinterCutMode.none),
      allowCutCommands: profile.supportsCut,
    );
  }

  factory PrinterPrintConfig.label({
    int width = 384,
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode ditherMode = PrinterDitherMode.threshold,
  }) {
    return PrinterPrintConfig(
      width: width,
      threshold: threshold,
      copies: copies,
      ditherMode: ditherMode,
      feedLinesAfterPrint: 0,
      cutMode: PrinterCutMode.none,
      allowCutCommands: false,
    );
  }

  factory PrinterPrintConfig.labelFromProfile(
    PrinterCapabilityProfile profile, {
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode? ditherMode,
  }) {
    return PrinterPrintConfig(
      width: profile.paperWidthPx,
      threshold: threshold,
      copies: copies,
      ditherMode: ditherMode ?? profile.defaultDitherMode,
      feedLinesAfterPrint: 0,
      cutMode: PrinterCutMode.none,
      allowCutCommands: false,
    );
  }

  final int width;
  final int threshold;
  final int copies;
  final PrinterDitherMode ditherMode;
  final int feedLinesAfterPrint;
  final PrinterCutMode cutMode;
  final bool allowCutCommands;
}
