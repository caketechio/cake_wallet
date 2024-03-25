import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';

ReactionDisposer? _onCurrentFiatCurrencyChangeDisposer;

void startCurrentFiatChangeReaction(
    AppStore appStore, SettingsStore settingsStore, FiatConversionStore fiatConversionStore) {
  _onCurrentFiatCurrencyChangeDisposer?.reaction.dispose();
  _onCurrentFiatCurrencyChangeDisposer =
      reaction((_) => settingsStore.fiatCurrency, (FiatCurrency fiatCurrency) async {
    if (appStore.wallet == null || settingsStore.fiatApiMode == FiatApiMode.disabled) {
      return;
    }

    final cryptoCurrency = appStore.wallet!.currency;
    fiatConversionStore.prices[cryptoCurrency] = await FiatConversionService.fetchPrice(
      crypto: cryptoCurrency,
      fiat: fiatCurrency,
    );
  });
}
