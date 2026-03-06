import 'printer_connection_state.dart';
import 'printer_errors.dart';

typedef PrinterLogCallback = void Function(String message);

enum PrinterPrintProgressStage {
  started,
  copySent,
  completed,
  failed,
}

class PrinterPrintProgress {
  const PrinterPrintProgress({
    required this.stage,
    this.currentCopy,
    this.totalCopies,
    this.message,
  });

  final PrinterPrintProgressStage stage;
  final int? currentCopy;
  final int? totalCopies;
  final String? message;
}

class PrinterObservabilitySnapshot {
  const PrinterObservabilitySnapshot({
    required this.state,
    required this.lastError,
  });

  final PrinterConnectionState state;
  final PrinterOperationException? lastError;
}
