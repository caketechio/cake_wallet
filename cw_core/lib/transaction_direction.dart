class TransactionDirection {
  const TransactionDirection({required this.raw, required this.title, this.iconPath});

  final int raw;
  final String title;
  final String? iconPath;

  static const incoming =
      TransactionDirection(raw: 0, title: 'incoming', iconPath: 'assets/images/down_arrow.png');
  static const outgoing =
      TransactionDirection(raw: 1, title: 'outgoing', iconPath: 'assets/images/up_arrow.png');

  static TransactionDirection parseFromInt(int raw) {
    switch (raw) {
      case 0:
        return TransactionDirection.incoming;
      case 1:
        return TransactionDirection.outgoing;
      default:
        throw Exception(
            'Unexpected token: raw for TransactionDirection parseTransactionDirectionFromInt');
    }
  }

  static TransactionDirection parseFromString(String raw) {
    switch (raw) {
      case "0":
        return TransactionDirection.incoming;
      case "1":
        return TransactionDirection.outgoing;
      default:
        throw Exception(
            'Unexpected token: raw for TransactionDirection parseTransactionDirectionFromNumber');
    }
  }
}
