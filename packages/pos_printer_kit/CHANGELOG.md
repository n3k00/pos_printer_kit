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
