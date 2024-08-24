import 'package:cake_wallet/core/wallet_connect/web3wallet_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cake_wallet/store/wallet_list_store.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/node_list_store.dart';

part 'app_store.g.dart';

class AppStore = AppStoreBase with _$AppStore;

abstract class AppStoreBase with Store {
  AppStoreBase(
      {required this.authenticationStore,
      required this.walletList,
      required this.settingsStore,
      required this.nodeListStore});

  AuthenticationStore authenticationStore;

  @observable
  WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>? wallet;

  WalletListStore walletList;

  SettingsStore settingsStore;

  NodeListStore nodeListStore;

  @action
  Future<void> changeCurrentWallet(
      WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet) async {
    bool switchingToSameWalletType = this.wallet?.type == wallet.type;
    this.wallet?.close(switchingToSameWalletType: switchingToSameWalletType);
    this.wallet = wallet;
    this.wallet!.setExceptionHandler(ExceptionHandler.onError);

    if (isWalletConnectCompatibleChain(wallet.type)) {
      await getIt.get<Web3WalletService>().onDispose();
      getIt.get<Web3WalletService>().create();
      await getIt.get<Web3WalletService>().init();
    }
  }
}
