class ZanoTransactionCreationException implements Exception {
  ZanoTransactionCreationException(this.message);

  final String message;

  @override
  String toString() => message;
}