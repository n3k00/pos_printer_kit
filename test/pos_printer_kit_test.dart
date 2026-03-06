import 'package:flutter_test/flutter_test.dart';

import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  test('exports package symbols', () {
    const strings = PrinterUiStrings();
    expect(strings.readyToSearch, isNotEmpty);
  });
}
