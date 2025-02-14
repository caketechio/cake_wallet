import 'package:cw_core/transaction_priority.dart';

class BitcoinAPITransactionPriority extends TransactionPriority {
  const BitcoinAPITransactionPriority({required super.title, required super.raw});

  @override
  String get unit => 'sat';

  static const List<BitcoinAPITransactionPriority> all = [
    fastest,
    halfHour,
    hour,
    economy,
    minimum,
    custom
  ];

// Minimum: the lowest fee possible to be included in the mempool, confirms whenever without an estimate but could be dropped from the mempool if fees rise more.
  static const BitcoinAPITransactionPriority minimum =
      BitcoinAPITransactionPriority(title: 'Minimum', raw: 0);
// Economy: in between the minimum and the low fee rates, or 2x the minimum, gives a bigger chance of not being dropped from the mempool
  static const BitcoinAPITransactionPriority economy =
      BitcoinAPITransactionPriority(title: 'Economy', raw: 1);
  static const BitcoinAPITransactionPriority hour =
      BitcoinAPITransactionPriority(title: 'Hour', raw: 2);
  static const BitcoinAPITransactionPriority halfHour =
      BitcoinAPITransactionPriority(title: 'HalfHour', raw: 3);
  static const BitcoinAPITransactionPriority fastest =
      BitcoinAPITransactionPriority(title: 'Fastest', raw: 4);
  static const BitcoinAPITransactionPriority custom =
      BitcoinAPITransactionPriority(title: 'Custom', raw: 5);

  static BitcoinAPITransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return minimum;
      case 1:
        return economy;
      case 2:
        return hour;
      case 3:
        return halfHour;
      case 4:
        return fastest;
      case 5:
        return custom;
      default:
        throw Exception('Unexpected token: $raw for BitcoinTransactionPriority deserialize');
    }
  }

  @override
  String toString() {
    return title;
  }

  @override
  TransactionPriorityLabel getLabelWithRate(int rate, int? customRate) {
    final rateValue = this.title == custom.title ? customRate ??= 0 : rate;
    return TransactionPriorityLabel(priority: this, rateValue: rateValue);
  }
}

class BitcoinAPITransactionPriorities
    implements TransactionPriorities<BitcoinAPITransactionPriority> {
  const BitcoinAPITransactionPriorities({
    required this.minimum,
    required this.economy,
    required this.hour,
    required this.halfHour,
    required this.fastest,
    required this.custom,
  });

  final int minimum;
  final int economy;
  final int hour;
  final int halfHour;
  final int fastest;
  final int custom;

  @override
  int operator [](BitcoinAPITransactionPriority type) {
    switch (type) {
      case BitcoinAPITransactionPriority.minimum:
        return minimum;
      case BitcoinAPITransactionPriority.economy:
        return economy;
      case BitcoinAPITransactionPriority.hour:
        return hour;
      case BitcoinAPITransactionPriority.halfHour:
        return halfHour;
      case BitcoinAPITransactionPriority.fastest:
        return fastest;
      case BitcoinAPITransactionPriority.custom:
        return custom;
      default:
        throw Exception('Unexpected token: $type for TransactionPriorities operator[]');
    }
  }

  TransactionPriorityLabel getLabelWithRate(BitcoinAPITransactionPriority priorityType,
      [int? rate]) {
    late int rateValue;

    if (priorityType == BitcoinAPITransactionPriority.custom) {
      if (rate == null) {
        throw Exception('Rate must be provided for custom transaction priority');
      }
      rateValue = rate;
    } else {
      rateValue = this[priorityType];
    }

    return TransactionPriorityLabel(priority: priorityType, rateValue: rateValue);
  }

  String labelWithRate(BitcoinAPITransactionPriority priorityType, [int? rate]) {
    return getLabelWithRate(priorityType, rate).toString();
  }

  @override
  Map<String, int> toJson() {
    return {
      'minimum': minimum,
      'economy': economy,
      'hour': hour,
      'halfHour': halfHour,
      'fastest': fastest,
      'custom': custom,
    };
  }

  static BitcoinAPITransactionPriorities fromJson(Map<String, dynamic> json) {
    return BitcoinAPITransactionPriorities(
      minimum: json['minimum'] as int,
      economy: json['economy'] as int,
      hour: json['hour'] as int,
      halfHour: json['halfHour'] as int,
      fastest: json['fastest'] as int,
      custom: json['custom'] as int,
    );
  }
}

class ElectrumTransactionPriority extends TransactionPriority {
  const ElectrumTransactionPriority({required String title, required int raw})
      : super(title: title, raw: raw);

  static const List<ElectrumTransactionPriority> all = [fast, medium, slow, custom];

  static const ElectrumTransactionPriority slow =
      ElectrumTransactionPriority(title: 'Slow', raw: 0);
  static const ElectrumTransactionPriority medium =
      ElectrumTransactionPriority(title: 'Medium', raw: 1);
  static const ElectrumTransactionPriority fast =
      ElectrumTransactionPriority(title: 'Fast', raw: 2);
  static const ElectrumTransactionPriority custom =
      ElectrumTransactionPriority(title: 'Custom', raw: 3);

