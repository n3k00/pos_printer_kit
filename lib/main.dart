import 'package:flutter/material.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: HomePrintPage(controller: _controller),
    );
  }
}

class HomePrintPage extends StatelessWidget {
  const HomePrintPage({super.key, required this.controller});

  final PrinterCore controller;

  Future<void> _goToConnectPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrinterConnectPage(core: controller),
      ),
    );
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
                            await controller.testPrint();
                          },
                    child: Text(
                      controller.hasConnectedPrinter
                          ? 'Send Test Image Print'
                          : 'Connect Printer First',
                    ),
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
