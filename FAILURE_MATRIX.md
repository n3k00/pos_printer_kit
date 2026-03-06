# Failure Matrix and Recovery Behavior

This document defines expected failure handling for common BLE printer issues.

## Scope

- Platform: Android BLE printers
- Package: `pos_printer_kit`
- Core actor: `PrinterCore`

## Failure Matrix

| Failure case | Typical signal | Package behavior | Recommended app recovery UX |
|---|---|---|---|
| Bluetooth is off | `BluetoothAdapterState != on`, scan/connect fail | Emits `BluetoothOffException`; `status` updated; `onError` stream emits | Show "Turn on Bluetooth" CTA, keep retry button visible |
| Permission denied / missing BLE permission | Scan/connect fails with platform error mentioning permission/unauthorized | Emits `scan_failed` or `connect_failed` (typed mapping can be extended), `onError` emits | Prompt permission flow, then re-trigger scan |
| Android GATT 133 | connect failure with `gatt_error` / `133` | Retries based on `PrinterRetryPolicy` (`retryGatt133Only`), then fails with mapped connect error | Show "Retry connect" + "Move closer to printer" hint |
| No writable characteristic | Services discovered but write characteristic absent | Emits `NoWritableCharacteristicException` | Show "Unsupported printer profile" message |
| Saved printer not available | auto reconnect timeout / not found | Falls back to manual connect state, status set to manual connect hint | Show device list + "Connect manually" |
| Print image conversion failure | invalid bytes, decode failure | Emits `print_failed`, `onError` emits, progress emits `failed` | Show "Invalid print image" and allow retry |
| Disconnect during operation | connection state becomes disconnected | Emits disconnected state on `onStateChanged`; status updated | Show reconnect button and preserve pending print context if needed |

## Recovery Design Rules

1. Never hard crash on recoverable printer failure.
2. Emit observable signals (`onError`, `onStateChanged`, `onPrintProgress`) for every failure path.
3. Prefer user-actionable messaging over raw platform error text.
4. Keep manual recovery actions visible: `Start Searching`, `Retry`, `Disconnect`.
5. Avoid infinite retries. Respect `PrinterRetryPolicy` bounds.

## Operational Recommendations

- Keep `retryGatt133Only = true` in production unless vendor-specific testing suggests otherwise.
- For unstable radio environments:
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
