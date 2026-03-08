# pos_printer_kit

Reusable Flutter package for POS thermal printing.

This package is designed for:
- app developers who need BLE printer connect + print quickly
- maintainers who need clear extension points
- AI/code agents that need reliable project context to patch safely

## What This Package Does

- BLE printer discovery/connect/disconnect
- reusable connect page UI (`PrinterConnectPage`)
- image-only ESC/POS raster printing (recommended for Myanmar-safe output)
- print configuration controls (`PrinterPrintConfig`)
- typed error model for core operations
- optional last-printer persistence + auto reconnect
- print transport prefers `print_bluetooth_thermal` + `esc_pos_utils_plus` for faster send path

## What This Package Does Not Do

- guaranteed vendor-specific command compatibility across all printer models
- raw text-mode Unicode printing reliability (use image pipeline)
- universal dual-transport discovery UX (current connect UI remains BLE-first)

## Package Layout

- `lib/src/core/`
  - connection logic, print orchestration, errors, state machine
- `lib/src/ui/`
  - connect page widgets and flows
- `lib/src/image_print/`
  - raster encoder and image-print helpers
- `lib/src/l10n/`
  - connect page UI strings and overrides

## Install

```yaml
dependencies:
  pos_printer_kit:
    git:
      url: https://github.com/n3k00/pos_printer_kit.git
      ref: v0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

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
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PrinterConnectPage(core: core),
                ),
              );
            },
            icon: const Icon(Icons.bluetooth),
          ),
        ],
      ),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            if (!core.hasConnectedPrinter) return;
            await core.printDemoImage();
          },
          child: const Text('Test Print'),
        ),
      ),
    );
  }
}
```

## Primary Printing API

Use `printImage` as the primary API.

```dart
await core.printImage(
  imageBytes, // Uint8List (PNG/JPG)
  config: const PrinterPrintConfig(
    width: 384,
    threshold: 160,
    copies: 1,
    ditherMode: PrinterDitherMode.floydSteinberg,
    feedLinesAfterPrint: 2,
    cutMode: PrinterCutMode.none,
    chunkDelayMs: 12,
    maxChunkSize: 180,
    preferWriteWithoutResponse: false,
  ),
);
```

`PrinterPrintConfig`:
- `width`
- `threshold`
- `copies`
- `ditherMode` (`threshold`, `floydSteinberg`)
- `feedLinesAfterPrint`
- `cutMode` (`none`, `full`, `partial`)
- `allowCutCommands`
- `chunkDelayMs` (default `12`, lower is faster but may reduce stability)
- `maxChunkSize` (default `180`, upper bound for each BLE write chunk)
- `preferWriteWithoutResponse` (can improve speed on some printers)

Transport behavior:
- package first attempts `print_bluetooth_thermal` connection/write path
- if that path is not available, package falls back to BLE chunk writing

## Printer Capability Profiles

Built-in profiles:
- `PrinterCapabilityProfile.receipt58` (384px, cutter usually not available)
- `PrinterCapabilityProfile.receipt80` (576px, cutter usually available)
- `PrinterCapabilityProfile.xpP323b` (portable BLE profile)

Use profile-based config:

```dart
final cfg = PrinterPrintConfig.fromProfile(
  PrinterCapabilityProfile.receipt58,
  ditherMode: PrinterDitherMode.floydSteinberg,
  copies: 1,
);
await core.printImage(imageBytes, config: cfg);
```

Model quirk lookup:

```dart
final profile = PrinterCapabilityProfile.findByModelName('XP-P323B');
if (profile != null) {
  debugPrint(profile.quirks.toString());
}
```

## Label Sticker Printing

Yes, this package can be used for label sticker workflows.

Recommended label config:

```dart
final labelConfig = PrinterPrintConfig.label(
  width: 384,
  threshold: 170,
  copies: 1,
  ditherMode: PrinterDitherMode.threshold,
);
await core.printImage(labelImageBytes, config: labelConfig);
```

Why this helps for labels:
- `feedLinesAfterPrint = 0` by default
- `cutMode = none` by default
- `allowCutCommands = false` by default
- avoids unnecessary paper feed/cut for sticker stock

