# Label Print Architecture

This document defines the recommended long-term design for production-grade label printing in `pos_printer_kit`.

## Goal

Support printers such as `XP-P326B` with:

- fixed media sizes such as `72x50 mm`, `70x50 mm`, `40x40 mm`
- gap-aware printing
- single-label stop behavior
- content layout independent from media size
- Android-native label backend for better calibration behavior

## Core Principle

Treat receipt printing and label printing as separate pipelines.

- Receipt printing: ESC/POS image pipeline
- Label printing: TSPL or vendor SDK pipeline

Do not force label media handling through the receipt pipeline.

## Proposed Layers

### 1. Connection Layer

Responsible only for:

- scan
- connect
- disconnect
- connection state
- device identity

### 2. Driver Layer

Responsible for translating a print job into printer-specific commands.

Recommended drivers:

- `ReceiptPrinterDriver`
- `LabelPrinterDriver`
- `AndroidTsplSdkLabelDriver`

### 3. Job Layer

Responsible for describing what to print in stable package-level models.

Recommended jobs:

- `ReceiptPrintJob`
- `LabelPrintJob`

### 4. Rendering Layer

Responsible for preparing final bitmap content before it reaches the driver.

For labels:

- render content bitmap
- apply content width and height
- apply centering or offsets
- preserve white background

This layer should not contain gap calibration logic.

## Data Model

### LabelMediaConfig

Purpose: describe the physical label media.

Recommended fields:

- `widthMm`
- `heightMm`
- `gapMm`
- `paperType`
- `direction`
- `tearMode`
- `density`
- `sensorMode`

Example:

```dart
const LabelMediaConfig(
  widthMm: 72,
  heightMm: 50,
  gapMm: 2,
  paperType: LabelPaperType.gap,
  direction: LabelPrintDirection.normal,
  tearMode: LabelTearMode.off,
  density: 8,
  sensorMode: LabelSensorMode.gap,
);
```

### LabelContentLayout

Purpose: describe how content sits inside the media.

Recommended fields:

- `contentWidthPx`
- `contentHeightPx`
- `offsetXPx`
- `offsetYPx`
- `alignment`
- `background`

This is what enables `40x40` content to print inside `72x50` media cleanly.

### LabelPrintJob

Purpose: define one complete label print request.

Recommended fields:

- `media`
- `layout`
- `imageBytes`
- `copies`
- `calibrateBeforePrint`
- `advanceToNextGapAfterPrint`

Example:

```dart
final job = LabelPrintJob(
  media: LabelPresets.xp326b72x50,
  layout: const LabelContentLayout(
    contentWidthPx: 320,
    contentHeightPx: 320,
    alignment: LabelContentAlignment.center,
    offsetYPx: 40,
    background: LabelBackground.white,
  ),
  imageBytes: pngBytes,
  copies: 1,
  calibrateBeforePrint: false,
  advanceToNextGapAfterPrint: true,
);
```

## Backend Strategy

### A. Raw TSPL Path

Use as a fallback.

Strengths:

- simple
- no extra vendor binary dependency

Weaknesses:

- gap behavior varies by firmware
- command ordering can be model-specific
- stop-at-gap behavior is harder to make reliable

### B. Android Native SDK Label Path

Preferred for label printers.

Why:

- vendor/helper SDKs usually manage media calibration better
- gap seek behavior is more reliable
- single-label stop behavior is easier to achieve

Recommended abstraction:

```dart
abstract class LabelPrinterDriver {
  Future<void> configureMedia(LabelMediaConfig media);
  Future<void> printImage(LabelPrintJob job);
  Future<void> calibrateGap(LabelMediaConfig media);
}
```

Android implementation target:

- `AndroidTsplSdkLabelDriver`

## Presets

Add printer-specific presets so apps do not need to remember dimensions.

Example:

```dart
class LabelPresets {
  static const xp326b72x50 = LabelMediaConfig(
    widthMm: 72,
    heightMm: 50,
    gapMm: 2,
    paperType: LabelPaperType.gap,
    direction: LabelPrintDirection.normal,
    tearMode: LabelTearMode.off,
    density: 8,
    sensorMode: LabelSensorMode.gap,
  );
}
```

This should later expand into a model-profile table.

## Responsibility Split

### App Level

The app should decide:

- what business document to print
- which preset to use
- what language to render
- what content bitmap to generate

The app should not decide:

- raw TSPL command ordering
- calibration command sequence
- vendor-specific gap handling

### Package Level

The package should own:

- label media config types
- label job types
- printer model presets
- driver selection
- Android native label bridge
- calibration workflow

## UI Recommendation

For label printing screens, expose only app-friendly controls:

- label size preset
- copy count
- content alignment
- horizontal offset
- vertical offset
- calibrate paper action

Hide protocol-level details such as:

- raw TSPL mode
- command sequence
- bitmap row bytes

## Recommended Implementation Order

### Phase 1

- introduce `LabelMediaConfig`
- introduce `LabelContentLayout`
- introduce `LabelPrintJob`
- add `LabelPresets.xp326b72x50`

### Phase 2

- refactor current `printTsplLabelImage(...)` into a `LabelPrinterDriver`
- keep raw TSPL as fallback implementation

### Phase 3

- add Android-native label driver
- add `calibrateGap()` API
- add stable `printLabel(LabelPrintJob job)` API

### Phase 4

- add more presets
- add model quirks table
- add label diagnostics logging

## Public API Direction

Preferred long-term API:

```dart
Future<bool> printLabel(LabelPrintJob job);
Future<void> calibrateLabelMedia(LabelMediaConfig media);
```

Avoid growing this API as the final product API:

```dart
printTsplLabelImage(
  ...many low-level booleans and command toggles...
)
```

That low-level method is useful for experimentation but not ideal as the stable package API.

## Decision Summary

For `XP-P326B`-style label printing:

- keep receipt and label paths separate
- introduce structured label job and config types
- use raw TSPL only as fallback
- prefer Android-native SDK-backed label printing for reliable gap behavior
- expose one stable package API to the app
