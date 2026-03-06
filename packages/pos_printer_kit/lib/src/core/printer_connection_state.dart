enum PrinterConnectionStage {
  idle,
  searching,
  connecting,
  connected,
  disconnected,
  error,
}

class PrinterConnectionState {
  const PrinterConnectionState({
    required this.stage,
    this.deviceId,
    this.deviceName,
    this.message,
  });

  final PrinterConnectionStage stage;
  final String? deviceId;
  final String? deviceName;
  final String? message;
}
