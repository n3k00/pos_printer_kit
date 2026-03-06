import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_connection_state.dart';
import '../image_print/esc_pos_raster_encoder.dart';
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
  static const EscPosRasterEncoder _rasterEncoder = EscPosRasterEncoder();

  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  List<ScanResult> results = [];
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothAdapterState adapterState = BluetoothAdapterState.unknown;
  bool isScanning = false;
  bool busy = false;
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
    _listenBluetooth();
    await _initializeBluetooth();
    if (autoReconnectEnabled && lastConnectedPrinterId != null) {
      await reconnectSavedPrinter();
    }
  }

  void _listenBluetooth() {
    _scanResultsSub = FlutterBluePlus.onScanResults.listen(
      (scanResults) {
        scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
        results = scanResults;
        final savedId = lastConnectedPrinterId;
        if (savedId != null && savedId.isNotEmpty) {
          for (final r in scanResults) {
            if (r.device.remoteId.str != savedId) continue;
            final discoveredName = _bestDeviceName(
              r.device,
              fallbackName: r.advertisementData.advName,
            );
            if (discoveredName != savedId && discoveredName != lastConnectedPrinterName) {
              unawaited(_saveLastPrinter(savedId, discoveredName));
            }
            break;
          }
        }
        notifyListeners();
      },
      onError: (Object e) => _setStatus('Scan error: $e'),
    );

    _isScanningSub = FlutterBluePlus.isScanning.listen((value) {
      isScanning = value;
      notifyListeners();
    });

    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      adapterState = state;
      notifyListeners();
    });
  }

  Future<void> _initializeBluetooth() async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        _setStatus('This device does not support BLE.');
        return;
      }

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }
      _setStatus('Bluetooth ready.');
    } catch (e) {
      _setStatus('Bluetooth init failed: $e');
    }
  }

  Future<void> startScan() async {
    try {
      if (adapterState != BluetoothAdapterState.on) {
        _setError(const BluetoothOffException());
        return;
      }
      results = [];
      clearError(notify: false);
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startSearching,
      );
      _emitStateChange();
      _setStatus('Scanning for BLE printers...');
    } catch (e) {
      _setError(_mapScanError(e));
    }
  }

  void setScanTimeout(Duration value) {
    if (value.inMilliseconds <= 0) return;
    scanTimeout = value;
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.stopSearching,
      );
      _emitStateChange();
      _setStatus('Scan stopped.');
    } catch (e) {
      _setStatus('Stop scan failed: $e');
    }
  }

  Future<void> connect(ScanResult result) async {
    if (busy) return;
    busy = true;
    notifyListeners();

    try {
      await stopScan();
      await connectedDevice?.disconnect();
      await _connectionSub?.cancel();

      final device = result.device;
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startConnecting,
        deviceId: device.remoteId.str,
        deviceName: displayName(device),
      );
      _emitStateChange();
      _setStatus('Connecting to ${displayName(device)}...');
      await _connectWithRetry(
        device,
        timeout: const Duration(seconds: 20),
      );

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeCharacteristic = null;
          connectionState = PrinterConnectionMachine.transition(
            connectionState,
            PrinterConnectionEvent.disconnected,
            message: 'Disconnected',
          );
          _emitStateChange();
          _setStatus('Device disconnected.');
        }
      });
      device.cancelWhenDisconnected(_connectionSub!, delayed: true);

      final services = await device.discoverServices();
      final writable = _findWritableCharacteristic(services);

      connectedDevice = device;
      writeCharacteristic = writable;
      if (writable == null) {
        _setError(const NoWritableCharacteristicException());
      } else {
        final name = _bestDeviceName(device, fallbackName: result.advertisementData.advName);
        connectionState = PrinterConnectionMachine.transition(
          connectionState,
          PrinterConnectionEvent.connected,
          deviceId: device.remoteId.str,
          deviceName: name,
          message: 'Connected',
        );
        _emitStateChange();
        await _saveLastPrinter(device.remoteId.str, name);
        _setStatus('Connected. Ready to print.');
      }
    } catch (e) {
      _setError(_mapConnectError(e));
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await connectedDevice?.disconnect();
      await _connectionSub?.cancel();
      connectedDevice = null;
      writeCharacteristic = null;
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.disconnected,
        message: 'Disconnected',
      );
      _emitStateChange();
      _setStatus('Disconnected.');
    } catch (e) {
      _setStatus('Disconnect failed: $e');
    }
  }

  Future<bool> reconnectSavedPrinter() async {
    final savedId = lastConnectedPrinterId;
    if (savedId == null || savedId.isEmpty) return false;
    if (busy) return false;

    busy = true;
    notifyListeners();
    try {
      await stopScan();
      await connectedDevice?.disconnect();
      await _connectionSub?.cancel();

      // Try to reuse any system-connected device first (Android ignores withServices).
      BluetoothDevice? device;
      try {
        final system = await FlutterBluePlus.systemDevices(const []);
        for (final d in system) {
          if (d.remoteId.str == savedId) {
            device = d;
            break;
          }
        }
      } catch (_) {
        // If system query fails, fallback to reconstructing from saved remoteId.
      }
      device ??= BluetoothDevice.fromId(savedId);

      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startConnecting,
        deviceId: savedId,
      );
      _emitStateChange();
      _setStatus('Reconnecting saved printer...');

      // First try a direct connect (faster restore when link is already up).
      try {
        await _connectWithRetry(
          device,
          timeout: const Duration(seconds: 8),
          autoConnect: false,
        );
      } catch (_) {
        // Fallback to autoConnect for slower background restoration.
        await _connectWithRetry(
          device,
          timeout: const Duration(seconds: 12),
          autoConnect: true,
        );
        await device.connectionState
            .where((v) => v == BluetoothConnectionState.connected)
            .first
            .timeout(const Duration(seconds: 15));
      }

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeCharacteristic = null;
          connectionState = PrinterConnectionMachine.transition(
            connectionState,
            PrinterConnectionEvent.disconnected,
            message: 'Disconnected',
          );
          _emitStateChange();
          _setStatus('Device disconnected.');
        }
      });
      device.cancelWhenDisconnected(_connectionSub!, delayed: true);

      final services = await device.discoverServices();
      final writable = _findWritableCharacteristic(services);
      if (writable == null) {
        _setError(const NoWritableCharacteristicException());
        return false;
      }

      connectedDevice = device;
      writeCharacteristic = writable;
      final name = _bestDeviceName(device, fallbackName: lastConnectedPrinterName);
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.connected,
        deviceId: device.remoteId.str,
        deviceName: name,
        message: 'Connected',
      );
      _emitStateChange();
      await _saveLastPrinter(device.remoteId.str, name);
      _setStatus('Restored saved printer connection.');
      return true;
    } catch (_) {
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.failed,
        message: 'Reconnect failed',
      );
      _emitStateChange();
      _setStatus('Saved printer not available. Connect manually.');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
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
    // Demo test image to validate image-only thermal printing flow.
    final demo = img.Image(width: 384, height: 220);
    img.fill(demo, color: img.ColorRgb8(255, 255, 255));
    img.drawRect(demo, x1: 8, y1: 8, x2: 376, y2: 212, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    img.drawRect(demo, x1: 16, y1: 16, x2: 368, y2: 64, color: img.ColorRgb8(0, 0, 0), thickness: 2);
    img.drawLine(demo, x1: 16, y1: 92, x2: 368, y2: 92, color: img.ColorRgb8(0, 0, 0), thickness: 1);
    img.drawLine(demo, x1: 16, y1: 128, x2: 368, y2: 128, color: img.ColorRgb8(0, 0, 0), thickness: 1);
    img.drawLine(demo, x1: 16, y1: 164, x2: 368, y2: 164, color: img.ColorRgb8(0, 0, 0), thickness: 1);
    final pngBytes = Uint8List.fromList(img.encodePng(demo));
    return printImage(pngBytes);
  }

  Future<bool> printImage(
    Uint8List imageBytes, {
    PrinterPrintConfig config = const PrinterPrintConfig(),
  }) async {
    final characteristic = writeCharacteristic;
    final device = connectedDevice;
    if (characteristic == null || device == null) {
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
      final raster = _rasterEncoder.encode(
        imageBytes,
        config: config,
      );
      final jobBytes = _buildPrintJobBytes(raster, config);

      final copyCount = config.copies < 1 ? 1 : config.copies;
      for (var i = 0; i < copyCount; i++) {
        await _writeInChunks(
          characteristic,
          jobBytes,
          device.mtuNow,
          config: config,
        );
        _emitPrintProgress(
          PrinterPrintProgress(
            stage: PrinterPrintProgressStage.copySent,
            currentCopy: i + 1,
            totalCopies: copyCount,
          ),
        );
      }
      _setStatus('Image print sent (${jobBytes.length} bytes x $copyCount).');
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

  List<int> _buildPrintJobBytes(List<int> raster, PrinterPrintConfig config) {
    final bytes = <int>[
      0x1B, 0x40, // init
      ...raster,
    ];

    final feed = config.feedLinesAfterPrint.clamp(0, 255).toInt();
    if (feed > 0) {
      bytes.addAll([0x1B, 0x64, feed]); // print and feed n lines
    }

    if (config.allowCutCommands) {
      switch (config.cutMode) {
        case PrinterCutMode.none:
          break;
        case PrinterCutMode.full:
          bytes.addAll([0x1D, 0x56, 0x00]); // full cut
          break;
        case PrinterCutMode.partial:
          bytes.addAll([0x1D, 0x56, 0x01]); // partial cut
          break;
      }
    }
    return bytes;
  }

  BluetoothCharacteristic? _findWritableCharacteristic(
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      for (final c in service.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

  Future<void> _writeInChunks(
    BluetoothCharacteristic characteristic,
    List<int> data,
    int mtu,
    {required PrinterPrintConfig config}
  ) async {
    final safeMtuPayload = max(20, mtu - 3);
    final safeMaxChunk = config.maxChunkSize.clamp(20, 512);
    final chunkSize = min(safeMtuPayload, safeMaxChunk);
    final delayMs = config.chunkDelayMs.clamp(0, 300);
    final canWriteWithoutResponse = characteristic.properties.writeWithoutResponse;
    final withoutResponse = config.preferWriteWithoutResponse
        ? canWriteWithoutResponse
        : (canWriteWithoutResponse && !characteristic.properties.write);

    for (var i = 0; i < data.length; i += chunkSize) {
      final end = min(i + chunkSize, data.length);
      await characteristic.write(
        data.sublist(i, end),
        withoutResponse: withoutResponse,
      );
      if (delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  bool get hasConnectedPrinter =>
      connectedDevice != null && writeCharacteristic != null;

  String displayName(BluetoothDevice device) {
    return _bestDeviceName(device);
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

  Future<void> _connectWithRetry(
    BluetoothDevice device, {
    required Duration timeout,
    bool autoConnect = false,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        await device.connect(
          license: License.free,
          timeout: timeout,
          mtu: autoConnect ? null : 512,
          autoConnect: autoConnect,
        );
        return;
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (message.contains('already connected')) {
          return;
        }
        final isGatt133 = message.contains('133') || message.contains('gatt_error');
        final shouldRetryByError = connectRetryPolicy.retryGatt133Only ? isGatt133 : true;
        final shouldRetry = attempt <= connectRetryPolicy.maxRetries && shouldRetryByError;
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(connectRetryPolicy.delayForAttempt(attempt));
      }
    }
  }

  void _setError(PrinterOperationException error) {
    lastError = error;
    status = error.message;
    connectionState = PrinterConnectionMachine.transition(
      connectionState,
      PrinterConnectionEvent.failed,
      message: error.message,
      deviceId: connectedDevice?.remoteId.str,
      deviceName: connectedDevice == null ? null : displayName(connectedDevice!),
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

  String _bestDeviceName(BluetoothDevice device, {String? fallbackName}) {
    final n1 = device.platformName.trim();
    if (n1.isNotEmpty) return n1;
    final n2 = device.advName.trim();
    if (n2.isNotEmpty) return n2;
    final n3 = (fallbackName ?? '').trim();
    if (n3.isNotEmpty) return n3;
    if (device.remoteId.str == lastConnectedPrinterId) {
      final savedName = (lastConnectedPrinterName ?? '').trim();
      if (savedName.isNotEmpty) return savedName;
    }
    return device.remoteId.str;
  }

  PrinterOperationException _mapScanError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('off') && text.contains('bluetooth')) {
      return BluetoothOffException(cause: e);
    }
    return PrinterOperationException(
      code: 'scan_failed',
      message: 'Could not start scanning.',
      cause: e,
    );
  }

  PrinterOperationException _mapConnectError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('timeout')) {
      return ConnectTimeoutException(cause: e);
    }
    if (text.contains('off') && text.contains('bluetooth')) {
      return BluetoothOffException(cause: e);
    }
    return PrinterOperationException(
      code: 'connect_failed',
      message: 'Could not connect to printer.',
      cause: e,
    );
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    _adapterSub?.cancel();
    _connectionSub?.cancel();
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
