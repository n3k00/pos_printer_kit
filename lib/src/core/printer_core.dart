import 'dart:async';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_connection_state.dart';
import 'printer_device.dart';
import 'printer_errors.dart';
import 'printer_observability.dart';
import 'printer_print_config.dart';
import 'printer_retry_policy.dart';

class PrinterCore extends ChangeNotifier {
  PrinterCore({
    this.autoReconnectEnabled = true,
    this.logCallback,
    this.connectRetryPolicy = const PrinterRetryPolicy(),
  });

  static const String _savedPrinterIdKey = 'pos_printer_kit.last_printer_id';
  static const String _savedPrinterNameKey = 'pos_printer_kit.last_printer_name';
  static Future<CapabilityProfile>? _escCapabilityProfileFuture;

  List<PrinterDevice> results = [];
  PrinterDevice? connectedDevice;
  bool isBluetoothOn = false;
  bool isScanning = false;
  bool busy = false;
  bool _isConnected = false;
  String status = 'Ready';
  Duration scanTimeout = const Duration(seconds: 8);
  PrinterOperationException? lastError;
  final bool autoReconnectEnabled;
  final PrinterLogCallback? logCallback;
  final PrinterRetryPolicy connectRetryPolicy;
  String? lastConnectedPrinterId;
  String? lastConnectedPrinterName;
  PrinterConnectionState connectionState = const PrinterConnectionState(
    stage: PrinterConnectionStage.idle,
    message: 'Ready',
  );

  final StreamController<PrinterConnectionState> _stateController =
      StreamController<PrinterConnectionState>.broadcast();
  final StreamController<PrinterPrintProgress> _printProgressController =
      StreamController<PrinterPrintProgress>.broadcast();
  final StreamController<PrinterOperationException> _errorController =
      StreamController<PrinterOperationException>.broadcast();

  Stream<PrinterConnectionState> get onStateChanged => _stateController.stream;
  Stream<PrinterPrintProgress> get onPrintProgress =>
      _printProgressController.stream;
  Stream<PrinterOperationException> get onError => _errorController.stream;

  Future<void> initialize() async {
    await _loadSavedPrinterMeta();
    await _refreshBluetoothState();
    if (autoReconnectEnabled && lastConnectedPrinterId != null) {
      await reconnectSavedPrinter();
    } else {
      notifyListeners();
    }
  }

  Future<void> _refreshBluetoothState() async {
    try {
      isBluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (isBluetoothOn) {
        _setStatus('Bluetooth ready.');
      } else {
        _setStatus('Bluetooth is off.');
      }
    } catch (e) {
      isBluetoothOn = false;
      _setStatus('Bluetooth init failed: $e');
    }
  }

