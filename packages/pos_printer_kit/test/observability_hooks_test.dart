import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  test('emits onError and onStateChanged when printing without connection', () async {
    final logs = <String>[];
    final core = PrinterCore(
      autoReconnectEnabled: false,
      logCallback: logs.add,
    );

    PrinterOperationException? observedError;
    PrinterConnectionState? observedState;

    final subErr = core.onError.listen((e) => observedError = e);
    final subState = core.onStateChanged.listen((s) => observedState = s);

    final ok = await core.printImage(Uint8List.fromList([0x00]));
    expect(ok, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(observedError, isA<NoWritableCharacteristicException>());
    expect(observedState?.stage, PrinterConnectionStage.error);
    expect(logs.any((l) => l.contains('[error]')), isTrue);

    await subErr.cancel();
    await subState.cancel();
    core.dispose();
  });
}
