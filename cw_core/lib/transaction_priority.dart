import 'package:cw_core/enumerable_item.dart';

abstract class TransactionPriority extends EnumerableItem<int> with Serializable<int> {
  const TransactionPriority({required super.title, required super.raw});

  String get unit => '';
  String getUnits(int rate) {
    if (unit.endsWith('s')) {
      // example: gas. doesn't become gass
      return unit;
    }

    return rate == 1 ? unit : '${unit}s';
  }

  TransactionPriorityLabel getLabelWithRate(int rate, int? customRate) {
    throw UnimplementedError();
  }

  String labelWithRate(int rate, int? customRate) {
    return getLabelWithRate(rate, customRate).toString();
  }

  String toString() {
    return title;
  }
}

abstract class TransactionPriorities<T extends TransactionPriority> {
  const TransactionPriorities();
  int operator [](T type);
  String labelWithRate(T type);
  Map<String, int> toJson();
  factory TransactionPriorities.fromJson(Map<String, int> json) {
    throw UnimplementedError();
  }
}

class TransactionPriorityLabel {
  final TransactionPriority priority;

  final String title;
  final String units;
  final int rateValue;

  TransactionPriorityLabel({
    required int rateValue,
    required this.priority,
    String? title,
  })  : title = title ?? priority.title,
        units = priority.getUnits(rateValue),
        rateValue = rateValue;

  String toString() {
    return '$title ($rateValue $units/byte)';
  }
}
