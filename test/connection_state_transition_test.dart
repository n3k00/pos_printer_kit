import 'package:flutter_test/flutter_test.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  group('PrinterConnectionMachine', () {
    test('moves through searching -> connecting -> connected -> disconnected', () {
      var state = const PrinterConnectionState(
        stage: PrinterConnectionStage.idle,
      );

      state = PrinterConnectionMachine.transition(
        state,
        PrinterConnectionEvent.startSearching,
      );
      expect(state.stage, PrinterConnectionStage.searching);

      state = PrinterConnectionMachine.transition(
        state,
        PrinterConnectionEvent.startConnecting,
        deviceId: 'AA:BB:CC',
        deviceName: 'XP-P323B',
      );
      expect(state.stage, PrinterConnectionStage.connecting);
      expect(state.deviceId, 'AA:BB:CC');
      expect(state.deviceName, 'XP-P323B');

      state = PrinterConnectionMachine.transition(
        state,
        PrinterConnectionEvent.connected,
      );
      expect(state.stage, PrinterConnectionStage.connected);
      expect(state.deviceId, 'AA:BB:CC');

      state = PrinterConnectionMachine.transition(
        state,
        PrinterConnectionEvent.disconnected,
        message: 'Disconnected',
      );
      expect(state.stage, PrinterConnectionStage.disconnected);
      expect(state.message, 'Disconnected');
    });

    test('moves to error state on failed event and preserves context', () {
      var state = const PrinterConnectionState(
        stage: PrinterConnectionStage.connecting,
        deviceId: '11:22:33',
        deviceName: 'Printer A',
      );

      state = PrinterConnectionMachine.transition(
        state,
        PrinterConnectionEvent.failed,
        message: 'Connection timeout',
      );

      expect(state.stage, PrinterConnectionStage.error);
      expect(state.deviceId, '11:22:33');
      expect(state.deviceName, 'Printer A');
      expect(state.message, 'Connection timeout');
    });
  });
}
