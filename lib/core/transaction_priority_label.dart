import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/transaction_priority.dart';

class TransactionPriorityLabelLocalized {
  TransactionPriorityLabel label;

  TransactionPriorityLabelLocalized(this.label);

  String toString() {
    late String title;

    if (label.title == 'Slow') {
      title = S.current.transaction_priority_slow;
    } else if (label.title == 'Medium') {
      title = S.current.transaction_priority_medium;
    } else if (label.title == 'Fast') {
      title = S.current.transaction_priority_fast;
    } else if (label.title == 'Custom') {
      title = S.current.transaction_priority_custom;
    } else if (label.title == 'Minimum') {
      title = S.current.transaction_priority_minimum;
    } else if (label.title == 'Economy') {
      title = S.current.transaction_priority_economy;
    } else if (label.title == 'Hour') {
      title = S.current.transaction_priority_hour;
    } else if (label.title == 'HalfHour') {
      title = S.current.transaction_priority_half_hour;
    } else if (label.title == 'Fastest') {
      title = S.current.transaction_priority_fastest;
    } else {
      title = label.title;
    }

    return TransactionPriorityLabel(
      title: title,
      rateValue: label.rateValue,
      priority: label.priority,
    ).toString();
  }
}