  static ElectrumTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      case 3:
        return custom;
      default:
        throw Exception('Unexpected token: $raw for ElectrumTransactionPriority deserialize');
    }
  }

  String get unit => throw UnimplementedError();

  @override
  String toString() {
    return title;
  }

  @override
  TransactionPriorityLabel getLabelWithRate(int rate, int? customRate) {
    final rateValue = this.title == custom.title ? customRate ??= 0 : rate;
    return TransactionPriorityLabel(priority: this, rateValue: rateValue);
  }

  static ElectrumTransactionPriority fromPriority(TransactionPriority priority) {
    if (priority.title == ElectrumTransactionPriority.slow.title) {
      return ElectrumTransactionPriority.slow;
    } else if (priority.title == ElectrumTransactionPriority.medium.title) {
      return ElectrumTransactionPriority.medium;
    } else if (priority.title == ElectrumTransactionPriority.fast.title) {
      return ElectrumTransactionPriority.fast;
    } else if (priority.title == ElectrumTransactionPriority.custom.title) {
      return ElectrumTransactionPriority.custom;
    }

    throw Exception('Unexpected token: $priority for ElectrumTransactionPriority fromPriority');
  }
}

class BitcoinElectrumTransactionPriority extends ElectrumTransactionPriority {
  const BitcoinElectrumTransactionPriority({required super.title, required super.raw});

  @override
  String get unit => 'sat';

  static const List<BitcoinElectrumTransactionPriority> all = [fast, medium, slow, custom];

  static const BitcoinElectrumTransactionPriority slow =
      BitcoinElectrumTransactionPriority(title: 'Slow', raw: 0);
  static const BitcoinElectrumTransactionPriority medium =
      BitcoinElectrumTransactionPriority(title: 'Medium', raw: 1);
  static const BitcoinElectrumTransactionPriority fast =
      BitcoinElectrumTransactionPriority(title: 'Fast', raw: 2);
  static const BitcoinElectrumTransactionPriority custom =
      BitcoinElectrumTransactionPriority(title: 'Custom', raw: 3);

  static ElectrumTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      case 3:
        return custom;
      default:
        throw Exception('Unexpected token: $raw for ElectrumTransactionPriority deserialize');
    }
  }

  static BitcoinElectrumTransactionPriority fromPriority(TransactionPriority priority) {
    switch (priority) {
      case ElectrumTransactionPriority.slow:
        return BitcoinElectrumTransactionPriority.slow;
      case ElectrumTransactionPriority.medium:
        return BitcoinElectrumTransactionPriority.medium;
      case ElectrumTransactionPriority.fast:
        return BitcoinElectrumTransactionPriority.fast;
      case ElectrumTransactionPriority.custom:
        return BitcoinElectrumTransactionPriority.custom;
      default:
        throw Exception(
            'Unexpected token: $priority for BitcoinElectrumTransactionPriority fromPriority');
    }
  }
}

class LitecoinTransactionPriority extends ElectrumTransactionPriority {
  const LitecoinTransactionPriority({required super.title, required super.raw});

  @override
  String get unit => 'lit';

  static const List<LitecoinTransactionPriority> all = [fast, medium, slow];

  static const LitecoinTransactionPriority slow =
      LitecoinTransactionPriority(title: 'Slow', raw: 0);
  static const LitecoinTransactionPriority medium =
      LitecoinTransactionPriority(title: 'Medium', raw: 1);
  static const LitecoinTransactionPriority fast =
      LitecoinTransactionPriority(title: 'Fast', raw: 2);

  static ElectrumTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      default:
        throw Exception('Unexpected token: $raw for ElectrumTransactionPriority deserialize');
    }
  }

  static LitecoinTransactionPriority fromPriority(TransactionPriority priority) {
    switch (priority) {
      case ElectrumTransactionPriority.slow:
        return LitecoinTransactionPriority.slow;
      case ElectrumTransactionPriority.medium:
        return LitecoinTransactionPriority.medium;
      case ElectrumTransactionPriority.fast:
        return LitecoinTransactionPriority.fast;
      default:
        throw Exception('Unexpected token: $priority for LitecoinTransactionPriority fromPriority');
    }
  }
}

class BitcoinCashTransactionPriority extends ElectrumTransactionPriority {
  const BitcoinCashTransactionPriority({required super.title, required super.raw});

  @override
  String get unit => 'satoshi';

  static const List<BitcoinCashTransactionPriority> all = [fast, medium, slow];

  static const BitcoinCashTransactionPriority slow =
      BitcoinCashTransactionPriority(title: 'Slow', raw: 0);
  static const BitcoinCashTransactionPriority medium =
      BitcoinCashTransactionPriority(title: 'Medium', raw: 1);
  static const BitcoinCashTransactionPriority fast =
      BitcoinCashTransactionPriority(title: 'Fast', raw: 2);

