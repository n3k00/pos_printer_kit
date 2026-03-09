import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:pos_printer_kit/pos_printer_kit.dart';

void main() {
  runApp(const PrinterApp());
}

class PrinterApp extends StatefulWidget {
  const PrinterApp({super.key});

  @override
  State<PrinterApp> createState() => _PrinterAppState();
}

class _PrinterAppState extends State<PrinterApp> {
  late final PrinterCore _controller;
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _controller = PrinterCore()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Printer',
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('my'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomePrintPage(
        controller: _controller,
        locale: _locale,
        onLocaleChanged: (Locale locale) {
          setState(() => _locale = locale);
        },
      ),
    );
  }
}

class HomePrintPage extends StatelessWidget {
  const HomePrintPage({
    super.key,
    required this.controller,
    required this.locale,
    required this.onLocaleChanged,
  });

  final PrinterCore controller;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  Future<void> _goToConnectPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrinterConnectPage(core: controller),
      ),
    );
  }

  Future<void> _print80mmSample(BuildContext context) async {
    if (!controller.hasConnectedPrinter) {
      await _goToConnectPage(context);
      if (!controller.hasConnectedPrinter) return;
    }

    final bytes = _buildSampleReceiptImage(width: 560, title: '80MM SAMPLE RECEIPT');
    const config = PrinterPrintConfig(
      width: 560,
      threshold: 175,
      copies: 1,
      ditherMode: PrinterDitherMode.threshold,
      chunkDelayMs: 8,
      maxChunkSize: 220,
      preferWriteWithoutResponse: true,
      feedLinesAfterPrint: 0,
      cutMode: PrinterCutMode.none,
      allowCutCommands: false,
    );
    await controller.printImage(bytes, config: config);
  }

  Uint8List _buildSampleReceiptImage({
    required int width,
    required String title,
  }) {
    const height = 1200;
    final image = img.Image(width: width, height: height);
    final black = img.ColorRgb8(0, 0, 0);
    final white = img.ColorRgb8(255, 255, 255);
    // Positive value shifts content to the right for printer alignment calibration.
    const horizontalOffset = 10;
    final basePad = width > 420 ? 14 : 10;
    final leftPad = basePad + horizontalOffset;
    final rightPad = (basePad - horizontalOffset).clamp(4, 40);
    final textLeft = leftPad + 8;
    final qtyX = (width * 0.63).round();
    final priceX = (width * 0.74).round();
    final summaryX = (width * 0.54).round();

    img.fill(image, color: white);
    img.drawRect(
      image,
      x1: leftPad,
      y1: 18,
      x2: width - rightPad,
      y2: 130,
      color: black,
      thickness: 2,
    );
    img.drawString(
      image,
      title,
      font: img.arial48,
      y: 44,
      color: black,
    );
    img.drawString(
      image,
      'POS PRINTER KIT',
      font: img.arial24,
      x: (width * 0.31).round(),
      y: 104,
      color: black,
    );

    var y = 198;
    img.drawString(image, 'Date: ${DateTime.now()}', font: img.arial24, x: textLeft, y: y, color: black);
    y += 46;
    img.drawLine(image, x1: leftPad, y1: y, x2: width - rightPad, y2: y, color: black, thickness: 1);
    y += 18;

    img.drawString(image, 'Item', font: img.arial24, x: textLeft, y: y, color: black);
    img.drawString(image, 'Qty', font: img.arial24, x: qtyX, y: y, color: black);
    img.drawString(image, 'Price', font: img.arial24, x: priceX, y: y, color: black);
    y += 38;
    img.drawLine(image, x1: leftPad, y1: y, x2: width - rightPad, y2: y, color: black, thickness: 1);
    y += 16;

    final rows = <({String name, int qty, int price})>[
      (name: 'Americano', qty: 2, price: 7000),
      (name: 'Croissant', qty: 1, price: 2500),
      (name: 'Water 600ml', qty: 3, price: 3000),
    ];

    for (final row in rows) {
      img.drawString(image, row.name, font: img.arial24, x: textLeft, y: y, color: black);
      img.drawString(image, '${row.qty}', font: img.arial24, x: qtyX + 4, y: y, color: black);
      img.drawString(image, '${row.price}', font: img.arial24, x: priceX, y: y, color: black);
      y += 36;
    }

    y += 12;
    img.drawLine(image, x1: leftPad, y1: y, x2: width - rightPad, y2: y, color: black, thickness: 1);
    y += 18;
    img.drawString(image, 'Subtotal: 12500', font: img.arial24, x: summaryX, y: y, color: black);
    y += 36;
    img.drawString(image, 'Tax (5%): 625', font: img.arial24, x: summaryX, y: y, color: black);
    y += 36;
    img.drawString(
      image,
      'TOTAL: 13125',
      font: img.arial48,
      x: (width * 0.36).round(),
      y: y - 4,
      color: black,
    );
    y += 68;

    img.drawLine(image, x1: leftPad, y1: y, x2: width - rightPad, y2: y, color: black, thickness: 1);
    y += 20;
    img.drawString(
      image,
      'THANK YOU',
      font: img.arial48,
      x: (width * 0.26).round(),
      y: y,
      color: black,
    );
    y += 62;
    img.drawString(
      image,
      'Image-based print pipeline (Myanmar-safe)',
      font: img.arial24,
      x: (width * 0.10).round(),
      y: y,
      color: black,
    );

    final usedHeight = (y + 66).clamp(260, height);
    final cropped = img.copyCrop(
      image,
      x: 0,
      y: 0,
      width: width,
      height: usedHeight,
    );
    return Uint8List.fromList(img.encodePng(cropped));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final connectedName = controller.connectedDevice == null
            ? 'No printer connected'
            : controller.displayName(controller.connectedDevice!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('POS Print'),
            actions: [
              PopupMenuButton<Locale>(
                tooltip: 'Language',
                icon: const Icon(Icons.language),
                onSelected: onLocaleChanged,
                itemBuilder: (context) => [
                  PopupMenuItem<Locale>(
                    value: const Locale('en'),
                    child: Row(
                      children: [
                        const Text('English'),
                        const Spacer(),
                        if (locale.languageCode == 'en')
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                  PopupMenuItem<Locale>(
                    value: const Locale('my'),
                    child: Row(
                      children: [
                        const Text('Myanmar'),
                        const Spacer(),
                        if (locale.languageCode == 'my')
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Connect printer',
                onPressed: () => _goToConnectPage(context),
                icon: Icon(
                  Icons.bluetooth,
                  color: controller.bluetoothStatusColor(theme),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Printer', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(connectedName),
                        const SizedBox(height: 6),
                        Text(controller.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Print mode: Image-only raster print (for Myanmar-safe output).',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () async {
                            if (!controller.hasConnectedPrinter) {
                              await _goToConnectPage(context);
                              return;
                            }
                            await controller.printDemoImage();
                          },
                    child: Text(
                      controller.hasConnectedPrinter
                          ? 'Send Test Image Print'
                          : 'Connect Printer First',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: controller.busy
                        ? null
                        : () => _print80mmSample(context),
                    child: const Text('Print 80mm Sample Page'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
