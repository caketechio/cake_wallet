import 'dart:convert';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_core/balance.dart';

class ElectrumBalance extends Balance {
  ElectrumBalance({
    required this.confirmed,
    required this.unconfirmed,
    required this.frozen,
    this.secondConfirmed = 0,
    this.secondUnconfirmed = 0,
  }) : super(
          confirmed,
          unconfirmed,
          secondAvailable: secondConfirmed,
          secondAdditional: secondUnconfirmed,
        );

  static ElectrumBalance? fromJSON(String? jsonSource) {
    if (jsonSource == null) {
      return null;
    }

    final decoded = json.decode(jsonSource) as Map;

    return ElectrumBalance(
      confirmed: decoded['confirmed'] as int? ?? 0,
      unconfirmed: decoded['unconfirmed'] as int? ?? 0,
      frozen: decoded['frozen'] as int? ?? 0,
      secondConfirmed: decoded['secondConfirmed'] as int? ?? 0,
      secondUnconfirmed: decoded['secondUnconfirmed'] as int? ?? 0,
    );
  }

  int confirmed;
  int unconfirmed;
  int frozen;
  int secondConfirmed = 0;
  int secondUnconfirmed = 0;

  @override
  String get formattedAvailableBalance =>
      BitcoinAmountUtils.bitcoinAmountToString(amount: (confirmed + unconfirmed) - frozen);

  @override
  String get formattedAdditionalBalance =>
      BitcoinAmountUtils.bitcoinAmountToString(amount: unconfirmed);

  @override
  String get formattedUnAvailableBalance {
    final frozenFormatted = BitcoinAmountUtils.bitcoinAmountToString(amount: frozen);
    return frozenFormatted == '0.0' ? '' : frozenFormatted;
  }

  @override
  String get formattedSecondAvailableBalance =>
      BitcoinAmountUtils.bitcoinAmountToString(amount: secondConfirmed);

  @override
  String get formattedSecondAdditionalBalance =>
      BitcoinAmountUtils.bitcoinAmountToString(amount: secondUnconfirmed);

  @override
  String get formattedFullAvailableBalance =>
      BitcoinAmountUtils.bitcoinAmountToString(amount: (confirmed + unconfirmed) + secondConfirmed - frozen);

  String toJSON() => json.encode({
        'confirmed': confirmed,
        'unconfirmed': unconfirmed,
        'frozen': frozen,
        'secondConfirmed': secondConfirmed,
        'secondUnconfirmed': secondUnconfirmed
      });
}
