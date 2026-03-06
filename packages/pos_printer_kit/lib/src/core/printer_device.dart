class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    this.rssi,
  });

  final String id;
  final String name;
  final int? rssi;
}
