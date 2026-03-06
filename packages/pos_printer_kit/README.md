# pos_printer_kit

Private Flutter package for POS thermal printing with:
- BLE printer connection flow UI
- BLE scan/connect/disconnect core logic
- Image-only ESC/POS raster printing (Myanmar-safe output path)

## Current capabilities

- `PrinterCore`
  - scan BLE devices
  - connect/disconnect printer
  - expose status fields (`isScanning`, `busy`, `status`, `connectedDevice`)
  - print image bytes via ESC/POS raster command (`GS v 0`) with `PrinterPrintConfig`
- `PrinterConnectPage`
  - ready-to-search / searching / results / connected states
  - list nearby BLE devices and connect from UI
- `testPrint()` (deprecated helper)
  - sends a generated demo image to verify printer output quickly

## Requirements

- Flutter `3.11+`
- Android BLE printer (BLE only)
- App must include required Android Bluetooth permissions in `AndroidManifest.xml`

Important:
- This package currently targets BLE printers. Bluetooth Classic printers are not supported by this flow.
- Text-mode ESC/POS printing is intentionally avoided; printing is image-only.

## Install

`pubspec.yaml`:

```yaml
dependencies:
  pos_printer_kit:
    git:
      url: https://github.com/n3k00/pos_printer_kit.git
      ref: main
```

Then:

```bash
flutter pub get
```

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:pos_printer_kit/pos_printer_kit.dart';

class PrinterHostPage extends StatefulWidget {
  const PrinterHostPage({super.key});

  @override
  State<PrinterHostPage> createState() => _PrinterHostPageState();
}

class _PrinterHostPageState extends State<PrinterHostPage> {
  late final PrinterCore core;

  @override
  void initState() {
    super.initState();
    core = PrinterCore()..initialize();
  }

  @override
  void dispose() {
    core.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrinterConnectPage(core: core),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            if (!core.hasConnectedPrinter) return;
            await core.testPrint();
          },
          child: const Text('Send Test Image Print'),
        ),
      ),
    );
  }
}
```

## Printing API

### Print image bytes

```dart
await core.printImage(
  imageBytes, // Uint8List (PNG/JPG bytes)
  config: const PrinterPrintConfig(
    width: 384,
    threshold: 160,
    copies: 1,
    ditherMode: PrinterDitherMode.floydSteinberg,
    feedLinesAfterPrint: 2,
    cutMode: PrinterCutMode.none,
  ),
);
```

`PrinterPrintConfig` fields:
- `width`: target render width in pixels
- `threshold`: black/white threshold
- `copies`: print copies
- `ditherMode`: `threshold` or `floydSteinberg`
- `feedLinesAfterPrint`: line feeds after raster print
- `cutMode`: `none`, `full`, `partial`

## Recommended workflow for Myanmar output

1. Render receipt/label as image in app layer
2. Pass image bytes to `printImage(...)`
3. Avoid direct text-mode printing for Myanmar glyph reliability

## Known limitations

- BLE only (no Classic/SPP path in this package)
- Current i18n in connect page is hardcoded English (localization layer planned)
- Dithering quality/output may vary by printer model and paper

## License and dependency notice

- This repository license applies to `pos_printer_kit` source.
- Third-party dependency licenses still apply to their own packages.
- `flutter_blue_plus` has its own license terms; verify suitability for your commercial use before production rollout.
- See `THIRD_PARTY_NOTICES.md` for dependency-specific compliance notes.

## Roadmap

- UI localization (`en` / `my`) with overridable strings
- Persist and auto-reconnect last printer
- Better image pipeline options (dithering, width profiles)
- Typed error model for connection/printing failures

## Release process

- Follow `CHANGELOG_RULES.md` for changelog/version policy.
- Create annotated tags for releases (example: `v0.1.0`).
