class ZanoWalletException implements Exception {
  final String message;

  ZanoWalletException(this.message);
  @override
  String toString() => '${this.runtimeType} (message: $message)';
}

class RestoreFromSeedsException extends ZanoWalletException {
  RestoreFromSeedsException(String message) : super(message);
}

class TransferException extends ZanoWalletException {
  TransferException(String message): super(message);
}

class ZanoWalletBusyException extends ZanoWalletException {
  ZanoWalletBusyException(): super('');
}