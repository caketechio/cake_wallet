import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/update_haven_rate.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/reactions/check_connection.dart';
import 'package:cake_wallet/reactions/on_wallet_sync_status_change.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';

ReactionDisposer? _onCurrentWalletChangeReaction;
ReactionDisposer? _onCurrentWalletChangeFiatRateUpdateReaction;
//ReactionDisposer _onCurrentWalletAddressChangeReaction;

void startCurrentWalletChangeReaction(AppStore appStore,
    SettingsStore settingsStore, FiatConversionStore fiatConversionStore) {
  _onCurrentWalletChangeReaction?.reaction.dispose();
  _onCurrentWalletChangeFiatRateUpdateReaction?.reaction.dispose();
  //_onCurrentWalletAddressChangeReaction?.reaction?dispose();

  //_onCurrentWalletAddressChangeReaction = reaction((_) => appStore.wallet.walletAddresses.address,
    //(String address) async {
      //if (address == appStore.wallet.walletInfo.yatLastUsedAddress) {
      //  return;
      //}

      //try {
      //  final yatStore = getIt.get<YatStore>();
      //  await updateEmojiIdAddress(
      //    appStore.wallet.walletInfo.yatEmojiId,
      //    appStore.wallet.walletAddresses.address,
      //    yatStore.apiKey,
      //    appStore.wallet.type
      //  );
      //  appStore.wallet.walletInfo.yatLastUsedAddress = address;
      //  await appStore.wallet.walletInfo.save();
      //} catch (e) {
      //  print(e.toString());
      //}
  //});

  _onCurrentWalletChangeReaction = reaction((_) => appStore.wallet, (WalletBase<
          Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>?
      wallet) async {
    try {
      if (wallet == null) {
        return;
      }

      final node = settingsStore.getCurrentNode(wallet.type);
      startWalletSyncStatusChangeReaction(wallet, fiatConversionStore, settingsStore);
      startCheckConnectionReaction(wallet, settingsStore);
      await getIt
          .get<SharedPreferences>()
          .setString(PreferencesKey.currentWalletName, wallet.name);
      await getIt.get<SharedPreferences>().setInt(
          PreferencesKey.currentWalletType, serializeToInt(wallet.type));
      await wallet.connectToNode(node: node);

      if (wallet.type == WalletType.haven) {
        await updateHavenRate(fiatConversionStore);
      }

      if (wallet.walletInfo.address.isEmpty) {
        wallet.walletInfo.address = wallet.walletAddresses.address;

        if (wallet.walletInfo.isInBox) {
          await wallet.walletInfo.save();
        }
      }
    } catch (e) {
      print(e.toString());
    }
  });

  _onCurrentWalletChangeFiatRateUpdateReaction =
      reaction((_) => appStore.wallet, (WalletBase<Balance,
              TransactionHistoryBase<TransactionInfo>, TransactionInfo>?
          wallet) async {
    try {
      if (wallet == null || settingsStore.fiatApiMode == FiatApiMode.disabled) {
        return;
      }

      fiatConversionStore.prices[wallet.currency] = 0;
      fiatConversionStore.prices[wallet.currency] =
          await FiatConversionService.fetchPrice(
              crypto: wallet.currency,
              fiat: settingsStore.fiatCurrency,
              torOnly: settingsStore.fiatApiMode == FiatApiMode.torOnly);
    } catch (e) {
      print(e.toString());
    }
  });
}