  Future<void> startScan() async {
    if (busy) return;
    busy = true;
    isScanning = true;
    results = [];
    clearError(notify: false);
    notifyListeners();

    try {
      await _refreshBluetoothState();
      if (!isBluetoothOn) {
        _setError(const BluetoothOffException());
        return;
      }

      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startSearching,
      );
      _emitStateChange();
      _setStatus('Loading paired Bluetooth printers...');

      final paired = await PrintBluetoothThermal.pairedBluetooths;
      results = paired
          .map(
            (e) => PrinterDevice(
              id: e.macAdress.trim(),
              name: e.name.trim().isEmpty ? e.macAdress.trim() : e.name.trim(),
            ),
          )
          .where((e) => e.id.isNotEmpty)
          .toList();

      results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.stopSearching,
      );
      _emitStateChange();
      _setStatus(
        results.isEmpty
            ? 'No paired Bluetooth printer found.'
            : 'Found ${results.length} paired printer(s).',
      );
    } catch (e) {
      _setError(
        PrinterOperationException(
          code: 'scan_failed',
          message: 'Could not load paired Bluetooth printers.',
          cause: e,
        ),
      );
    } finally {
      isScanning = false;
      busy = false;
      notifyListeners();
    }
  }

  void setScanTimeout(Duration value) {
    if (value.inMilliseconds <= 0) return;
    scanTimeout = value;
  }

  Future<void> stopScan() async {
    isScanning = false;
    connectionState = PrinterConnectionMachine.transition(
      connectionState,
      PrinterConnectionEvent.stopSearching,
    );
    _emitStateChange();
    _setStatus('Scan stopped.');
  }

  Future<void> connect(PrinterDevice device) async {
    if (busy) return;
    busy = true;
    notifyListeners();

    try {
      await stopScan();
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startConnecting,
        deviceId: device.id,
        deviceName: device.name,
      );
      _emitStateChange();
      _setStatus('Connecting to ${device.name}...');

      final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.id,
      );
      if (!ok) {
        _setError(
          PrinterOperationException(
            code: 'connect_failed',
            message: 'Could not connect to printer.',
          ),
        );
        return;
      }

      _isConnected = true;
      connectedDevice = device;
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.connected,
        deviceId: device.id,
        deviceName: device.name,
        message: 'Connected',
      );
      _emitStateChange();
      await _saveLastPrinter(device.id, device.name);
      _setStatus('Connected. Ready to print.');
    } catch (e) {
      _setError(
        PrinterOperationException(
          code: 'connect_failed',
          message: 'Could not connect to printer.',
          cause: e,
        ),
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      final ok = await PrintBluetoothThermal.disconnect;
      if (!ok) {
        _setStatus('Disconnect may not have completed.');
      } else {
        _setStatus('Disconnected.');
      }
    } catch (e) {
      _setStatus('Disconnect failed: $e');
    } finally {
      _isConnected = false;
      connectedDevice = null;
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.disconnected,
        message: 'Disconnected',
      );
      _emitStateChange();
      notifyListeners();
    }
  }

  Future<bool> reconnectSavedPrinter() async {
    final savedId = lastConnectedPrinterId;
    if (savedId == null || savedId.isEmpty) return false;
    if (busy) return false;

    final saved = PrinterDevice(
      id: savedId,
      name: (lastConnectedPrinterName ?? savedId).trim(),
    );
    await connect(saved);
    return hasConnectedPrinter;
  }

  Future<void> forgetSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPrinterIdKey);
    await prefs.remove(_savedPrinterNameKey);
    lastConnectedPrinterId = null;
    lastConnectedPrinterName = null;
    notifyListeners();
  }

  @Deprecated('Use printImage(Uint8List, {config}) as primary API.')
  Future<bool> testPrint() async {
    return printDemoImage();
  }

  Future<bool> printDemoImage() async {
    final demo = img.Image(width: 384, height: 220);
    img.fill(demo, color: img.ColorRgb8(255, 255, 255));
    img.drawRect(
      demo,
      x1: 8,
      y1: 8,
      x2: 376,
      y2: 212,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 2,
    );
    img.drawRect(
      demo,
      x1: 16,
      y1: 16,
      x2: 368,
      y2: 64,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 2,
    );
    img.drawLine(
      demo,
      x1: 16,
      y1: 92,
      x2: 368,
      y2: 92,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 1,
    );
    img.drawLine(
      demo,
      x1: 16,
      y1: 128,
      x2: 368,
      y2: 128,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 1,
    );
    img.drawLine(
      demo,
      x1: 16,
      y1: 164,
      x2: 368,
      y2: 164,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 1,
    );
    final pngBytes = Uint8List.fromList(img.encodePng(demo));
    return printImage(pngBytes);
  }

  Future<bool> printImage(
    Uint8List imageBytes, {
    PrinterPrintConfig config = const PrinterPrintConfig(),
  }) async {
    if (!hasConnectedPrinter) {
      _setError(const NoWritableCharacteristicException());
      return false;
    }

    if (busy) return false;
    busy = true;
    notifyListeners();
    _emitPrintProgress(
      const PrinterPrintProgress(
        stage: PrinterPrintProgressStage.started,
      ),
    );

    try {
      clearError(notify: false);
      final escPosBytes = await _buildEscPosImageBytes(imageBytes, config: config);
      final copyCount = config.copies < 1 ? 1 : config.copies;
      for (var i = 0; i < copyCount; i++) {
        final ok = await PrintBluetoothThermal.writeBytes(escPosBytes);
        if (!ok) {
          _handleRemoteDisconnect();
          throw PrinterOperationException(
            code: 'thermal_write_failed',
            message: 'Failed to send data to printer.',
          );
        }
        _emitPrintProgress(
          PrinterPrintProgress(
            stage: PrinterPrintProgressStage.copySent,
            currentCopy: i + 1,
            totalCopies: copyCount,
          ),
        );
      }
      _setStatus('Image print sent (${escPosBytes.length} bytes x $copyCount).');
      _emitPrintProgress(
        PrinterPrintProgress(
          stage: PrinterPrintProgressStage.completed,
          currentCopy: copyCount,
          totalCopies: copyCount,
        ),
      );
      return true;
    } catch (e) {
      _setError(
        PrinterOperationException(
          code: 'print_failed',
          message: 'Image print failed.',
          cause: e,
        ),
      );
      _emitPrintProgress(
        PrinterPrintProgress(
          stage: PrinterPrintProgressStage.failed,
          message: e.toString(),
        ),
      );
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _handleRemoteDisconnect() {
    if (!_isConnected) return;
    _isConnected = false;
    connectedDevice = null;
    connectionState = PrinterConnectionMachine.transition(
      connectionState,
      PrinterConnectionEvent.disconnected,
      message: 'Disconnected',
    );
    _emitStateChange();
    _setStatus('Printer connection lost.');
    notifyListeners();
  }

  Future<List<int>> _buildEscPosImageBytes(
    Uint8List imageBytes, {
    required PrinterPrintConfig config,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw PrinterOperationException(
        code: 'invalid_image',
        message: 'Could not decode image bytes.',
      );
    }

    final targetWidth = config.width <= 0 ? 384 : config.width;
    final prepared = decoded.width == targetWidth
        ? decoded
        : img.copyResize(decoded, width: targetWidth);

    final profile = await _loadEscCapabilityProfile();
    final paper = targetWidth >= 550 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    final bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.imageRaster(prepared, align: PosAlign.center));

    final feed = config.feedLinesAfterPrint.clamp(0, 255).toInt();
    if (feed > 0) {
      bytes.addAll(generator.feed(feed));
    }
    if (config.allowCutCommands) {
      switch (config.cutMode) {
        case PrinterCutMode.none:
          break;
        case PrinterCutMode.full:
          bytes.addAll(generator.cut(mode: PosCutMode.full));
          break;
        case PrinterCutMode.partial:
          bytes.addAll(generator.cut(mode: PosCutMode.partial));
          break;
      }
    }
    return bytes;
  }

  Future<CapabilityProfile> _loadEscCapabilityProfile() {
    return _escCapabilityProfileFuture ??= CapabilityProfile.load();
  }

  bool get hasConnectedPrinter => _isConnected && connectedDevice != null;

  String displayName(PrinterDevice device) {
    final name = device.name.trim();
    if (name.isNotEmpty) return name;
    if (device.id == lastConnectedPrinterId) {
      final saved = (lastConnectedPrinterName ?? '').trim();
      if (saved.isNotEmpty) return saved;
    }
    return device.id;
  }

  Color bluetoothStatusColor(ThemeData theme) {
    if (hasConnectedPrinter) return Colors.green;
    if (busy || isScanning) return Colors.amber.shade700;
    return theme.colorScheme.outline;
  }

  void _setStatus(String message) {
    status = message;
    lastError = null;
    _log('[status] $message');
    notifyListeners();
  }

  void _setError(PrinterOperationException error) {
    lastError = error;
    status = error.message;
    connectionState = PrinterConnectionMachine.transition(
      connectionState,
      PrinterConnectionEvent.failed,
      message: error.message,
      deviceId: connectedDevice?.id,
      deviceName: connectedDevice?.name,
    );
    _emitStateChange();
    _errorController.add(error);
    _log('[error] ${error.code}: ${error.message}');
    notifyListeners();
  }

  void clearError({bool notify = true}) {
    lastError = null;
    if (notify) notifyListeners();
  }

  Future<void> _saveLastPrinter(String id, String? name) async {
    lastConnectedPrinterId = id;
    final normalizedName = (name ?? '').trim();
    if (normalizedName.isNotEmpty) {
      lastConnectedPrinterName = normalizedName;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPrinterIdKey, id);
    if (normalizedName.isNotEmpty) {
      await prefs.setString(_savedPrinterNameKey, normalizedName);
    }
  }

  Future<void> _loadSavedPrinterMeta() async {
    final prefs = await SharedPreferences.getInstance();
    lastConnectedPrinterId = prefs.getString(_savedPrinterIdKey);
    lastConnectedPrinterName = prefs.getString(_savedPrinterNameKey);
  }

  @override
  void dispose() {
    _stateController.close();
    _printProgressController.close();
    _errorController.close();
    super.dispose();
  }

  void _emitStateChange() {
    _stateController.add(connectionState);
    _log(
      '[state] ${connectionState.stage.name} '
      'device=${connectionState.deviceName ?? connectionState.deviceId ?? '-'}',
    );
  }

  void _emitPrintProgress(PrinterPrintProgress progress) {
    _printProgressController.add(progress);
    _log(
      '[print] ${progress.stage.name} '
      'copy=${progress.currentCopy ?? '-'} / ${progress.totalCopies ?? '-'}',
    );
  }

  void _log(String message) {
    logCallback?.call(message);
  }
}
