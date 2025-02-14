class ElectrumWorkerMethods {
  const ElectrumWorkerMethods._(this.method);
  final String method;

  static const String connectionMethod = "connection";
  static const String unknownMethod = "unknown";
  static const String txHashMethod = "txHash";
  static const String txHexMethod = "txHex";
  static const String checkTweaksMethod = "checkTweaks";
  static const String stopScanningMethod = "stopScanning";

  static const ElectrumWorkerMethods connect = ElectrumWorkerMethods._(connectionMethod);
  static const ElectrumWorkerMethods unknown = ElectrumWorkerMethods._(unknownMethod);
  static const ElectrumWorkerMethods txHash = ElectrumWorkerMethods._(txHashMethod);
  static const ElectrumWorkerMethods txHex = ElectrumWorkerMethods._(txHexMethod);
  static const ElectrumWorkerMethods checkTweaks = ElectrumWorkerMethods._(checkTweaksMethod);
  static const ElectrumWorkerMethods stopScanning = ElectrumWorkerMethods._(stopScanningMethod);

  @override
  String toString() {
    return method;
  }
}
