import 'package:cw_core/transaction_priority.dart';

class EVMChainTransactionPriority extends TransactionPriority {
  final int tip;

  const EVMChainTransactionPriority({required String title, required int raw, required this.tip})
      : super(title: title, raw: raw);

  static const List<EVMChainTransactionPriority> all = [fast, medium, slow];
  static const EVMChainTransactionPriority slow =
      EVMChainTransactionPriority(title: 'slow', raw: 0, tip: 1);
  static const EVMChainTransactionPriority medium =
      EVMChainTransactionPriority(title: 'Medium', raw: 1, tip: 2);
  static const EVMChainTransactionPriority fast =
      EVMChainTransactionPriority(title: 'Fast', raw: 2, tip: 4);

  static EVMChainTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      default:
        throw Exception('Unexpected token: $raw for EVMChainTransactionPriority deserialize');
    }
  }

  @override
  String get unit => 'gas';

  @override
  String toString() {
    var label = '';

    switch (this) {
      case EVMChainTransactionPriority.slow:
        label = 'Slow';
        break;
      case EVMChainTransactionPriority.medium:
        label = 'Medium';
        break;
      case EVMChainTransactionPriority.fast:
        label = 'Fast';
        break;
      default:
        break;
    }

    return label;
  }
}
