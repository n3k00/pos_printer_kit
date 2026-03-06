import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image/image.dart' as img;

class PrinterCore extends ChangeNotifier {
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

  Future<void> initialize() async {
    _listenBluetooth();
    await _initializeBluetooth();
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
        _setStatus('Bluetooth is OFF. Please turn on Bluetooth first.');
        return;
      }
      results = [];
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidUsesFineLocation: false,
        androidCheckLocationServices: false,
      );
      _setStatus('Scanning for BLE printers...');
    } catch (e) {
      _setStatus('Start scan failed: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
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
      _setStatus('Connecting to ${displayName(device)}...');
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 20),
      );

      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          connectedDevice = null;
          writeCharacteristic = null;
          _setStatus('Device disconnected.');
        }
      });
      device.cancelWhenDisconnected(_connectionSub!, delayed: true);

      final services = await device.discoverServices();
      final writable = _findWritableCharacteristic(services);

      connectedDevice = device;
      writeCharacteristic = writable;
      if (writable == null) {
        _setStatus('Connected, but no writable characteristic found.');
      } else {
        _setStatus('Connected. Ready to print.');
      }
    } catch (e) {
      _setStatus('Connect failed: $e');
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
      _setStatus('Disconnected.');
    } catch (e) {
      _setStatus('Disconnect failed: $e');
    }
  }

  Future<bool> testPrint() async {
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
    int copies = 1,
    int targetWidth = 384,
    int threshold = 160,
  }) async {
    final characteristic = writeCharacteristic;
    final device = connectedDevice;
    if (characteristic == null || device == null) {
      _setStatus('Connect printer first.');
      return false;
    }

    if (busy) return false;
    busy = true;
    notifyListeners();

    try {
      final raster = _buildEscPosRaster(
        imageBytes,
        targetWidth: targetWidth,
        threshold: threshold,
      );
      final jobBytes = <int>[
        0x1B, 0x40, // init
        ...raster,
        0x0A,
        0x0A,
      ];

      final copyCount = copies < 1 ? 1 : copies;
      for (var i = 0; i < copyCount; i++) {
        await _writeInChunks(characteristic, jobBytes, device.mtuNow);
      }
      _setStatus('Image print sent (${jobBytes.length} bytes x $copyCount).');
      return true;
    } catch (e) {
      _setStatus('Print failed: $e');
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  List<int> _buildEscPosRaster(
    Uint8List imageBytes, {
    required int targetWidth,
    required int threshold,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Invalid image bytes');
    }

    final safeTarget = targetWidth <= 0 ? 384 : targetWidth;
    img.Image converted = decoded;
    if (decoded.width > safeTarget) {
      converted = img.copyResize(decoded, width: safeTarget);
    }
    converted = img.grayscale(converted);

    final width = converted.width;
    final height = converted.height;
    final widthBytes = (width + 7) ~/ 8;
    final data = Uint8List(widthBytes * height);

    var offset = 0;
    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = (xByte * 8) + bit;
          if (x >= width) continue;
          final p = converted.getPixel(x, y);
          final isBlack = p.r.toInt() < threshold;
          if (isBlack) {
            byte |= (0x80 >> bit);
          }
        }
        data[offset++] = byte;
      }
    }

    return <int>[
      0x1D,
      0x76,
      0x30,
      0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
      ...data,
    ];
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
    notifyListeners();
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