## Localization

Connect page supports:
- English (`en`)
- Myanmar (`my`)

Default behavior:
- language auto-selects from app locale

Override behavior:
- pass `strings` or `textOverrides` to `PrinterConnectPage`

## Error Model

Typed errors are exposed via `PrinterCore.lastError`.

Examples:
- `BluetoothOffException`
- `NoWritableCharacteristicException`
- `ConnectTimeoutException`

## Retry / Backoff Policy

Connection retry behavior is configurable via `PrinterRetryPolicy`.

```dart
final core = PrinterCore(
  connectRetryPolicy: const PrinterRetryPolicy(
    maxRetries: 3,
    baseDelayMs: 500,
    backoffMultiplier: 2.0,
    maxDelayMs: 4000,
    retryGatt133Only: false,
  ),
);
```

Fields:
- `maxRetries`: number of retries after first failure
- `baseDelayMs`: delay before retry #1
- `backoffMultiplier`: exponential factor for next retries
- `maxDelayMs`: upper bound for retry delay
- `retryGatt133Only`: legacy compatibility flag (safe to keep `false` on current transport)

## Observability Hooks

`PrinterCore` exposes hooks for app telemetry and debugging:

- `onStateChanged` (`Stream<PrinterConnectionState>`)
- `onPrintProgress` (`Stream<PrinterPrintProgress>`)
- `onError` (`Stream<PrinterOperationException>`)
- `logCallback` (constructor callback)

Example:

```dart
final core = PrinterCore(
  logCallback: (msg) => debugPrint('[printer] $msg'),
);

core.onStateChanged.listen((s) {
  debugPrint('state=${s.stage} device=${s.deviceName}');
});

core.onPrintProgress.listen((p) {
  debugPrint('print=${p.stage} ${p.currentCopy}/${p.totalCopies}');
});

core.onError.listen((e) {
  debugPrint('error=${e.code} ${e.message}');
});
```

## Recommended Receipt Strategy

For Myanmar and mixed-language receipts:
1. Render receipt/label as image in app layer
2. Call `printImage(...)`
3. Avoid text-only ESC/POS for critical glyph correctness

## Host App Calibration Boundary

This package handles BLE transport, connection lifecycle, and print pipeline.
Final receipt layout calibration is intentionally host-app responsibility.

Host app should tune:
- image canvas width per deployed printer (`384`, `560`, `576`, etc.)
- horizontal offsets for model-specific centering
- bottom crop to remove trailing blank area
- font sizes and x/y layout for business design

Reason:
- printable area differs by hardware/firmware even inside "80mm" class
- package cannot safely assume fixed margin offsets for every vendor

## Current Gaps / Roadmap

These are practical improvements recommended for production apps:

- `PrinterSpeedProfile` presets (`fast`, `balanced`, `quality`) on top of low-level chunk settings
- byte-level print progress percentage (`sent/total`) for clearer UX feedback
- optional `printRasterBytes(...)` API to bypass repeated image encoding
- profile-level width calibration table per known model (e.g., safe 80mm width by model)
- richer examples for 80mm receipt and 80mm label sticker flows

## Development Rules (For Humans + AI Agents)

- Keep printing API backward-compatible within `0.x` where possible.
- Do not remove exported symbols without changelog note.
- Add/adjust tests for behavior changes.
- Prefer configurable defaults instead of hardcoded magic values.
- Keep BLE logic in `core`, UI logic in `ui`, encoding logic in `image_print`.

## Test Commands

```bash
flutter analyze
flutter test
```

## Release Process

1. Update `pubspec.yaml` version.
2. Update `CHANGELOG.md` using `CHANGELOG_RULES.md`.
3. Run analyze + tests.
4. Create annotated tag (`vX.Y.Z`).

## Compliance

- This repo uses MIT license (`LICENSE`).
- Third-party terms still apply to dependencies.
- Read `THIRD_PARTY_NOTICES.md` before commercial release.
- For runtime fault handling expectations, read `FAILURE_MATRIX.md`.
