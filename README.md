# test_codex

Flutter host app for `pos_printer_kit`, focused on BLE thermal printing with image-based pipeline.

This app currently targets:
- portable thermal printer workflows
- 80mm sample receipt printing (app-level tuned)
- Myanmar-safe output via raster image printing

## Project Structure

- `lib/main.dart`
  - app UI
  - connect page entry
  - app-level print sample generation and calibration
- `packages/pos_printer_kit/`
  - reusable package for BLE connect + print core + UI + l10n

## Run

```bash
flutter pub get
flutter run -d <device-id>
```

Example:

```bash
flutter run -d b42fa72
```

## App-Level 80mm Calibration Guide

If output is not centered, too small, or has too much blank space, tune app-level variables in `lib/main.dart`.

### 1) Width and print behavior

Function: `_print80mmSample(...)`

Key config:

```dart
const config = PrinterPrintConfig(
  width: 576,                 // 80mm typical printable width
  threshold: 165,
  ditherMode: PrinterDitherMode.floydSteinberg,
  feedLinesAfterPrint: 0,     // reduce tail blank
  cutMode: PrinterCutMode.none,
  allowCutCommands: false,
);
```

How to tune:
- if content looks narrow: try `width: 640` (only if your printer truly supports it)
- if print is too dark/light: tune `threshold` (150~190)
- if paper feeds too much at end: keep `feedLinesAfterPrint: 0`

### 2) Horizontal alignment (left/right shift)

Function: `_buildSampleReceiptImage(...)`

Key variable:

```dart
const horizontalOffset = 22; // positive => shift right, negative => shift left
```

How to tune:
- left side too tight / right too wide: increase value (`22 -> 26`)
- right side too tight / left too wide: decrease value (`22 -> 16`)

### 3) Reduce extra blank area

Same function uses auto-crop:

```dart
final usedHeight = (y + 56).clamp(260, height);
final cropped = img.copyCrop(image, x: 0, y: 0, width: width, height: usedHeight);
```

How to tune:
- still too much blank at bottom: lower `y + 56` to `y + 40`
- content gets cut: increase `y + 56` to `y + 72`

## Quick Troubleshooting

### Log shows many `GATT_SUCCESS (0)` lines

This is normal. Image data is sent in many BLE chunks and each chunk logs success.

### 80mm print still looks like 58mm

Possible causes:
- printer hardware is actually 58mm-class
- firmware printable width is limited even with 80mm paper

Action:
- print a width ruler test at `576` and `640`
- keep the width that gives the best real output

## Important Notes

- Unicode text-mode ESC/POS is not reliable for Myanmar on many printers.
- Preferred approach: render receipt/label as image and print via `printImage(...)`.
- Package docs are in:
  - `packages/pos_printer_kit/README.md`
