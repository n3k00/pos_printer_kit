import 'dart:math';

class PrinterRetryPolicy {
  const PrinterRetryPolicy({
    this.maxRetries = 2,
    this.baseDelayMs = 600,
    this.backoffMultiplier = 1.0,
    this.maxDelayMs = 3000,
    this.retryGatt133Only = true,
  });

  final int maxRetries;
  final int baseDelayMs;
  final double backoffMultiplier;
  final int maxDelayMs;
  final bool retryGatt133Only;

  Duration delayForAttempt(int attempt) {
    final safeAttempt = max(1, attempt);
    final factor = pow(backoffMultiplier <= 0 ? 1.0 : backoffMultiplier, safeAttempt - 1);
    final raw = (baseDelayMs * factor).round();
    final ms = raw.clamp(0, maxDelayMs);
    return Duration(milliseconds: ms);
  }
}
