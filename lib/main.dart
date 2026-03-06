import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
              ],
            ),
          ),
        );
      },
    );
  }
}
