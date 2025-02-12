class PayjoinSessionError {
  final String message;

  const PayjoinSessionError._(this.message);

  factory PayjoinSessionError.recoverable(String message) = RecoverableError;
  factory PayjoinSessionError.unrecoverable(String message) = UnrecoverableError;
}

class RecoverableError extends PayjoinSessionError {
  const RecoverableError(super.message) : super._();
}

class UnrecoverableError extends PayjoinSessionError {
  const UnrecoverableError(super.message) : super._();
}
