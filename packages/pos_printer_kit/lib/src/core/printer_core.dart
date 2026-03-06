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
import 'printer_print_config.dart';

class PrinterCore extends ChangeNotifier {
  PrinterCore({
    this.autoReconnectEnabled = true,
  });

  static const String _savedPrinterIdKey = 'pos_printer_kit.last_printer_id';
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
  String? lastConnectedPrinterId;
  PrinterConnectionState connectionState = const PrinterConnectionState(
    stage: PrinterConnectionStage.idle,
    message: 'Ready',
  );

  Future<void> initialize() async {
    await _loadSavedPrinterId();
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
      _setStatus('Connecting to ${displayName(device)}...');
      await _connectWithRetry(
        device,
        timeout: const Duration(seconds: 20),
        retries: 2,
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
        connectionState = PrinterConnectionMachine.transition(
          connectionState,
          PrinterConnectionEvent.connected,
          deviceId: device.remoteId.str,
          deviceName: displayName(device),
          message: 'Connected',
        );
        await _saveLastPrinterId(device.remoteId.str);
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

      final device = BluetoothDevice.fromId(savedId);
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.startConnecting,
        deviceId: savedId,
      );
      _setStatus('Reconnecting saved printer...');
      await _connectWithRetry(
        device,
        timeout: const Duration(seconds: 12),
        retries: 2,
        autoConnect: true,
      );
      await device.connectionState
          .where((v) => v == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 15));

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeCharacteristic = null;
          connectionState = PrinterConnectionMachine.transition(
            connectionState,
            PrinterConnectionEvent.disconnected,
            message: 'Disconnected',
          );
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
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.connected,
        deviceId: device.remoteId.str,
        deviceName: displayName(device),
        message: 'Connected',
      );
      await _saveLastPrinterId(device.remoteId.str);
      _setStatus('Reconnected to saved printer.');
      return true;
    } catch (_) {
      connectionState = PrinterConnectionMachine.transition(
        connectionState,
        PrinterConnectionEvent.failed,
        message: 'Reconnect failed',
      );
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
    lastConnectedPrinterId = null;
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

    try {
      clearError(notify: false);
      final raster = _rasterEncoder.encode(
        imageBytes,
        config: config,
      );
      final jobBytes = _buildPrintJobBytes(raster, config);

      final copyCount = config.copies < 1 ? 1 : config.copies;
      for (var i = 0; i < copyCount; i++) {
        await _writeInChunks(characteristic, jobBytes, device.mtuNow);
      }
      _setStatus('Image print sent (${jobBytes.length} bytes x $copyCount).');
      return true;
    } catch (e) {
      _setError(
        PrinterOperationException(
          code: 'print_failed',
          message: 'Image print failed.',
          cause: e,
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
  ) async {
    final chunkSize = max(20, min(180, mtu - 3));
    final withoutResponse =
        characteristic.properties.writeWithoutResponse &&
            !characteristic.properties.write;

    for (var i = 0; i < data.length; i += chunkSize) {
      final end = min(i + chunkSize, data.length);
      await characteristic.write(
        data.sublist(i, end),
        withoutResponse: withoutResponse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  bool get hasConnectedPrinter =>
      connectedDevice != null && writeCharacteristic != null;

  String displayName(BluetoothDevice device) {
    final n1 = device.platformName.trim();
    if (n1.isNotEmpty) return n1;
    final n2 = device.advName.trim();
    if (n2.isNotEmpty) return n2;
    return device.remoteId.str;
  }

  Color bluetoothStatusColor(ThemeData theme) {
    if (hasConnectedPrinter) return Colors.green;
    if (busy || isScanning) return Colors.amber.shade700;
    return theme.colorScheme.outline;
  }

  void _setStatus(String message) {
    status = message;
    lastError = null;
    notifyListeners();
  }

  Future<void> _connectWithRetry(
    BluetoothDevice device, {
    required Duration timeout,
    int retries = 2,
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
        final isGatt133 = message.contains('133') || message.contains('gatt_error');
        final shouldRetry = attempt <= retries && isGatt133;
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
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
    notifyListeners();
  }

  void clearError({bool notify = true}) {
    lastError = null;
    if (notify) notifyListeners();
  }

  Future<void> _saveLastPrinterId(String id) async {
    lastConnectedPrinterId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPrinterIdKey, id);
  }

  Future<void> _loadSavedPrinterId() async {
    final prefs = await SharedPreferences.getInstance();
    lastConnectedPrinterId = prefs.getString(_savedPrinterIdKey);
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
    super.dispose();
  }
}
