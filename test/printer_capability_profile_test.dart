import 'package:flutter_test/flutter_test.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  group('PrinterCapabilityProfile', () {
    test('receipt58 preset has expected defaults', () {
      final p = PrinterCapabilityProfile.receipt58;
      expect(p.paperWidthPx, 384);
      expect(p.supportsCut, isFalse);
    });

    test('findByModelName resolves xp-p323b', () {
      final p = PrinterCapabilityProfile.findByModelName('XP-P323B');
      expect(p, isNotNull);
      expect(p!.id, 'xp_p323b');
    });
  });

  group('PrinterPrintConfig presets', () {
    test('fromProfile applies cutter support', () {
      final cfg = PrinterPrintConfig.fromProfile(
        PrinterCapabilityProfile.receipt80,
      );
      expect(cfg.width, 576);
      expect(cfg.allowCutCommands, isTrue);
    });

    test('label preset disables feed and cut', () {
      final cfg = PrinterPrintConfig.label();
      expect(cfg.feedLinesAfterPrint, 0);
      expect(cfg.cutMode, PrinterCutMode.none);
      expect(cfg.allowCutCommands, isFalse);
    });
  });
}
