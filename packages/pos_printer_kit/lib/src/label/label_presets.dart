import 'label_models.dart';

class LabelPresets {
  const LabelPresets._();

  static const LabelMediaConfig xp326b72x50 = LabelMediaConfig(
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
