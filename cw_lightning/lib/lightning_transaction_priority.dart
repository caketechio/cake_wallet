import 'package:cw_core/transaction_priority.dart';

class LightningTransactionPriority extends TransactionPriority {
  const LightningTransactionPriority({required String title, required int raw})
      : super(title: title, raw: raw);

  static const List<LightningTransactionPriority> all = [minimum, economy, fastest, halfhour, hour, custom];
  static const LightningTransactionPriority minimum =
      LightningTransactionPriority(title: 'Minimum', raw: 0);
  static const LightningTransactionPriority economy =
      LightningTransactionPriority(title: 'Economy', raw: 1);
  static const LightningTransactionPriority fastest =
      LightningTransactionPriority(title: 'Fastest', raw: 2);
  static const LightningTransactionPriority halfhour =
      LightningTransactionPriority(title: 'Half Hour', raw: 3);
  static const LightningTransactionPriority hour =
      LightningTransactionPriority(title: 'Hour', raw: 4);
  static const LightningTransactionPriority custom =
      LightningTransactionPriority(title: 'Custom', raw: 5);

  static LightningTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return minimum;
      case 1:
        return economy;
      case 2:
        return fastest;
      case 3:
        return halfhour;
      case 4:
        return hour;
      case 5:
        return custom;
      default:
        throw Exception('Unexpected token: $raw for LightningTransactionPriority deserialize');
    }
  }

  String get units => 'sat';

  @override
  String toString() {
    var label = '';

    switch (this) {
      case LightningTransactionPriority.minimum:
        label = 'Minimum ~24hrs+';
        break;
      case LightningTransactionPriority.economy:
        label = 'Economy';
        break;
      case LightningTransactionPriority.fastest:
        label = 'Fastest';
        break;
      case LightningTransactionPriority.halfhour:
        label = 'Half Hour';
        break;
      case LightningTransactionPriority.hour:
        label = 'Hour';
        break;
      case LightningTransactionPriority.custom:
        label = 'Custom';
        break;
      default:
        break;
    }

    return label;
  }

  String labelWithRate(int rate, int? customRate) {
    final rateValue = this == custom ? customRate ??= 0 : rate;
    return '${toString()} ($rateValue ${units}/byte)';
  }
}
