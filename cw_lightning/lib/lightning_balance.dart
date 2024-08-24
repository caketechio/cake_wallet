import 'dart:convert';
import 'package:cw_bitcoin/bitcoin_amount_format.dart';
import 'package:cw_bitcoin/electrum_balance.dart';

class LightningBalance extends ElectrumBalance {
  LightningBalance({required this.confirmed, required this.unconfirmed, required this.frozen})
      : super(
          confirmed: confirmed,
          unconfirmed: unconfirmed,
          frozen: frozen,
        );

  static LightningBalance? fromJSON(String? jsonSource) {
    if (jsonSource == null) {
      return null;
    }

    final decoded = json.decode(jsonSource) as Map;

    return LightningBalance(
      confirmed: decoded['confirmed'] as int? ?? 0,
      unconfirmed: decoded['unconfirmed'] as int? ?? 0,
      frozen: decoded['frozen'] as int? ?? 0,
    );
  }

  final int confirmed;
  final int unconfirmed;
  final int frozen;

  @override
  String get formattedAvailableBalance => bitcoinAmountToLightningString(amount: confirmed);

  @override
  String get formattedAdditionalBalance => bitcoinAmountToLightningString(amount: unconfirmed);

  @override
  String get formattedUnAvailableBalance {
    final frozenFormatted = bitcoinAmountToLightningString(amount: frozen);
    return frozenFormatted == '0.0' ? '' : frozenFormatted;
  }

  String toJSON() =>
      json.encode({'confirmed': confirmed, 'unconfirmed': unconfirmed, 'frozen': frozen});
}
