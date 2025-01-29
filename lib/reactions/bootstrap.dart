import 'dart:async';
import 'package:cake_wallet/reactions/fiat_rate_update.dart';
import 'package:cake_wallet/reactions/on_current_fiat_api_mode_change.dart';
import 'package:cake_wallet/reactions/on_current_node_change.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/reactions/on_authentication_state_change.dart';
import 'package:cake_wallet/reactions/on_current_fiat_change.dart';
import 'package:cake_wallet/reactions/on_current_wallet_change.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';

Future<void> bootstrap(GlobalKey<NavigatorState> navigatorKey, {bool loadWallet = true}) async {
  final appStore = getIt.get<AppStore>();
  final authenticationStore = getIt.get<AuthenticationStore>();
  final settingsStore = getIt.get<SettingsStore>();
  final fiatConversionStore = getIt.get<FiatConversionStore>();

  final currentWalletName =
      getIt.get<SharedPreferences>().getString(PreferencesKey.currentWalletName);
  if (currentWalletName != null) {
    authenticationStore.installed();
  }

  // we need to NOT automatically load the default wallet inside the background service:
  if (loadWallet) {
    startAuthenticationStateChange(authenticationStore, navigatorKey);
  }
  startCurrentWalletChangeReaction(appStore, settingsStore, fiatConversionStore);
  startCurrentFiatChangeReaction(appStore, settingsStore, fiatConversionStore);
  startCurrentFiatApiModeChangeReaction(appStore, settingsStore, fiatConversionStore);
  startOnCurrentNodeChangeReaction(appStore);
  startFiatRateUpdate(appStore, settingsStore, fiatConversionStore);
}
