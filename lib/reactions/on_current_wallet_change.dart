import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/update_haven_rate.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cake_wallet/utils/tor.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:mobx/mobx.dart';
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

void startCurrentWalletChangeReaction(
    AppStore appStore, SettingsStore settingsStore, FiatConversionStore fiatConversionStore) {
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
  //  printV(e.toString());
  //}
  //});

  _onCurrentWalletChangeReaction = reaction((_) => appStore.wallet,
      (WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>?
          wallet) async {
    try {
      if (wallet == null) {
        return;
      }

      final node = settingsStore.getCurrentNode(wallet.type);

      startWalletSyncStatusChangeReaction(wallet, fiatConversionStore);
      startCheckConnectionReaction(wallet, settingsStore);

      await Future.delayed(Duration.zero);

      if (wallet.type == WalletType.monero ||
          wallet.type == WalletType.wownero ||
          wallet.type == WalletType.bitcoin ||
          wallet.type == WalletType.litecoin ||
          wallet.type == WalletType.bitcoinCash) {
        _setAutoGenerateSubaddressStatus(wallet, settingsStore);
      }

      if (settingsStore.builtinTor) {
        await ensureTorStarted(context: null);
      }
      
      await wallet.connectToNode(node: node);
      if (wallet.type == WalletType.nano || wallet.type == WalletType.banano) {
        final powNode = settingsStore.getCurrentPowNode(wallet.type);
        await wallet.connectToPowNode(node: powNode);
      }

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
      printV(e.toString());
    }
  });

  _onCurrentWalletChangeFiatRateUpdateReaction = reaction((_) => appStore.wallet,
      (WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>?
          wallet) async {
    try {
      if (wallet == null || settingsStore.fiatApiMode == FiatApiMode.disabled) {
        return;
      }

      fiatConversionStore.prices[wallet.currency] = 0;
      fiatConversionStore.prices[wallet.currency] = await FiatConversionService.fetchPrice(
          crypto: wallet.currency,
          fiat: settingsStore.fiatCurrency,
          torOnly: settingsStore.fiatApiMode == FiatApiMode.torOnly);

      Iterable<CryptoCurrency>? currencies;
      if (wallet.type == WalletType.ethereum) {
        currencies =
            ethereum!.getERC20Currencies(appStore.wallet!).where((element) => element.enabled);
      }
      if (wallet.type == WalletType.polygon) {
        currencies =
            polygon!.getERC20Currencies(appStore.wallet!).where((element) => element.enabled);
      }
      if (wallet.type == WalletType.solana) {
        currencies =
            solana!.getSPLTokenCurrencies(appStore.wallet!).where((element) => element.enabled);
      }
      if (wallet.type == WalletType.tron) {
        currencies =
            tron!.getTronTokenCurrencies(appStore.wallet!).where((element) => element.enabled);
      }

      if (currencies != null) {
        for (final currency in currencies) {
          () async {
            fiatConversionStore.prices[currency] = await FiatConversionService.fetchPrice(
                crypto: currency,
                fiat: settingsStore.fiatCurrency,
                torOnly: settingsStore.fiatApiMode == FiatApiMode.torOnly);
          }.call();
        }
      }
    } catch (e) {
      printV(e.toString());
    }
  });
}

void _setAutoGenerateSubaddressStatus(
  WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet,
  SettingsStore settingsStore,
) async {
  wallet.isEnabledAutoGenerateSubaddress =
      settingsStore.autoGenerateSubaddressStatus == AutoGenerateSubaddressStatus.enabled ||
          settingsStore.autoGenerateSubaddressStatus == AutoGenerateSubaddressStatus.initialized;
}
