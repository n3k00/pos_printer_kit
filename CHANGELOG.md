## 0.1.0

- Added `PrinterCore` BLE scan/connect/disconnect flow with retry handling for common GATT failures.
- Added `PrinterConnectPage` reusable UI with localized strings (`en`/`my`) and app-side override API.
- Added image-only printing pipeline via ESC/POS raster (`GS v 0`) with `PrinterPrintConfig`.
- Added configurable print options: width, threshold, copies, dither mode, feed lines, cut mode.
- Added optional Floyd-Steinberg dithering for raster conversion.
- Added persistence for last connected printer ID with optional auto-reconnect.
- Added typed error model (`BluetoothOffException`, `NoWritableCharacteristicException`, `ConnectTimeoutException`).
- Added test coverage:
  - raster conversion unit tests
  - connection state transition tests
- Added compliance docs: proprietary `LICENSE` and `THIRD_PARTY_NOTICES.md`.

## Unreleased

- Switched discovery from bonded-only listing to nearby Bluetooth discovery with bonded printer merge on Android.
- Added Android 12+ Nearby Devices permission request flow before scan/connect.
- Added `BluetoothPermissionDeniedException` for explicit permission failure handling.
- Patched vendored `print_bluetooth_thermal` plugin to stabilize repeated discovery runs.
