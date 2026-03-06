import 'package:flutter_test/flutter_test.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  group('PrinterRetryPolicy', () {
    test('returns base delay for first attempt by default', () {
      const policy = PrinterRetryPolicy();
      expect(policy.delayForAttempt(1).inMilliseconds, 600);
    });

    test('supports exponential backoff with max cap', () {
      const policy = PrinterRetryPolicy(
        baseDelayMs: 500,
        backoffMultiplier: 2,
        maxDelayMs: 1200,
      );

      expect(policy.delayForAttempt(1).inMilliseconds, 500);
      expect(policy.delayForAttempt(2).inMilliseconds, 1000);
      expect(policy.delayForAttempt(3).inMilliseconds, 1200); // capped
    });
  });
}
