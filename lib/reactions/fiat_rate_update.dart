import 'dart:async';
import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/update_haven_rate.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

Timer? _timer;

Future<void> startFiatRateUpdate(
    AppStore appStore, SettingsStore settingsStore, FiatConversionStore fiatConversionStore) async {
  if (_timer != null) {
    return;
  }

  final _updateFiat = (_) async {
    try {
      if (appStore.wallet == null || settingsStore.fiatApiMode == FiatApiMode.disabled) {
        return;
      }

      if (appStore.wallet!.type == WalletType.haven) {
        await updateHavenRate(fiatConversionStore);
        return;
      }

      Iterable<CryptoCurrency>? currencies = [];
      switch (appStore.wallet!.type) {
        case WalletType.ethereum:
          currencies =
              ethereum!.getERC20Currencies(appStore.wallet!).where((element) => element.enabled);
          break;
        case WalletType.polygon:
          currencies =
              polygon!.getERC20Currencies(appStore.wallet!).where((element) => element.enabled);
          break;
        case WalletType.solana:
          currencies =
              solana!.getSPLTokenCurrencies(appStore.wallet!).where((element) => element.enabled);
          break;
        case WalletType.tron:
          currencies =
              tron!.getTronTokenCurrencies(appStore.wallet!).where((element) => element.enabled);
          break;
        case WalletType.lightning:
          currencies = [CryptoCurrency.btc];
          break;
        default:
          currencies = [appStore.wallet!.currency];
          break;
      }

      for (final currency in currencies) {
        () async {
          fiatConversionStore.prices[currency] = await FiatConversionService.fetchPrice(
            crypto: currency,
            fiat: settingsStore.fiatCurrency,
            torOnly: settingsStore.fiatApiMode == FiatApiMode.torOnly,
          );
        }.call();
      }

      // keep btcln price in sync with btc (since the fiat api only returns btc and not btcln)
      // (btcln price is just the btc price divided by 100000000)
      fiatConversionStore.prices[CryptoCurrency.btcln] =
          (fiatConversionStore.prices[CryptoCurrency.btc] ?? 0) / 100000000;
    } catch (e) {
      print(e);
    }
  };

  _timer = Timer.periodic(Duration(seconds: 30), _updateFiat);
  // also run immediately:
  _updateFiat(null);

  // setup autorun to listen to changes in fiatApiMode
  autorun((_) {
    // restart the timer if fiatApiMode was re-enabled
    if (settingsStore.fiatApiMode != FiatApiMode.disabled) {
      _timer = Timer.periodic(Duration(seconds: 30), _updateFiat);
      _updateFiat(null);
    } else {
      _timer?.cancel();
    }
  });
}
