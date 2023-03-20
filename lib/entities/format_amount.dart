import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cw_core/wallet_type.dart';

String formatAmount(String amount) {
  if ((!amount.contains('.'))&&(!amount.contains(','))) {
    return amount + '.00';
  } else if ((amount.endsWith('.'))||(amount.endsWith(','))) {
    return amount + '00';
  }
  return amount;
}

double formatAmountToDouble({required WalletType type, required int amount}) {
  if (type == WalletType.bitcoin || type == WalletType.litecoin) {
    return bitcoin!.formatterBitcoinAmountToDouble(amount: amount);
  }

  if (type == WalletType.monero) {
    return monero!.formatterMoneroAmountToDouble(amount: amount);
  }

  return 0.0;
}