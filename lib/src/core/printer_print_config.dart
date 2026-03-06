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
    this.chunkDelayMs = 12,
    this.maxChunkSize = 180,
    this.preferWriteWithoutResponse = false,
  });

  factory PrinterPrintConfig.fromProfile(
    PrinterCapabilityProfile profile, {
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode? ditherMode,
    PrinterCutMode? cutMode,
    int? feedLinesAfterPrint,
    int chunkDelayMs = 12,
    int maxChunkSize = 180,
    bool preferWriteWithoutResponse = false,
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
      chunkDelayMs: chunkDelayMs,
      maxChunkSize: maxChunkSize,
      preferWriteWithoutResponse: preferWriteWithoutResponse,
    );
  }

  factory PrinterPrintConfig.label({
    int width = 384,
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode ditherMode = PrinterDitherMode.threshold,
    int chunkDelayMs = 12,
    int maxChunkSize = 180,
    bool preferWriteWithoutResponse = false,
  }) {
    return PrinterPrintConfig(
      width: width,
      threshold: threshold,
      copies: copies,
      ditherMode: ditherMode,
      feedLinesAfterPrint: 0,
      cutMode: PrinterCutMode.none,
      allowCutCommands: false,
      chunkDelayMs: chunkDelayMs,
      maxChunkSize: maxChunkSize,
      preferWriteWithoutResponse: preferWriteWithoutResponse,
    );
  }

  factory PrinterPrintConfig.labelFromProfile(
    PrinterCapabilityProfile profile, {
    int threshold = 160,
    int copies = 1,
    PrinterDitherMode? ditherMode,
    int chunkDelayMs = 12,
    int maxChunkSize = 180,
    bool preferWriteWithoutResponse = false,
  }) {
    return PrinterPrintConfig(
      width: profile.paperWidthPx,
      threshold: threshold,
      copies: copies,
      ditherMode: ditherMode ?? profile.defaultDitherMode,
      feedLinesAfterPrint: 0,
      cutMode: PrinterCutMode.none,
      allowCutCommands: false,
      chunkDelayMs: chunkDelayMs,
      maxChunkSize: maxChunkSize,
      preferWriteWithoutResponse: preferWriteWithoutResponse,
    );
  }

  final int width;
  final int threshold;
  final int copies;
  final PrinterDitherMode ditherMode;
  final int feedLinesAfterPrint;
  final PrinterCutMode cutMode;
  final bool allowCutCommands;
  final int chunkDelayMs;
  final int maxChunkSize;
  final bool preferWriteWithoutResponse;
}
