class PrinterOperationException implements Exception {
  const PrinterOperationException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

class BluetoothOffException extends PrinterOperationException {
  const BluetoothOffException({super.cause})
      : super(
          code: 'bluetooth_off',
          message: 'Bluetooth is off. Please turn on Bluetooth.',
        );
}

class NoWritableCharacteristicException extends PrinterOperationException {
  const NoWritableCharacteristicException({super.cause})
      : super(
          code: 'no_writable_characteristic',
          message: 'Connected device has no writable printer characteristic.',
        );
}

class ConnectTimeoutException extends PrinterOperationException {
  const ConnectTimeoutException({super.cause})
      : super(
          code: 'connect_timeout',
          message: 'Connection timed out. Move closer and try again.',
        );
}
