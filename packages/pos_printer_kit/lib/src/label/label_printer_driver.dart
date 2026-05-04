import 'label_models.dart';

abstract class LabelPrinterDriver {
  const LabelPrinterDriver();

  Future<List<int>> buildPrintJobBytes(LabelPrintJob job);
}
