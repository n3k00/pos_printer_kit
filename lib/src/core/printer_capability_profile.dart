import 'printer_print_enums.dart';

class PrinterCapabilityProfile {
  const PrinterCapabilityProfile({
    required this.id,
    required this.displayName,
    required this.paperWidthPx,
    required this.supportsCut,
    required this.defaultFeedLinesAfterPrint,
    required this.defaultDitherMode,
    required this.quirks,
  });

  final String id;
  final String displayName;
  final int paperWidthPx;
  final bool supportsCut;
  final int defaultFeedLinesAfterPrint;
  final PrinterDitherMode defaultDitherMode;
  final Map<String, String> quirks;

  static const PrinterCapabilityProfile receipt58 = PrinterCapabilityProfile(
    id: 'receipt_58mm',
    displayName: 'Receipt 58mm',
    paperWidthPx: 384,
    supportsCut: false,
    defaultFeedLinesAfterPrint: 2,
    defaultDitherMode: PrinterDitherMode.threshold,
    quirks: {
      'width': 'Typical printable width is ~384px.',
      'cut': 'Most portable 58mm printers do not have an auto cutter.',
    },
  );

  static const PrinterCapabilityProfile receipt80 = PrinterCapabilityProfile(
    id: 'receipt_80mm',
    displayName: 'Receipt 80mm',
    paperWidthPx: 576,
    supportsCut: true,
    defaultFeedLinesAfterPrint: 3,
    defaultDitherMode: PrinterDitherMode.floydSteinberg,
    quirks: {
      'width': 'Typical printable width is ~576px.',
      'cut': 'Auto cutter is common on desktop 80mm printers.',
    },
  );

  static const PrinterCapabilityProfile xpP323b = PrinterCapabilityProfile(
    id: 'xp_p323b',
    displayName: 'XP-P323B',
    paperWidthPx: 384,
    supportsCut: false,
    defaultFeedLinesAfterPrint: 2,
    defaultDitherMode: PrinterDitherMode.threshold,
    quirks: {
      'connectivity': 'BLE mode supported. Bluetooth Classic is separate.',
      'encoding': 'Use image print for Myanmar-safe output.',
      'cut': 'No hardware cutter; ignore cut commands.',
    },
  );

  static const List<PrinterCapabilityProfile> knownProfiles = [
    receipt58,
    receipt80,
    xpP323b,
  ];

  static PrinterCapabilityProfile? findByModelName(String modelName) {
    final normalized = modelName.toLowerCase().trim();
    for (final profile in knownProfiles) {
      if (normalized.contains(profile.id.replaceAll('_', '')) ||
          normalized.contains(profile.displayName.toLowerCase().replaceAll('-', ''))) {
        return profile;
      }
    }
    if (normalized.contains('xp-p323b') || normalized.contains('p323b')) {
      return xpP323b;
    }
    if (normalized.contains('80mm')) return receipt80;
    if (normalized.contains('58mm')) return receipt58;
    return null;
  }
}
