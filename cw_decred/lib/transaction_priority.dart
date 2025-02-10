import 'package:cw_core/transaction_priority.dart';

class DecredTransactionPriority extends TransactionPriority {
  const DecredTransactionPriority({required String title, required int raw})
      : super(title: title, raw: raw);

  static const List<DecredTransactionPriority> all = [fast, medium, slow];
  static const DecredTransactionPriority slow = DecredTransactionPriority(title: 'Slow', raw: 0);
  static const DecredTransactionPriority medium =
      DecredTransactionPriority(title: 'Medium', raw: 1);
  static const DecredTransactionPriority fast = DecredTransactionPriority(title: 'Fast', raw: 2);

  static DecredTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      default:
        throw Exception('Unexpected token: $raw for DecredTransactionPriority deserialize');
    }
  }

  String get units => 'atom';

  @override
  String toString() {
    var label = '';

    switch (this) {
      case DecredTransactionPriority.slow:
        label = 'Slow ~24hrs'; // '${S.current.transaction_priority_slow} ~24hrs';
        break;
      case DecredTransactionPriority.medium:
        label = 'Medium'; // S.current.transaction_priority_medium;
        break;
      case DecredTransactionPriority.fast:
        label = 'Fast'; // S.current.transaction_priority_fast;
        break;
      default:
        break;
    }

    return label;
  }

  String labelWithRate(int rate) => '${toString()} ($rate ${units}/byte)';
}

class FeeCache {
  int _feeRate;
  DateTime stamp;
  FeeCache(this._feeRate) : this.stamp = DateTime(0, 0, 0, 0, 0, 0, 0, 0);

  bool isOld() {
    return this.stamp.add(const Duration(minutes: 30)).isBefore(DateTime.now());
  }

  void update(int feeRate) {
    this._feeRate = feeRate;
    this.stamp = DateTime.now();
  }

  int feeRate() {
    return this._feeRate;
  }
}
