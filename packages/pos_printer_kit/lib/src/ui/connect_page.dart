import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/printer_core.dart';
import '../l10n/printer_ui_strings.dart';

class PrinterConnectPage extends StatefulWidget {
  const PrinterConnectPage({
    super.key,
    required this.core,
    this.strings,
    this.textOverrides,
  });

  final PrinterCore core;
  final PrinterUiStrings? strings;
  final PrinterUiTextOverrides? textOverrides;

  @override
  State<PrinterConnectPage> createState() => _PrinterConnectPageState();
}

class _PrinterConnectPageState extends State<PrinterConnectPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  bool _wasScanning = false;
  bool _hasCompletedSearch = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _wasScanning = widget.core.isScanning;
    widget.core.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    widget.core.removeListener(_handleControllerChange);
    _ringController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final scanning = widget.core.isScanning;
    if (!scanning && _wasScanning) {
      setState(() => _hasCompletedSearch = true);
    }
    _wasScanning = scanning;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.core;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final isConnected = c.hasConnectedPrinter;
        final isConnecting = c.busy;
        final isScanning = c.isScanning;
        final adapterOn = c.adapterState == BluetoothAdapterState.on;

        final showResultsMode =
            !isConnected && !isConnecting && !isScanning && _hasCompletedSearch;
        final showCenteredMode = !showResultsMode;

        final bg = const Color(0xFFF4F7FB);
        final textPrimary = const Color(0xFF142033);
        final textSecondary = const Color(0xFF5E6B80);
        final blue = const Color(0xFF1D9BF0);
        final ringColor = isConnected ? const Color(0xFF19A55A) : blue;
        final animateRing = !isConnected && (isScanning || isConnecting);
        final localeCode = Localizations.localeOf(context).languageCode;
        final baseStrings =
            widget.strings ?? PrinterUiStrings.forLanguageCode(localeCode);
        final s = widget.textOverrides == null
            ? baseStrings
            : widget.textOverrides!.applyTo(baseStrings);

        final title = isConnected
            ? s.connectedTitle
            : (isConnecting
                ? s.connectingTitle
                : (isScanning
                    ? s.searchingPrintersTitle
                    : (showResultsMode
                        ? s.selectPrinterTitle
                        : s.readyToSearchTitle)));
        final subtitle = isConnected
            ? s.connectedSubtitle
            : (isConnecting
                ? s.connectingSubtitle
                : (isScanning
                    ? s.searchingSubtitle
                    : (showResultsMode
                        ? s.selectPrinterSubtitle
                        : s.readyToSearchSubtitle)));

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      color: textSecondary,
                    ),
                  ),
                  if (showCenteredMode)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BluetoothPulse(
                            color: ringColor,
                            controller: _ringController,
                            animate: animateRing,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 40,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: TextStyle(color: textSecondary, fontSize: 17),
                            textAlign: TextAlign.center,
                          ),
                          if (isConnected && c.connectedDevice != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7EF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                c.displayName(c.connectedDevice!),
                                style: const TextStyle(
                                  color: Color(0xFF1A7F4C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Center(
                            child: Column(
                              children: [
                                _BluetoothPulse(
                                  color: ringColor,
                                  controller: _ringController,
                                  animate: false,
                                  size: 150,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 34,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            s.printersFoundLabel,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: c.results.isEmpty
                                ? Center(
                                    child: Text(
                                      s.noBlePrinterFoundLabel,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 17,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: c.results.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFFDCE3EE),
                                        ),
                                    itemBuilder: (context, index) {
                                      final r = c.results[index];
                                      final d = r.device;
                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(vertical: 6),
                                        onTap: c.busy ? null : () => c.connect(r),
                                        leading: Icon(Icons.bluetooth, color: blue),
                                        title: Text(
                                          c.displayName(d),
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontSize: 20,
                                          ),
                                        ),
                                        subtitle: Text(
                                          d.remoteId.str,
                                          style: TextStyle(color: textSecondary),
                                        ),
                                        trailing: Icon(
                                          Icons.chevron_right,
                                          color: blue,
                                          size: 28,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  _BottomActions(
                    strings: s,
                    isConnecting: isConnecting,
                    isConnected: isConnected,
                    isScanning: isScanning,
                    adapterOn: adapterOn,
                    busy: c.busy,
                    onStart: c.startScan,
                    onStop: c.stopScan,
                    onDisconnect: c.disconnect,
                    onDone: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BluetoothPulse extends StatelessWidget {
  const _BluetoothPulse({
    required this.color,
    required this.controller,
    required this.animate,
    this.size = 180,
  });

  final Color color;
  final AnimationController controller;
  final bool animate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size >= 100 ? 72.0 : 44.0;
    final iconRadius = iconSize / 2;
    final baseRing = size * 0.73;
    final r1 = baseRing * 0.42;
    final r2 = baseRing * 0.58;
    final r3 = baseRing * 0.74;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (animate) ...[
                _ring(r1, 1.0),
                _ring(r2, 0.66),
                _ring(r3, 0.33),
              ] else
                Container(
                  width: baseRing,
                  height: baseRing,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.20),
                      width: 1.6,
                    ),
                  ),
                ),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.bluetooth,
                  color: Colors.white,
                  size: iconRadius,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(double radius, double offset) {
    final progress = (controller.value + offset) % 1.0;
    final opacity = (1 - progress).clamp(0.0, 1.0) * 0.55;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity), width: 1.4),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.strings,
    required this.isConnecting,
    required this.isConnected,
    required this.isScanning,
    required this.adapterOn,
    required this.busy,
    required this.onStart,
    required this.onStop,
    required this.onDisconnect,
    required this.onDone,
  });

  final PrinterUiStrings strings;
  final bool isConnecting;
  final bool isConnected;
  final bool isScanning;
  final bool adapterOn;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onDisconnect;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1D9BF0);
    const successGreen = Color(0xFF16A34A);
    const warningAmber = Color(0xFFD97706);
    const dangerRed = Color(0xFFDC2626);

    String primaryText;
    VoidCallback? primaryAction;
    Color primaryBg = brandBlue;
    Color primaryFg = Colors.white;
    if (isConnecting || busy) {
      primaryText = strings.connectingButton;
      primaryAction = null;
    } else if (isConnected) {
      primaryText = strings.doneButton;
      primaryAction = onDone;
      primaryBg = successGreen;
    } else if (isScanning) {
      primaryText = strings.stopSearchingButton;
      primaryAction = onStop;
      primaryBg = warningAmber;
    } else {
      primaryText = strings.startSearchingButton;
      primaryAction = adapterOn ? onStart : null;
      primaryBg = brandBlue;
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: primaryAction,
            style: FilledButton.styleFrom(
              backgroundColor: primaryBg,
              foregroundColor: primaryFg,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              primaryText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onDisconnect,
            style: TextButton.styleFrom(
              foregroundColor: dangerRed,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
            child: Text(
              strings.disconnectButton,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}