  static ElectrumTransactionPriority deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return slow;
      case 1:
        return medium;
      case 2:
        return fast;
      default:
        throw Exception('Unexpected token: $raw for ElectrumTransactionPriority deserialize');
    }
  }

  static BitcoinCashTransactionPriority fromPriority(TransactionPriority priority) {
    switch (priority) {
      case ElectrumTransactionPriority.slow:
        return BitcoinCashTransactionPriority.slow;
      case ElectrumTransactionPriority.medium:
        return BitcoinCashTransactionPriority.medium;
      case ElectrumTransactionPriority.fast:
        return BitcoinCashTransactionPriority.fast;
      default:
        throw Exception(
            'Unexpected token: $priority for BitcoinCashTransactionPriority fromPriority');
    }
  }
}

class ElectrumTransactionPriorities<T extends ElectrumTransactionPriority>
    implements TransactionPriorities<T> {
  const ElectrumTransactionPriorities({
    required this.slow,
    required this.medium,
    required this.fast,
    required this.custom,
  });

  final int slow;
  final int medium;
  final int fast;
  final int custom;

  @override
  int operator [](T type) {
    if (type.title == ElectrumTransactionPriority.slow.title) {
      return slow;
    } else if (type.title == ElectrumTransactionPriority.medium.title) {
      return medium;
    } else if (type.title == ElectrumTransactionPriority.fast.title) {
      return fast;
    } else if (type.title == ElectrumTransactionPriority.custom.title) {
      return custom;
    }

    throw Exception('Unexpected token: $type for TransactionPriorities operator[]');
  }

  TransactionPriorityLabel getLabelWithRate(T priorityType, [int? rate]) {
    final rateValue = this[priorityType];
    return TransactionPriorityLabel(priority: priorityType, rateValue: rateValue);
  }

  String labelWithRate(T priorityType, [int? rate]) {
    return getLabelWithRate(priorityType, rate).toString();
  }

  factory ElectrumTransactionPriorities.fromList(List<int> list) {
    if (list.length != 3) {
      throw Exception(
          'Unexpected list length: ${list.length} for ElectrumTransactionPriorities.fromList');
    }

    return ElectrumTransactionPriorities(
      slow: list[0],
      medium: list[1],
      fast: list[2],
      custom: 0,
    );
  }

  @override
  Map<String, int> toJson() {
    return {
      'slow': slow,
      'medium': medium,
      'fast': fast,
      'custom': custom,
    };
  }

  static ElectrumTransactionPriorities fromJson(Map<String, dynamic> json) {
    return ElectrumTransactionPriorities(
      slow: json['slow'] as int,
      medium: json['medium'] as int,
      fast: json['fast'] as int,
      custom: json['custom'] as int,
    );
  }
}

class BitcoinElectrumTransactionPriorities
    extends ElectrumTransactionPriorities<BitcoinElectrumTransactionPriority> {
  const BitcoinElectrumTransactionPriorities({
    required super.slow,
    required super.medium,
    required super.fast,
    required super.custom,
  }) : super();

  static BitcoinElectrumTransactionPriorities fromJson(Map<String, dynamic> json) {
    return BitcoinElectrumTransactionPriorities(
      slow: json['slow'] as int,
      medium: json['medium'] as int,
      fast: json['fast'] as int,
      custom: json['custom'] as int,
    );
  }
}

class LitecoinTransactionPriorities
    extends ElectrumTransactionPriorities<LitecoinTransactionPriority> {
  const LitecoinTransactionPriorities({
    required super.slow,
    required super.medium,
    required super.fast,
    required super.custom,
  }) : super();

  static LitecoinTransactionPriorities fromJson(Map<String, dynamic> json) {
    return LitecoinTransactionPriorities(
      slow: json['slow'] as int,
      medium: json['medium'] as int,
      fast: json['fast'] as int,
      custom: json['custom'] as int,
    );
  }
}

class BitcoinCashTransactionPriorities
    extends ElectrumTransactionPriorities<BitcoinCashTransactionPriority> {
  const BitcoinCashTransactionPriorities({
    required super.slow,
    required super.medium,
    required super.fast,
    required super.custom,
  }) : super();

  static BitcoinCashTransactionPriorities fromJson(Map<String, dynamic> json) {
    return BitcoinCashTransactionPriorities(
      slow: json['slow'] as int,
      medium: json['medium'] as int,
      fast: json['fast'] as int,
      custom: json['custom'] as int,
    );
  }
}

TransactionPriorities deserializeTransactionPriorities(Map<String, dynamic> json) {
  if (json.containsKey('minimum')) {
    return BitcoinAPITransactionPriorities.fromJson(json);
  } else if (json.containsKey('slow')) {
    return ElectrumTransactionPriorities.fromJson(json);
  } else {
    throw Exception('Unexpected token: $json for deserializeTransactionPriorities');
  }
}
