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

enum PrinterConnectionEvent {
  ready,
  startSearching,
  stopSearching,
  startConnecting,
  connected,
  disconnected,
  failed,
}

class PrinterConnectionMachine {
  const PrinterConnectionMachine._();

  static PrinterConnectionState transition(
    PrinterConnectionState current,
    PrinterConnectionEvent event, {
    String? deviceId,
    String? deviceName,
    String? message,
  }) {
    switch (event) {
      case PrinterConnectionEvent.ready:
        return PrinterConnectionState(
          stage: PrinterConnectionStage.idle,
          message: message ?? current.message,
          deviceId: current.deviceId,
          deviceName: current.deviceName,
        );
      case PrinterConnectionEvent.startSearching:
        return const PrinterConnectionState(
          stage: PrinterConnectionStage.searching,
        );
      case PrinterConnectionEvent.stopSearching:
        return const PrinterConnectionState(
          stage: PrinterConnectionStage.idle,
        );
      case PrinterConnectionEvent.startConnecting:
        return PrinterConnectionState(
          stage: PrinterConnectionStage.connecting,
          deviceId: deviceId ?? current.deviceId,
          deviceName: deviceName ?? current.deviceName,
          message: message,
        );
      case PrinterConnectionEvent.connected:
        return PrinterConnectionState(
          stage: PrinterConnectionStage.connected,
          deviceId: deviceId ?? current.deviceId,
          deviceName: deviceName ?? current.deviceName,
          message: message,
        );
      case PrinterConnectionEvent.disconnected:
        return PrinterConnectionState(
          stage: PrinterConnectionStage.disconnected,
          message: message,
        );
      case PrinterConnectionEvent.failed:
        return PrinterConnectionState(
          stage: PrinterConnectionStage.error,
          deviceId: deviceId ?? current.deviceId,
          deviceName: deviceName ?? current.deviceName,
          message: message,
        );
    }
  }
}
