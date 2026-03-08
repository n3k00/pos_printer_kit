# Failure Matrix and Recovery Behavior

This document defines expected failure handling for common Bluetooth printer issues.

## Scope

- Platform: Android Bluetooth printers
- Package: `pos_printer_kit`
- Core actor: `PrinterCore`

## Failure Matrix

| Failure case | Typical signal | Package behavior | Recommended app recovery UX |
|---|---|---|---|
| Bluetooth is off | platform reports Bluetooth disabled | Emits `BluetoothOffException`; `status` updated; `onError` stream emits | Show "Turn on Bluetooth" CTA, keep retry button visible |
| Permission denied / missing Bluetooth permission | scan/connect fails with permission/unauthorized platform error | Emits `scan_failed` or `connect_failed`, `onError` emits | Prompt permission flow, then re-trigger scan |
| Connect failure | printer offline/out of range/wrong pairing | Emits `connect_failed`; state transitions to `error` | Show "Retry connect" + "Check pairing" hint |
| Not connected at print time | user prints before connecting | Emits `NoWritableCharacteristicException` for backward compatibility | Show "Connect printer first" message |
| Saved printer not available | auto reconnect timeout / not found | Falls back to manual connect state, status set to manual connect hint | Show device list + "Connect manually" |
| Print image conversion failure | invalid bytes, decode failure | Emits `print_failed`, `onError` emits, progress emits `failed` | Show "Invalid print image" and allow retry |
| Disconnect during operation | connection drops while printing | Emits disconnected state on `onStateChanged`; status updated | Show reconnect button and preserve pending print context if needed |

## Recovery Design Rules

1. Never hard crash on recoverable printer failure.
2. Emit observable signals (`onError`, `onStateChanged`, `onPrintProgress`) for every failure path.
3. Prefer user-actionable messaging over raw platform error text.
4. Keep manual recovery actions visible: `Start Searching`, `Retry`, `Disconnect`.
5. Avoid infinite retries. Respect `PrinterRetryPolicy` bounds.

## Operational Recommendations

- For unstable environments:
  - increase `maxRetries`
  - increase `baseDelayMs`
  - keep `maxDelayMs` bounded
- Log and monitor:
  - error code frequency
  - reconnect success rate
  - print failure rate

## Compliance Notes

- Failure handling must not bypass dependency license requirements.
- See `THIRD_PARTY_NOTICES.md` for dependency licensing obligations.
