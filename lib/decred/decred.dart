import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/unspent_transaction_output.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:hive/hive.dart';

import 'package:cw_decred/transaction_priority.dart';
import 'package:cw_decred/wallet.dart';
import 'package:cw_decred/wallet_service.dart';
import 'package:cw_decred/wallet_creation_credentials.dart';
import 'package:cw_decred/amount_format.dart';
import 'package:cw_decred/transaction_credentials.dart';
import 'package:cw_decred/mnemonic.dart';

part 'cw_decred.dart';

Decred? decred = CWDecred();


abstract class Decred {
  WalletCredentials createDecredNewWalletCredentials(
      {required String name, WalletInfo? walletInfo});
  WalletCredentials createDecredRestoreWalletFromSeedCredentials(
      {required String name,
      required String mnemonic,
      required String password});
  WalletCredentials createDecredRestoreWalletFromPubkeyCredentials(
      {required String name,
      required String pubkey,
      required String password});
  WalletService createDecredWalletService(Box<WalletInfo> walletInfoSource,
      Box<UnspentCoinsInfo> unspentCoinSource);

  List<TransactionPriority> getTransactionPriorities();
  TransactionPriority getMediumTransactionPriority();
  TransactionPriority getDecredTransactionPriorityMedium();
  TransactionPriority getDecredTransactionPrioritySlow();
  TransactionPriority deserializeDecredTransactionPriority(int raw);

  int getFeeRate(Object wallet, TransactionPriority priority);
  Object createDecredTransactionCredentials(
      List<Output> outputs, TransactionPriority priority);

  List<String> getAddresses(Object wallet);
  String getAddress(Object wallet);
  Future<void> generateNewAddress(Object wallet);

  String formatterDecredAmountToString({required int amount});
  double formatterDecredAmountToDouble({required int amount});
  int formatterStringDoubleToDecredAmount(String amount);

  List<Unspent> getUnspents(Object wallet);
  void updateUnspents(Object wallet);

  int heightByDate(DateTime date);

  List<String> getDecredWordList();

  String pubkey(Object wallet);
}
