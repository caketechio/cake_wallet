import 'dart:io';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/bitcoin_cash/bitcoin_cash.dart';
import 'package:cake_wallet/core/secure_storage.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/action_list_display_mode.dart';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/background_tasks.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/cake_2fa_preset_options.dart';
import 'package:cake_wallet/entities/country.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/entities/pin_code_required_duration.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/entities/provider_types.dart';
import 'package:cake_wallet/entities/secret_store_key.dart';
import 'package:cake_wallet/entities/seed_phrase_length.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/entities/sort_balance_types.dart';
import 'package:cake_wallet/entities/wallet_list_order_types.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cake_wallet/zano/zano.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cake_wallet/exchange/provider/trocador_exchange_provider.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/themes/theme_list.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/package_info.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/set_app_secure_native.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_store.g.dart';

class SettingsStore = SettingsStoreBase with _$SettingsStore;

abstract class SettingsStoreBase with Store {
  SettingsStoreBase(
      {required SecureStorage secureStorage,
      required BackgroundTasks backgroundTasks,
      required SharedPreferences sharedPreferences,
      required bool initialShouldShowMarketPlaceInDashboard,
      required bool initialShowAddressBookPopupEnabled,
      required FiatCurrency initialFiatCurrency,
      required BalanceDisplayMode initialBalanceDisplayMode,
      required bool initialSaveRecipientAddress,
      required AutoGenerateSubaddressStatus initialAutoGenerateSubaddressStatus,
      required MoneroSeedType initialMoneroSeedType,
      required BitcoinSeedType initialBitcoinSeedType,
      required NanoSeedType initialNanoSeedType,
      required bool initialAppSecure,
      required bool initialDisableTrade,
      required FilterListOrderType initialWalletListOrder,
      required FilterListOrderType initialContactListOrder,
      required bool initialDisableBulletin,
      required bool initialWalletListAscending,
      required bool initialContactListAscending,
      required FiatApiMode initialFiatMode,
      required bool initialAllowBiometricalAuthentication,
      required String initialTotpSecretKey,
      required bool initialUseTOTP2FA,
      required int initialFailedTokenTrial,
      required ExchangeApiMode initialExchangeStatus,
      required ThemeBase initialTheme,
      required int initialPinLength,
      required String initialLanguageCode,
      required SyncMode initialSyncMode,
      required bool initialSyncAll,
      required bool initialShowSyncNotification,
      required bool initialBackgroundSyncEnabled,
      required bool initialBackgroundSyncOnBattery,
      required bool initialBackgroundSyncOnData,
      // required String initialCurrentLocale,
      required this.appVersion,
      required this.deviceName,
      required Map<WalletType, Node> nodes,
      required Map<WalletType, Node> powNodes,
      required this.shouldShowYatPopup,
      required this.shouldShowRepWarning,
      required this.isBitcoinBuyEnabled,
      required this.actionlistDisplayMode,
      required this.pinTimeOutDuration,
      required this.seedPhraseLength,
      required Cake2FAPresetsOptions initialCake2FAPresetOptions,
      required bool initialShouldRequireTOTP2FAForAccessingWallet,
      required bool initialShouldRequireTOTP2FAForSendsToContact,
      required bool initialShouldRequireTOTP2FAForSendsToNonContact,
      required bool initialShouldRequireTOTP2FAForSendsToInternalWallets,
      required bool initialShouldRequireTOTP2FAForExchangesToInternalWallets,
      required bool initialShouldRequireTOTP2FAForExchangesToExternalWallets,
      required bool initialShouldRequireTOTP2FAForAddingContacts,
      required bool initialShouldRequireTOTP2FAForCreatingNewWallets,
      required bool initialShouldRequireTOTP2FAForAllSecurityAndBackupSettings,
      required this.sortBalanceBy,
      required this.pinNativeTokenAtTop,
      required this.useEtherscan,
      required this.usePolygonScan,
      required this.useTronGrid,
      required this.useMempoolFeeAPI,
      required this.defaultNanoRep,
      required this.defaultBananoRep,
      required this.lookupsTwitter,
      required this.lookupsZanoAlias,
      required this.lookupsMastodon,
      required this.lookupsYatService,
      required this.lookupsUnstoppableDomains,
      required this.lookupsOpenAlias,
      required this.lookupsENS,
      required this.lookupsWellKnown,
      required this.customBitcoinFeeRate,
      required this.silentPaymentsCardDisplay,
      required this.silentPaymentsAlwaysScan,
      required this.mwebAlwaysScan,
      required this.mwebCardDisplay,
      required this.mwebEnabled,
      required this.hasEnabledMwebBefore,
      required this.mwebNodeUri,
      TransactionPriority? initialBitcoinTransactionPriority,
      TransactionPriority? initialMoneroTransactionPriority,
      TransactionPriority? initialWowneroTransactionPriority,
      TransactionPriority? initialHavenTransactionPriority,
      TransactionPriority? initialLitecoinTransactionPriority,
      TransactionPriority? initialEthereumTransactionPriority,
      TransactionPriority? initialPolygonTransactionPriority,
      TransactionPriority? initialBitcoinCashTransactionPriority,
      TransactionPriority? initialZanoTransactionPriority,
      Country? initialCakePayCountry})
      : nodes = ObservableMap<WalletType, Node>.of(nodes),
        powNodes = ObservableMap<WalletType, Node>.of(powNodes),
        _secureStorage = secureStorage,
        _sharedPreferences = sharedPreferences,
        _backgroundTasks = backgroundTasks,
        fiatCurrency = initialFiatCurrency,
        balanceDisplayMode = initialBalanceDisplayMode,
        shouldSaveRecipientAddress = initialSaveRecipientAddress,
        autoGenerateSubaddressStatus = initialAutoGenerateSubaddressStatus,
        moneroSeedType = initialMoneroSeedType,
        bitcoinSeedType = initialBitcoinSeedType,
        nanoSeedType = initialNanoSeedType,
        fiatApiMode = initialFiatMode,
        allowBiometricalAuthentication = initialAllowBiometricalAuthentication,
        selectedCake2FAPreset = initialCake2FAPresetOptions,
        totpSecretKey = initialTotpSecretKey,
        useTOTP2FA = initialUseTOTP2FA,
        numberOfFailedTokenTrials = initialFailedTokenTrial,
        isAppSecure = initialAppSecure,
        disableTradeOption = initialDisableTrade,
        disableBulletin = initialDisableBulletin,
        walletListOrder = initialWalletListOrder,
        contactListOrder = initialContactListOrder,
        walletListAscending = initialWalletListAscending,
        contactListAscending = initialContactListAscending,
        shouldShowMarketPlaceInDashboard = initialShouldShowMarketPlaceInDashboard,
        showAddressBookPopupEnabled = initialShowAddressBookPopupEnabled,
        exchangeStatus = initialExchangeStatus,
        currentTheme = initialTheme,
        pinCodeLength = initialPinLength,
        languageCode = initialLanguageCode,
        shouldRequireTOTP2FAForAccessingWallet = initialShouldRequireTOTP2FAForAccessingWallet,
        shouldRequireTOTP2FAForSendsToContact = initialShouldRequireTOTP2FAForSendsToContact,
        shouldRequireTOTP2FAForSendsToNonContact = initialShouldRequireTOTP2FAForSendsToNonContact,
        shouldRequireTOTP2FAForSendsToInternalWallets =
            initialShouldRequireTOTP2FAForSendsToInternalWallets,
        shouldRequireTOTP2FAForExchangesToInternalWallets =
            initialShouldRequireTOTP2FAForExchangesToInternalWallets,
        shouldRequireTOTP2FAForExchangesToExternalWallets =
            initialShouldRequireTOTP2FAForExchangesToExternalWallets,
        shouldRequireTOTP2FAForAddingContacts = initialShouldRequireTOTP2FAForAddingContacts,
        shouldRequireTOTP2FAForCreatingNewWallets =
            initialShouldRequireTOTP2FAForCreatingNewWallets,
        shouldRequireTOTP2FAForAllSecurityAndBackupSettings =
            initialShouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        currentSyncMode = initialSyncMode,
        currentSyncAll = initialSyncAll,
        showSyncNotification = initialShowSyncNotification,
        backgroundSyncEnabled = initialBackgroundSyncEnabled,
        backgroundSyncOnBattery = initialBackgroundSyncOnBattery,
        backgroundSyncOnData = initialBackgroundSyncOnData,
        priority = ObservableMap<WalletType, TransactionPriority>() {
    //this.nodes = ObservableMap<WalletType, Node>.of(nodes);

    if (initialMoneroTransactionPriority != null) {
      priority[WalletType.monero] = initialMoneroTransactionPriority;
    }

    if (initialWowneroTransactionPriority != null) {
      priority[WalletType.wownero] = initialWowneroTransactionPriority;
    }

    if (initialBitcoinTransactionPriority != null) {
      priority[WalletType.bitcoin] = initialBitcoinTransactionPriority;
    }

    if (initialHavenTransactionPriority != null) {
      priority[WalletType.haven] = initialHavenTransactionPriority;
    }

    if (initialLitecoinTransactionPriority != null) {
      priority[WalletType.litecoin] = initialLitecoinTransactionPriority;
    }

    if (initialEthereumTransactionPriority != null) {
      priority[WalletType.ethereum] = initialEthereumTransactionPriority;
    }

    if (initialPolygonTransactionPriority != null) {
      priority[WalletType.polygon] = initialPolygonTransactionPriority;
    }

    if (initialBitcoinCashTransactionPriority != null) {
      priority[WalletType.bitcoinCash] = initialBitcoinCashTransactionPriority;
    }

    if (initialZanoTransactionPriority != null) {
      priority[WalletType.zano] = initialZanoTransactionPriority;
    }
    if (initialCakePayCountry != null) {
      selectedCakePayCountry = initialCakePayCountry;
    }

    initializeTrocadorProviderStates();

    reaction(
        (_) => fiatCurrency,
        (FiatCurrency fiatCurrency) => sharedPreferences.setString(
            PreferencesKey.currentFiatCurrencyKey, fiatCurrency.serialize()));

    reaction(
            (_) => selectedCakePayCountry,
            (Country? country) {
              if (country != null) {
                sharedPreferences.setString(
                    PreferencesKey.currentCakePayCountry, country.raw);
              }
            });

    reaction(
        (_) => shouldShowYatPopup,
        (bool shouldShowYatPopup) =>
            sharedPreferences.setBool(PreferencesKey.shouldShowYatPopup, shouldShowYatPopup));

    reaction((_) => shouldShowRepWarning,
        (bool val) => sharedPreferences.setBool(PreferencesKey.shouldShowRepWarning, val));

    priority.observe((change) {
      final String? key;
      switch (change.key) {
        case WalletType.monero:
        case WalletType.wownero:
          key = PreferencesKey.moneroTransactionPriority;
          break;
        case WalletType.bitcoin:
          key = PreferencesKey.bitcoinTransactionPriority;
          break;
        case WalletType.litecoin:
          key = PreferencesKey.litecoinTransactionPriority;
          break;
        case WalletType.haven:
          key = PreferencesKey.havenTransactionPriority;
          break;
        case WalletType.ethereum:
          key = PreferencesKey.ethereumTransactionPriority;
          break;
        case WalletType.bitcoinCash:
          key = PreferencesKey.bitcoinCashTransactionPriority;
          break;
        case WalletType.polygon:
          key = PreferencesKey.polygonTransactionPriority;
          break;
        case WalletType.zano:
          key = PreferencesKey.zanoTransactionPriority;
          break;
        default:
          key = null;
      }

      if (change.newValue != null && key != null) {
        sharedPreferences.setInt(key, change.newValue!.serialize());
      }
    });

    reaction(
        (_) => shouldSaveRecipientAddress,
        (bool shouldSaveRecipientAddress) => sharedPreferences.setBool(
            PreferencesKey.shouldSaveRecipientAddressKey, shouldSaveRecipientAddress));

    if (DeviceInfo.instance.isMobile) {
      setIsAppSecureNative(isAppSecure);

      reaction((_) => isAppSecure, (bool isAppSecure) {
        sharedPreferences.setBool(PreferencesKey.isAppSecureKey, isAppSecure);
        setIsAppSecureNative(isAppSecure);
      });
    }

    reaction((_) => disableTradeOption,
        (bool disableTradeOption) => sharedPreferences.setBool(PreferencesKey.disableTradeOption, disableTradeOption));
    
    reaction(
        (_) => disableBulletin,
        (bool disableBulletin) =>
            sharedPreferences.setBool(PreferencesKey.disableBulletinKey, disableBulletin));

    reaction(
        (_) => walletListOrder,
        (FilterListOrderType walletListOrder) =>
            sharedPreferences.setInt(PreferencesKey.walletListOrder, walletListOrder.index));

    reaction(
            (_) => contactListOrder,
            (FilterListOrderType contactListOrder) =>
            sharedPreferences.setInt(PreferencesKey.contactListOrder, contactListOrder.index));

    reaction(
        (_) => walletListAscending,
        (bool walletListAscending) =>
            sharedPreferences.setBool(PreferencesKey.walletListAscending, walletListAscending));

    reaction(
            (_) => contactListAscending,
            (bool contactListAscending) =>
            sharedPreferences.setBool(PreferencesKey.contactListAscending, contactListAscending));

    reaction(
        (_) => autoGenerateSubaddressStatus,
        (AutoGenerateSubaddressStatus autoGenerateSubaddressStatus) => sharedPreferences.setInt(
            PreferencesKey.autoGenerateSubaddressStatusKey, autoGenerateSubaddressStatus.value));

    reaction(
        (_) => moneroSeedType,
        (MoneroSeedType moneroSeedType) =>
            sharedPreferences.setInt(PreferencesKey.moneroSeedType, moneroSeedType.raw));

    reaction(
        (_) => bitcoinSeedType,
        (BitcoinSeedType bitcoinSeedType) =>
            sharedPreferences.setInt(PreferencesKey.bitcoinSeedType, bitcoinSeedType.raw));

    reaction(
        (_) => nanoSeedType,
        (NanoSeedType nanoSeedType) =>
            sharedPreferences.setInt(PreferencesKey.nanoSeedType, nanoSeedType.raw));

    reaction(
        (_) => fiatApiMode,
        (FiatApiMode mode) =>
            sharedPreferences.setInt(PreferencesKey.currentFiatApiModeKey, mode.serialize()));

    reaction((_) => currentTheme,
        (ThemeBase theme) => sharedPreferences.setInt(PreferencesKey.currentTheme, theme.raw));

    reaction(
        (_) => numberOfFailedTokenTrials,
        (int failedTokenTrail) =>
            sharedPreferences.setInt(PreferencesKey.failedTotpTokenTrials, failedTokenTrail));

    reaction(
        (_) => shouldShowMarketPlaceInDashboard,
        (bool value) =>
            sharedPreferences.setBool(PreferencesKey.shouldShowMarketPlaceInDashboard, value));

    reaction(
            (_) => showAddressBookPopupEnabled,
            (bool value) =>
            sharedPreferences.setBool(PreferencesKey.showAddressBookPopupEnabled, value));

    reaction((_) => pinCodeLength,
        (int pinLength) => sharedPreferences.setInt(PreferencesKey.currentPinLength, pinLength));

    reaction(
        (_) => languageCode,
        (String languageCode) =>
            sharedPreferences.setString(PreferencesKey.currentLanguageCode, languageCode));

    reaction(
        (_) => seedPhraseLength,
        (SeedPhraseLength seedPhraseWordCount) => sharedPreferences.setInt(
            PreferencesKey.currentSeedPhraseLength, seedPhraseWordCount.value));

    reaction(
        (_) => balanceDisplayMode,
        (BalanceDisplayMode mode) => sharedPreferences.setInt(
            PreferencesKey.currentBalanceDisplayModeKey, mode.serialize()));

    reaction((_) => currentSyncMode, (SyncMode syncMode) {
      sharedPreferences.setInt(PreferencesKey.syncModeKey, syncMode.type.index);
      _backgroundTasks.registerBackgroundService();
    });

    reaction((_) => currentSyncAll, (bool syncAll) {
      sharedPreferences.setBool(PreferencesKey.syncAllKey, syncAll);
      _backgroundTasks.registerBackgroundService();
    });

    reaction((_) => showSyncNotification, (bool value) {
      sharedPreferences.setBool(PreferencesKey.showSyncNotificationKey, value);
      _backgroundTasks.registerBackgroundService();
    });

    reaction((_) => backgroundSyncEnabled, (bool value) {
      sharedPreferences.setBool(PreferencesKey.backgroundSyncEnabled, value);
      _backgroundTasks.registerBackgroundService();
    });

    reaction((_) => backgroundSyncOnBattery, (bool value) {
      sharedPreferences.setBool(PreferencesKey.backgroundSyncOnBattery, value);
      _backgroundTasks.registerBackgroundService();
    });

    reaction((_) => backgroundSyncOnData, (bool value) {
      sharedPreferences.setBool(PreferencesKey.backgroundSyncOnData, value);
      _backgroundTasks.registerBackgroundService();
    });

    reaction(
        (_) => exchangeStatus,
        (ExchangeApiMode mode) =>
            sharedPreferences.setInt(PreferencesKey.exchangeStatusKey, mode.serialize()));

    reaction(
        (_) => sortBalanceBy,
        (SortBalanceBy sortBalanceBy) =>
            _sharedPreferences.setInt(PreferencesKey.sortBalanceBy, sortBalanceBy.index));

    reaction(
        (_) => pinNativeTokenAtTop,
        (bool pinNativeTokenAtTop) =>
            _sharedPreferences.setBool(PreferencesKey.pinNativeTokenAtTop, pinNativeTokenAtTop));

    reaction(
        (_) => useEtherscan,
        (bool useEtherscan) =>
            _sharedPreferences.setBool(PreferencesKey.useEtherscan, useEtherscan));

    reaction(
        (_) => usePolygonScan,
        (bool usePolygonScan) =>
            _sharedPreferences.setBool(PreferencesKey.usePolygonScan, usePolygonScan));

    reaction((_) => useTronGrid,
        (bool useTronGrid) => _sharedPreferences.setBool(PreferencesKey.useTronGrid, useTronGrid));

    reaction(
        (_) => useMempoolFeeAPI,
        (bool useMempoolFeeAPI) =>
            _sharedPreferences.setBool(PreferencesKey.useMempoolFeeAPI, useMempoolFeeAPI));

    reaction((_) => defaultNanoRep,
        (String nanoRep) => _sharedPreferences.setString(PreferencesKey.defaultNanoRep, nanoRep));

    reaction(
        (_) => defaultBananoRep,
        (String bananoRep) =>
            _sharedPreferences.setString(PreferencesKey.defaultBananoRep, bananoRep));
    reaction(
        (_) => lookupsTwitter,
        (bool looksUpTwitter) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsTwitter, looksUpTwitter));
    reaction(
        (_) => lookupsZanoAlias,
        (bool lookupsZanoAlias) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsZanoAlias, lookupsZanoAlias));

    reaction(
        (_) => lookupsMastodon,
        (bool looksUpMastodon) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsMastodon, looksUpMastodon));

    reaction(
        (_) => lookupsYatService,
        (bool looksUpYatService) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsYatService, looksUpYatService));

    reaction(
        (_) => lookupsUnstoppableDomains,
        (bool looksUpUnstoppableDomains) => _sharedPreferences.setBool(
            PreferencesKey.lookupsUnstoppableDomains, looksUpUnstoppableDomains));

    reaction(
        (_) => lookupsOpenAlias,
        (bool looksUpOpenAlias) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsOpenAlias, looksUpOpenAlias));

    reaction((_) => lookupsENS,
        (bool looksUpENS) => _sharedPreferences.setBool(PreferencesKey.lookupsENS, looksUpENS));

    reaction(
        (_) => lookupsWellKnown,
        (bool looksUpWellKnown) =>
            _sharedPreferences.setBool(PreferencesKey.lookupsWellKnown, looksUpWellKnown));

    // secure storage keys:
    reaction(
        (_) => allowBiometricalAuthentication,
        (bool biometricalAuthentication) => secureStorage.write(
            key: SecureKey.allowBiometricalAuthenticationKey,
            value: biometricalAuthentication.toString()));

    reaction(
        (_) => selectedCake2FAPreset,
        (Cake2FAPresetsOptions selectedCake2FAPreset) => secureStorage.write(
            key: SecureKey.selectedCake2FAPreset,
            value: selectedCake2FAPreset.serialize().toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForAccessingWallet,
        (bool requireTOTP2FAForAccessingWallet) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForAccessingWallet,
            value: requireTOTP2FAForAccessingWallet.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToContact,
        (bool requireTOTP2FAForSendsToContact) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForSendsToContact,
            value: requireTOTP2FAForSendsToContact.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToNonContact,
        (bool requireTOTP2FAForSendsToNonContact) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForSendsToNonContact,
            value: requireTOTP2FAForSendsToNonContact.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToInternalWallets,
        (bool requireTOTP2FAForSendsToInternalWallets) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForSendsToInternalWallets,
            value: requireTOTP2FAForSendsToInternalWallets.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForExchangesToInternalWallets,
        (bool requireTOTP2FAForExchangesToInternalWallets) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForExchangesToInternalWallets,
            value: requireTOTP2FAForExchangesToInternalWallets.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForExchangesToExternalWallets,
        (bool requireTOTP2FAForExchangesToExternalWallets) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForExchangesToExternalWallets,
            value: requireTOTP2FAForExchangesToExternalWallets.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForAddingContacts,
        (bool requireTOTP2FAForAddingContacts) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForAddingContacts,
            value: requireTOTP2FAForAddingContacts.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForCreatingNewWallets,
        (bool requireTOTP2FAForCreatingNewWallets) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForCreatingNewWallets,
            value: requireTOTP2FAForCreatingNewWallets.toString()));

    reaction(
        (_) => shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        (bool requireTOTP2FAForAllSecurityAndBackupSettings) => secureStorage.write(
            key: SecureKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
            value: requireTOTP2FAForAllSecurityAndBackupSettings.toString()));

    reaction((_) => useTOTP2FA,
        (bool use) => secureStorage.write(key: SecureKey.useTOTP2FA, value: use.toString()));

    reaction((_) => totpSecretKey,
        (String totpKey) => secureStorage.write(key: SecureKey.totpSecretKey, value: totpKey));

    reaction(
        (_) => pinTimeOutDuration,
        (PinCodeRequiredDuration pinCodeInterval) => secureStorage.write(
            key: SecureKey.pinTimeOutDuration, value: pinCodeInterval.value.toString()));

    reaction(
        (_) => customBitcoinFeeRate,
        (int customBitcoinFeeRate) =>
            _sharedPreferences.setInt(PreferencesKey.customBitcoinFeeRate, customBitcoinFeeRate));

    reaction((_) => silentPaymentsCardDisplay, (bool silentPaymentsCardDisplay) {
      _sharedPreferences.setBool(
          PreferencesKey.silentPaymentsCardDisplay, silentPaymentsCardDisplay);
    });

    reaction(
        (_) => silentPaymentsAlwaysScan,
        (bool silentPaymentsAlwaysScan) => _sharedPreferences.setBool(
            PreferencesKey.silentPaymentsAlwaysScan, silentPaymentsAlwaysScan));

    reaction(
        (_) => mwebAlwaysScan,
        (bool mwebAlwaysScan) =>
            _sharedPreferences.setBool(PreferencesKey.mwebAlwaysScan, mwebAlwaysScan));

    reaction(
        (_) => mwebCardDisplay,
        (bool mwebCardDisplay) =>
            _sharedPreferences.setBool(PreferencesKey.mwebCardDisplay, mwebCardDisplay));

    reaction((_) => mwebEnabled,
        (bool mwebEnabled) => _sharedPreferences.setBool(PreferencesKey.mwebEnabled, mwebEnabled));

    reaction(
        (_) => hasEnabledMwebBefore,
        (bool hasEnabledMwebBefore) =>
            _sharedPreferences.setBool(PreferencesKey.hasEnabledMwebBefore, hasEnabledMwebBefore));

    reaction(
        (_) => mwebNodeUri,
        (String mwebNodeUri) =>
            _sharedPreferences.setString(PreferencesKey.mwebNodeUri, mwebNodeUri));

    this.nodes.observe((change) {
      if (change.newValue != null && change.key != null) {
        _saveCurrentNode(change.newValue!, change.key!);
      }
    });

    this.powNodes.observe((change) {
      if (change.newValue != null && change.key != null) {
        _saveCurrentPowNode(change.newValue!, change.key!);
      }
    });
  }

  static const defaultPinLength = 4;
  static const defaultActionsMode = 11;
  static const defaultPinCodeTimeOutDuration = PinCodeRequiredDuration.tenMinutes;
  static const defaultAutoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.initialized;
  static final walletPasswordDirectInput = Platform.isLinux;
  static const defaultSeedPhraseLength = SeedPhraseLength.twelveWords;
  static const defaultMoneroSeedType = MoneroSeedType.defaultSeedType;
  static const defaultBitcoinSeedType = BitcoinSeedType.defaultDerivationType;
  static const defaultNanoSeedType = NanoSeedType.defaultDerivationType;

  @observable
  FiatCurrency fiatCurrency;

  @observable
  Country? selectedCakePayCountry;

  @observable
  bool shouldShowYatPopup;

  @observable
  bool shouldShowRepWarning;

  @observable
  bool shouldShowMarketPlaceInDashboard;

  @observable
  bool showAddressBookPopupEnabled;

  @observable
  ObservableList<ActionListDisplayMode> actionlistDisplayMode;

  @observable
  BalanceDisplayMode balanceDisplayMode;

  @observable
  FiatApiMode fiatApiMode;

  @observable
  bool shouldSaveRecipientAddress;

  @observable
  AutoGenerateSubaddressStatus autoGenerateSubaddressStatus;

  @observable
  MoneroSeedType moneroSeedType;

  @observable
  BitcoinSeedType bitcoinSeedType;

  @observable
  NanoSeedType nanoSeedType;

  @observable
  bool isAppSecure;

  @observable
  bool disableTradeOption;

  @observable
  FilterListOrderType contactListOrder;

  @observable
  bool disableBulletin;

  @observable
  FilterListOrderType walletListOrder;

  @observable
  bool walletListAscending;

  @observable
  bool contactListAscending;

  @observable
  bool allowBiometricalAuthentication;

  @observable
  bool shouldRequireTOTP2FAForAccessingWallet;

  @observable
  bool shouldRequireTOTP2FAForSendsToContact;

  @observable
  bool shouldRequireTOTP2FAForSendsToNonContact;

  @observable
  bool shouldRequireTOTP2FAForSendsToInternalWallets;

  @observable
  bool shouldRequireTOTP2FAForExchangesToInternalWallets;

  @observable
  bool shouldRequireTOTP2FAForExchangesToExternalWallets;

  @observable
  Cake2FAPresetsOptions selectedCake2FAPreset;

  @observable
  bool shouldRequireTOTP2FAForAddingContacts;

  @observable
  bool shouldRequireTOTP2FAForCreatingNewWallets;

  @observable
  bool shouldRequireTOTP2FAForAllSecurityAndBackupSettings;

  @observable
  bool useTOTP2FA;

  @observable
  String totpSecretKey;

  @observable
  int numberOfFailedTokenTrials;

  @observable
  ExchangeApiMode exchangeStatus;

  @observable
  ThemeBase currentTheme;

  @observable
  int pinCodeLength;

  @observable
  PinCodeRequiredDuration pinTimeOutDuration;

  @observable
  SeedPhraseLength seedPhraseLength;

  @computed
  ThemeData get theme => currentTheme.themeData;

  @observable
  String languageCode;

  @observable
  ObservableMap<WalletType, TransactionPriority> priority;

  @observable
  ObservableMap<String, bool> trocadorProviderStates = ObservableMap<String, bool>();

  @observable
  SortBalanceBy sortBalanceBy;

  @observable
  bool pinNativeTokenAtTop;

  @observable
  bool useEtherscan;

  @observable
  bool usePolygonScan;

  @observable
  bool useTronGrid;

  @observable
  bool useMempoolFeeAPI;

  @observable
  String defaultNanoRep;

  @observable
  String defaultBananoRep;

  @observable
  bool lookupsTwitter;

  @observable
  bool lookupsZanoAlias;

  @observable
  bool lookupsMastodon;

  @observable
  bool lookupsYatService;

  @observable
  bool lookupsUnstoppableDomains;

  @observable
  bool lookupsOpenAlias;

  @observable
  bool lookupsENS;

  @observable
  bool lookupsWellKnown;
  @observable
  SyncMode currentSyncMode;

  @observable
  bool currentSyncAll;

  @observable
  bool showSyncNotification;

  @observable
  bool backgroundSyncEnabled;

  @observable
  bool backgroundSyncOnBattery;

  @observable
  bool backgroundSyncOnData;

  String appVersion;

  String deviceName;

  @observable
  int customBitcoinFeeRate;

  @observable
  bool silentPaymentsCardDisplay;

  @observable
  bool silentPaymentsAlwaysScan;

  @observable
  bool mwebAlwaysScan;

  @observable
  bool mwebCardDisplay;

  @observable
  bool mwebEnabled;

  @observable
  bool hasEnabledMwebBefore;

  @observable
  String mwebNodeUri;

  final SecureStorage _secureStorage;
  final SharedPreferences _sharedPreferences;
  final BackgroundTasks _backgroundTasks;

  ObservableMap<WalletType, Node> nodes;
  ObservableMap<WalletType, Node> powNodes;

  Node getCurrentNode(WalletType walletType) {
    final node = nodes[walletType];

    if (node == null) {
      throw Exception('No node found for wallet type: ${walletType.toString()}');
    }

    return node;
  }

  Node getCurrentPowNode(WalletType walletType) {
    final node = powNodes[walletType];

    if (node == null) {
      throw Exception('No pow node found for wallet type: ${walletType.toString()}');
    }

    return node;
  }

  bool isBitcoinBuyEnabled;

  bool get shouldShowReceiveWarning =>
      _sharedPreferences.getBool(PreferencesKey.shouldShowReceiveWarning) ?? true;

  Future<void> setShouldShowReceiveWarning(bool value) async =>
      _sharedPreferences.setBool(PreferencesKey.shouldShowReceiveWarning, value);

  static Future<SettingsStore> load(
      {required Box<Node> nodeSource,
      required Box<Node> powNodeSource,
      required bool isBitcoinBuyEnabled,
      FiatCurrency initialFiatCurrency = FiatCurrency.usd,
      BalanceDisplayMode initialBalanceDisplayMode = BalanceDisplayMode.availableBalance,
      ThemeBase? initialTheme}) async {
    final sharedPreferences = await getIt.getAsync<SharedPreferences>();
    final secureStorage = await getIt.get<SecureStorage>();
    final backgroundTasks = getIt.get<BackgroundTasks>();
    final currentFiatCurrency = FiatCurrency.deserialize(
        raw: sharedPreferences.getString(PreferencesKey.currentFiatCurrencyKey)!);
    final savedCakePayCountryRaw = sharedPreferences.getString(PreferencesKey.currentCakePayCountry);
    final currentCakePayCountry = savedCakePayCountryRaw != null
        ? Country.deserialize(raw: savedCakePayCountryRaw)
        : null;

    TransactionPriority? moneroTransactionPriority = monero?.deserializeMoneroTransactionPriority(
        raw: sharedPreferences.getInt(PreferencesKey.moneroTransactionPriority)!);
    TransactionPriority? bitcoinTransactionPriority =
        bitcoin?.deserializeBitcoinTransactionPriority(
            sharedPreferences.getInt(PreferencesKey.bitcoinTransactionPriority)!);

    TransactionPriority? havenTransactionPriority;
    TransactionPriority? litecoinTransactionPriority;
    TransactionPriority? ethereumTransactionPriority;
    TransactionPriority? polygonTransactionPriority;
    TransactionPriority? bitcoinCashTransactionPriority;
    TransactionPriority? wowneroTransactionPriority;
    TransactionPriority? zanoTransactionPriority;

    if (sharedPreferences.getInt(PreferencesKey.havenTransactionPriority) != null) {
      havenTransactionPriority = monero?.deserializeMoneroTransactionPriority(
          raw: sharedPreferences.getInt(PreferencesKey.havenTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority) != null) {
      litecoinTransactionPriority = bitcoin?.deserializeLitecoinTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority) != null) {
      ethereumTransactionPriority = ethereum?.deserializeEthereumTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority) != null) {
      polygonTransactionPriority = polygon?.deserializePolygonTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority) != null) {
      bitcoinCashTransactionPriority = bitcoinCash?.deserializeBitcoinCashTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.wowneroTransactionPriority) != null) {
      wowneroTransactionPriority = wownero?.deserializeWowneroTransactionPriority(
          raw: sharedPreferences.getInt(PreferencesKey.wowneroTransactionPriority)!);
    }
    if (sharedPreferences.getInt(PreferencesKey.zanoTransactionPriority) != null) {
      zanoTransactionPriority = monero?.deserializeMoneroTransactionPriority(
          raw: sharedPreferences.getInt(PreferencesKey.zanoTransactionPriority)!);
    }

    moneroTransactionPriority ??= monero?.getDefaultTransactionPriority();
    bitcoinTransactionPriority ??= bitcoin?.getMediumTransactionPriority();
    havenTransactionPriority ??= monero?.getDefaultTransactionPriority();
    litecoinTransactionPriority ??= bitcoin?.getLitecoinTransactionPriorityMedium();
    ethereumTransactionPriority ??= ethereum?.getDefaultTransactionPriority();
    bitcoinCashTransactionPriority ??= bitcoinCash?.getDefaultTransactionPriority();
    wowneroTransactionPriority ??= wownero?.getDefaultTransactionPriority();
    polygonTransactionPriority ??= polygon?.getDefaultTransactionPriority();
    zanoTransactionPriority ??= zano?.getDefaultTransactionPriority();

    final currentBalanceDisplayMode = BalanceDisplayMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey)!);
    // FIX-ME: Check for which default value we should have here
    final shouldSaveRecipientAddress =
        sharedPreferences.getBool(PreferencesKey.shouldSaveRecipientAddressKey) ?? false;
    final isAppSecure = sharedPreferences.getBool(PreferencesKey.isAppSecureKey) ?? false;
    final disableTradeOption = sharedPreferences.getBool(PreferencesKey.disableTradeOption) ?? false;
    final disableBulletin = sharedPreferences.getBool(PreferencesKey.disableBulletinKey) ?? false;
    final walletListOrder =
        FilterListOrderType.values[sharedPreferences.getInt(PreferencesKey.walletListOrder) ?? 0];
    final contactListOrder =
    FilterListOrderType.values[sharedPreferences.getInt(PreferencesKey.contactListOrder) ?? 0];
    final walletListAscending =
        sharedPreferences.getBool(PreferencesKey.walletListAscending) ?? true;
    final contactListAscending =
        sharedPreferences.getBool(PreferencesKey.contactListAscending) ?? true;
    final currentFiatApiMode = FiatApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentFiatApiModeKey) ??
            FiatApiMode.enabled.raw);
    final tokenTrialNumber = sharedPreferences.getInt(PreferencesKey.failedTotpTokenTrials) ?? 0;
    final shouldShowMarketPlaceInDashboard =
        sharedPreferences.getBool(PreferencesKey.shouldShowMarketPlaceInDashboard) ?? true;
    final showAddressBookPopupEnabled =
        sharedPreferences.getBool(PreferencesKey.showAddressBookPopupEnabled) ?? true;
    final exchangeStatus = ExchangeApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.exchangeStatusKey) ??
            ExchangeApiMode.enabled.raw);
    final bool isNewInstall = sharedPreferences.getBool(PreferencesKey.isNewInstall) ?? true;
    final int defaultTheme;
    if (isNewInstall) {
      defaultTheme = isMoneroOnly ? ThemeList.moneroDarkTheme.raw : ThemeList.brightTheme.raw;
    } else {
      defaultTheme = ThemeType.bright.index;
    }
    final savedTheme = initialTheme ??
        ThemeList.deserialize(
            raw: sharedPreferences.getInt(PreferencesKey.currentTheme) ?? defaultTheme);
    final actionListDisplayMode = ObservableList<ActionListDisplayMode>();
    actionListDisplayMode.addAll(deserializeActionlistDisplayModes(
        sharedPreferences.getInt(PreferencesKey.displayActionListModeKey) ?? defaultActionsMode));
    var pinLength = sharedPreferences.getInt(PreferencesKey.currentPinLength);
    final sortBalanceBy =
        SortBalanceBy.values[sharedPreferences.getInt(PreferencesKey.sortBalanceBy) ?? 0];
    final pinNativeTokenAtTop =
        sharedPreferences.getBool(PreferencesKey.pinNativeTokenAtTop) ?? true;
    final seedPhraseCount = sharedPreferences.getInt(PreferencesKey.currentSeedPhraseLength);
    final seedPhraseWordCount = seedPhraseCount != null
        ? SeedPhraseLength.deserialize(raw: seedPhraseCount)
        : defaultSeedPhraseLength;
    final useEtherscan = sharedPreferences.getBool(PreferencesKey.useEtherscan) ?? true;
    final usePolygonScan = sharedPreferences.getBool(PreferencesKey.usePolygonScan) ?? true;
    final useTronGrid = sharedPreferences.getBool(PreferencesKey.useTronGrid) ?? true;
    final useMempoolFeeAPI = sharedPreferences.getBool(PreferencesKey.useMempoolFeeAPI) ?? true;
    final defaultNanoRep = sharedPreferences.getString(PreferencesKey.defaultNanoRep) ?? "";
    final defaultBananoRep = sharedPreferences.getString(PreferencesKey.defaultBananoRep) ?? "";
    final lookupsTwitter = sharedPreferences.getBool(PreferencesKey.lookupsTwitter) ?? true;
    final lookupsZanoAlias = sharedPreferences.getBool(PreferencesKey.lookupsZanoAlias) ?? true;
    final lookupsMastodon = sharedPreferences.getBool(PreferencesKey.lookupsMastodon) ?? true;
    final lookupsYatService = sharedPreferences.getBool(PreferencesKey.lookupsYatService) ?? true;
    final lookupsUnstoppableDomains =
        sharedPreferences.getBool(PreferencesKey.lookupsUnstoppableDomains) ?? true;
    final lookupsOpenAlias = sharedPreferences.getBool(PreferencesKey.lookupsOpenAlias) ?? true;
    final lookupsENS = sharedPreferences.getBool(PreferencesKey.lookupsENS) ?? true;
    final lookupsWellKnown = sharedPreferences.getBool(PreferencesKey.lookupsWellKnown) ?? true;
    final customBitcoinFeeRate = sharedPreferences.getInt(PreferencesKey.customBitcoinFeeRate) ?? 1;
    final silentPaymentsCardDisplay =
        sharedPreferences.getBool(PreferencesKey.silentPaymentsCardDisplay) ?? true;
    final silentPaymentsAlwaysScan =
        sharedPreferences.getBool(PreferencesKey.silentPaymentsAlwaysScan) ?? false;
    final mwebAlwaysScan = sharedPreferences.getBool(PreferencesKey.mwebAlwaysScan) ?? false;
    final mwebCardDisplay = sharedPreferences.getBool(PreferencesKey.mwebCardDisplay) ?? true;
    final mwebEnabled = sharedPreferences.getBool(PreferencesKey.mwebEnabled) ?? false;
    final hasEnabledMwebBefore =
        sharedPreferences.getBool(PreferencesKey.hasEnabledMwebBefore) ?? false;
    final mwebNodeUri = sharedPreferences.getString(PreferencesKey.mwebNodeUri) ??
        "ltc-electrum.cakewallet.com:9333";

    // If no value
    if (pinLength == null || pinLength == 0) {
      pinLength = defaultPinLength;
    }

    final savedLanguageCode = sharedPreferences.getString(PreferencesKey.currentLanguageCode) ??
        await LanguageService.localeDetection();
    final nodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
    final bitcoinElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
    final litecoinElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentLitecoinElectrumSererIdKey);
    final bitcoinCashElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentBitcoinCashNodeIdKey);
    final havenNodeId = sharedPreferences.getInt(PreferencesKey.currentHavenNodeIdKey);
    final ethereumNodeId = sharedPreferences.getInt(PreferencesKey.currentEthereumNodeIdKey);
    final polygonNodeId = sharedPreferences.getInt(PreferencesKey.currentPolygonNodeIdKey);
    final nanoNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoNodeIdKey);
    final nanoPowNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoPowNodeIdKey);
    final solanaNodeId = sharedPreferences.getInt(PreferencesKey.currentSolanaNodeIdKey);
    final tronNodeId = sharedPreferences.getInt(PreferencesKey.currentTronNodeIdKey);
    final wowneroNodeId = sharedPreferences.getInt(PreferencesKey.currentWowneroNodeIdKey);
    final zanoNodeId = sharedPreferences.getInt(PreferencesKey.currentZanoNodeIdKey);

    final moneroNode = nodeSource.get(nodeId);
    final bitcoinElectrumServer = nodeSource.get(bitcoinElectrumServerId);
    final litecoinElectrumServer = nodeSource.get(litecoinElectrumServerId);
    final havenNode = nodeSource.get(havenNodeId);
    final ethereumNode = nodeSource.get(ethereumNodeId);
    final polygonNode = nodeSource.get(polygonNodeId);
    final bitcoinCashElectrumServer = nodeSource.get(bitcoinCashElectrumServerId);
    final nanoNode = nodeSource.get(nanoNodeId);
    final nanoPowNode = powNodeSource.get(nanoPowNodeId);
    final solanaNode = nodeSource.get(solanaNodeId);
    final tronNode = nodeSource.get(tronNodeId);
    final wowneroNode = nodeSource.get(wowneroNodeId);
    final zanoNode = nodeSource.get(zanoNodeId);
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceName = await _getDeviceName() ?? '';
    final shouldShowYatPopup = sharedPreferences.getBool(PreferencesKey.shouldShowYatPopup) ?? true;
    final shouldShowRepWarning =
        sharedPreferences.getBool(PreferencesKey.shouldShowRepWarning) ?? true;

    final generateSubaddresses =
        sharedPreferences.getInt(PreferencesKey.autoGenerateSubaddressStatusKey);

    final autoGenerateSubaddressStatus = generateSubaddresses != null
        ? AutoGenerateSubaddressStatus.deserialize(raw: generateSubaddresses)
        : defaultAutoGenerateSubaddressStatus;

    final _moneroSeedType = sharedPreferences.getInt(PreferencesKey.moneroSeedType);

    final moneroSeedType = _moneroSeedType != null
        ? MoneroSeedType.deserialize(raw: _moneroSeedType)
        : defaultMoneroSeedType;

    final _bitcoinSeedType = sharedPreferences.getInt(PreferencesKey.bitcoinSeedType);

    final bitcoinSeedType = _bitcoinSeedType != null
        ? BitcoinSeedType.deserialize(raw: _bitcoinSeedType)
        : defaultBitcoinSeedType;

    final _nanoSeedType = sharedPreferences.getInt(PreferencesKey.nanoSeedType);

    final nanoSeedType =
        _nanoSeedType != null ? NanoSeedType.deserialize(raw: _nanoSeedType) : defaultNanoSeedType;

    final nodes = <WalletType, Node>{};
    final powNodes = <WalletType, Node>{};

    if (moneroNode != null) {
      nodes[WalletType.monero] = moneroNode;
    }

    if (bitcoinElectrumServer != null) {
      nodes[WalletType.bitcoin] = bitcoinElectrumServer;
    }

    if (litecoinElectrumServer != null) {
      nodes[WalletType.litecoin] = litecoinElectrumServer;
    }

    if (havenNode != null) {
      nodes[WalletType.haven] = havenNode;
    }

    if (ethereumNode != null) {
      nodes[WalletType.ethereum] = ethereumNode;
    }

    if (polygonNode != null) {
      nodes[WalletType.polygon] = polygonNode;
    }

    if (bitcoinCashElectrumServer != null) {
      nodes[WalletType.bitcoinCash] = bitcoinCashElectrumServer;
    }

    if (nanoNode != null) {
      nodes[WalletType.nano] = nanoNode;
    }

    if (nanoPowNode != null) {
      powNodes[WalletType.nano] = nanoPowNode;
    }

    if (solanaNode != null) {
      nodes[WalletType.solana] = solanaNode;
    }

    if (tronNode != null) {
      nodes[WalletType.tron] = tronNode;
    }

    if (wowneroNode != null) {
      nodes[WalletType.wownero] = wowneroNode;
    }

    if (zanoNode != null) {
      nodes[WalletType.zano] = zanoNode;
    }

    final savedSyncMode = SyncMode.all.firstWhere((element) {
      return element.type.index == (sharedPreferences.getInt(PreferencesKey.syncModeKey) ?? SyncType.sixHours.index);
    });
    final savedSyncAll = sharedPreferences.getBool(PreferencesKey.syncAllKey) ?? true;
    final savedShowSyncNotification = sharedPreferences.getBool(PreferencesKey.showSyncNotificationKey) ?? false;
    final savedBackgroundSyncEnabled = sharedPreferences.getBool(PreferencesKey.backgroundSyncEnabled) ?? false;
    final savedBackgroundSyncOnBattery = sharedPreferences.getBool(PreferencesKey.backgroundSyncOnBattery) ?? true;
    final savedBackgroundSyncOnData = sharedPreferences.getBool(PreferencesKey.backgroundSyncOnData) ?? false;

    // migrated to secure:
    final timeOutDuration = await SecureKey.getInt(
      secureStorage: secureStorage,
      sharedPreferences: sharedPreferences,
      key: SecureKey.pinTimeOutDuration,
    );

    final pinCodeTimeOutDuration = timeOutDuration != null
        ? PinCodeRequiredDuration.deserialize(raw: timeOutDuration)
        : defaultPinCodeTimeOutDuration;

    final allowBiometricalAuthentication = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.allowBiometricalAuthenticationKey,
        ) ??
        false;

    final selectedCake2FAPreset = Cake2FAPresetsOptions.deserialize(
        raw: await SecureKey.getInt(
              secureStorage: secureStorage,
              sharedPreferences: sharedPreferences,
              key: SecureKey.selectedCake2FAPreset,
            ) ??
            Cake2FAPresetsOptions.normal.raw);

    final shouldRequireTOTP2FAForAccessingWallet = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAccessingWallet,
        ) ??
        false;
    final shouldRequireTOTP2FAForSendsToContact = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToContact,
        ) ??
        false;
    final shouldRequireTOTP2FAForSendsToNonContact = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToNonContact,
        ) ??
        false;
    final shouldRequireTOTP2FAForSendsToInternalWallets = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToInternalWallets,
        ) ??
        false;
    final shouldRequireTOTP2FAForExchangesToInternalWallets = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForExchangesToInternalWallets,
        ) ??
        false;
    final shouldRequireTOTP2FAForExchangesToExternalWallets = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForExchangesToExternalWallets,
        ) ??
        false;
    final shouldRequireTOTP2FAForAddingContacts = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAddingContacts,
        ) ??
        false;
    final shouldRequireTOTP2FAForCreatingNewWallets = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForCreatingNewWallets,
        ) ??
        false;
    final shouldRequireTOTP2FAForAllSecurityAndBackupSettings = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        ) ??
        false;
    final useTOTP2FA = await SecureKey.getBool(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.useTOTP2FA,
        ) ??
        false;
    final totpSecretKey = await SecureKey.getString(
          secureStorage: secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.totpSecretKey,
        ) ??
        '';

    return SettingsStore(
      secureStorage: secureStorage,
      sharedPreferences: sharedPreferences,
      initialShouldShowMarketPlaceInDashboard: shouldShowMarketPlaceInDashboard,
      initialShowAddressBookPopupEnabled: showAddressBookPopupEnabled,
      nodes: nodes,
      powNodes: powNodes,
      appVersion: packageInfo.version,
      deviceName: deviceName,
      isBitcoinBuyEnabled: isBitcoinBuyEnabled,
      initialFiatCurrency: currentFiatCurrency,
      initialCakePayCountry: currentCakePayCountry,
      initialBalanceDisplayMode: currentBalanceDisplayMode,
      initialSaveRecipientAddress: shouldSaveRecipientAddress,
      initialAutoGenerateSubaddressStatus: autoGenerateSubaddressStatus,
      initialMoneroSeedType: moneroSeedType,
      initialBitcoinSeedType: bitcoinSeedType,
      initialNanoSeedType: nanoSeedType,
      initialAppSecure: isAppSecure,
      initialDisableTrade: disableTradeOption,
      initialDisableBulletin: disableBulletin,
      initialWalletListOrder: walletListOrder,
      initialWalletListAscending: walletListAscending,
      initialContactListOrder: contactListOrder,
      initialContactListAscending: contactListAscending,
      initialFiatMode: currentFiatApiMode,
      initialAllowBiometricalAuthentication: allowBiometricalAuthentication,
      initialCake2FAPresetOptions: selectedCake2FAPreset,
      initialUseTOTP2FA: useTOTP2FA,
      initialTotpSecretKey: totpSecretKey,
      initialFailedTokenTrial: tokenTrialNumber,
      initialExchangeStatus: exchangeStatus,
      initialTheme: savedTheme,
      actionlistDisplayMode: actionListDisplayMode,
      initialPinLength: pinLength,
      pinTimeOutDuration: pinCodeTimeOutDuration,
      seedPhraseLength: seedPhraseWordCount,
      initialLanguageCode: savedLanguageCode,
      sortBalanceBy: sortBalanceBy,
      pinNativeTokenAtTop: pinNativeTokenAtTop,
      useEtherscan: useEtherscan,
      usePolygonScan: usePolygonScan,
      useTronGrid: useTronGrid,
      useMempoolFeeAPI: useMempoolFeeAPI,
      defaultNanoRep: defaultNanoRep,
      defaultBananoRep: defaultBananoRep,
      lookupsTwitter: lookupsTwitter,
      lookupsZanoAlias: lookupsZanoAlias,
      lookupsMastodon: lookupsMastodon,
      lookupsYatService: lookupsYatService,
      lookupsUnstoppableDomains: lookupsUnstoppableDomains,
      lookupsOpenAlias: lookupsOpenAlias,
      lookupsENS: lookupsENS,
      lookupsWellKnown: lookupsWellKnown,
      customBitcoinFeeRate: customBitcoinFeeRate,
      silentPaymentsCardDisplay: silentPaymentsCardDisplay,
      silentPaymentsAlwaysScan: silentPaymentsAlwaysScan,
      mwebAlwaysScan: mwebAlwaysScan,
      mwebCardDisplay: mwebCardDisplay,
      mwebEnabled: mwebEnabled,
      mwebNodeUri: mwebNodeUri,
      hasEnabledMwebBefore: hasEnabledMwebBefore,
      initialMoneroTransactionPriority: moneroTransactionPriority,
      initialWowneroTransactionPriority: wowneroTransactionPriority,
      initialZanoTransactionPriority: zanoTransactionPriority,
      initialBitcoinTransactionPriority: bitcoinTransactionPriority,
      initialHavenTransactionPriority: havenTransactionPriority,
      initialLitecoinTransactionPriority: litecoinTransactionPriority,
      initialBitcoinCashTransactionPriority: bitcoinCashTransactionPriority,
      initialShouldRequireTOTP2FAForAccessingWallet: shouldRequireTOTP2FAForAccessingWallet,
      initialShouldRequireTOTP2FAForSendsToContact: shouldRequireTOTP2FAForSendsToContact,
      initialShouldRequireTOTP2FAForSendsToNonContact: shouldRequireTOTP2FAForSendsToNonContact,
      initialShouldRequireTOTP2FAForSendsToInternalWallets:
          shouldRequireTOTP2FAForSendsToInternalWallets,
      initialShouldRequireTOTP2FAForExchangesToInternalWallets:
          shouldRequireTOTP2FAForExchangesToInternalWallets,
      initialShouldRequireTOTP2FAForExchangesToExternalWallets:
          shouldRequireTOTP2FAForExchangesToExternalWallets,
      initialShouldRequireTOTP2FAForAddingContacts: shouldRequireTOTP2FAForAddingContacts,
      initialShouldRequireTOTP2FAForCreatingNewWallets: shouldRequireTOTP2FAForCreatingNewWallets,
      initialShouldRequireTOTP2FAForAllSecurityAndBackupSettings:
          shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
      initialEthereumTransactionPriority: ethereumTransactionPriority,
      initialPolygonTransactionPriority: polygonTransactionPriority,
      backgroundTasks: backgroundTasks,
      initialSyncMode: savedSyncMode,
      initialSyncAll: savedSyncAll,
      initialShowSyncNotification: savedShowSyncNotification,
      initialBackgroundSyncEnabled: savedBackgroundSyncEnabled,
      initialBackgroundSyncOnBattery: savedBackgroundSyncOnBattery,
      initialBackgroundSyncOnData: savedBackgroundSyncOnData,
      shouldShowYatPopup: shouldShowYatPopup,
      shouldShowRepWarning: shouldShowRepWarning,
    );
  }

  Future<void> reload({required Box<Node> nodeSource}) async {
    final sharedPreferences = await getIt.getAsync<SharedPreferences>();

    fiatCurrency = FiatCurrency.deserialize(
        raw: sharedPreferences.getString(PreferencesKey.currentFiatCurrencyKey)!);

    priority[WalletType.monero] = monero?.deserializeMoneroTransactionPriority(
            raw: sharedPreferences.getInt(PreferencesKey.moneroTransactionPriority)!) ??
        priority[WalletType.monero]!;

    if (wownero != null &&
        sharedPreferences.getInt(PreferencesKey.wowneroTransactionPriority) != null) {
      priority[WalletType.wownero] = wownero!.deserializeWowneroTransactionPriority(
          raw: sharedPreferences.getInt(PreferencesKey.wowneroTransactionPriority)!);
    }

    if (bitcoin != null &&
        sharedPreferences.getInt(PreferencesKey.bitcoinTransactionPriority) != null) {
      priority[WalletType.bitcoin] = bitcoin!.deserializeBitcoinTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.bitcoinTransactionPriority)!);
    }

    if (monero != null &&
        sharedPreferences.getInt(PreferencesKey.havenTransactionPriority) != null) {
      priority[WalletType.haven] = monero!.deserializeMoneroTransactionPriority(
          raw: sharedPreferences.getInt(PreferencesKey.havenTransactionPriority)!);
    }
    if (bitcoin != null &&
        sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority) != null) {
      priority[WalletType.litecoin] = bitcoin!.deserializeLitecoinTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority)!);
    }
    if (ethereum != null &&
        sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority) != null) {
      priority[WalletType.ethereum] = ethereum!.deserializeEthereumTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority)!);
    }
    if (polygon != null &&
        sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority) != null) {
      priority[WalletType.polygon] = polygon!.deserializePolygonTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority)!);
    }
    if (bitcoinCash != null &&
        sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority) != null) {
      priority[WalletType.bitcoinCash] = bitcoinCash!.deserializeBitcoinCashTransactionPriority(
          sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority)!);
    }
    if (zano != null && sharedPreferences.getInt(PreferencesKey.zanoTransactionPriority) != null) {
      priority[WalletType.zano] = zano!.deserializeMoneroTransactionPriority(
              raw: sharedPreferences.getInt(PreferencesKey.zanoTransactionPriority)!);
    }

    final generateSubaddresses =
        sharedPreferences.getInt(PreferencesKey.autoGenerateSubaddressStatusKey);

    autoGenerateSubaddressStatus = generateSubaddresses != null
        ? AutoGenerateSubaddressStatus.deserialize(raw: generateSubaddresses)
        : defaultAutoGenerateSubaddressStatus;

    final _moneroSeedType = sharedPreferences.getInt(PreferencesKey.moneroSeedType);

    moneroSeedType = _moneroSeedType != null
        ? MoneroSeedType.deserialize(raw: _moneroSeedType)
        : defaultMoneroSeedType;

    final _bitcoinSeedType = sharedPreferences.getInt(PreferencesKey.bitcoinSeedType);

    bitcoinSeedType = _bitcoinSeedType != null
        ? BitcoinSeedType.deserialize(raw: _bitcoinSeedType)
        : defaultBitcoinSeedType;

    final _nanoSeedType = sharedPreferences.getInt(PreferencesKey.nanoSeedType);

    nanoSeedType =
        _nanoSeedType != null ? NanoSeedType.deserialize(raw: _nanoSeedType) : defaultNanoSeedType;

    balanceDisplayMode = BalanceDisplayMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey)!);
    shouldSaveRecipientAddress =
        sharedPreferences.getBool(PreferencesKey.shouldSaveRecipientAddressKey) ??
            shouldSaveRecipientAddress;
    numberOfFailedTokenTrials =
        sharedPreferences.getInt(PreferencesKey.failedTotpTokenTrials) ?? numberOfFailedTokenTrials;
    isAppSecure = sharedPreferences.getBool(PreferencesKey.isAppSecureKey) ?? isAppSecure;
    disableTradeOption = sharedPreferences.getBool(PreferencesKey.disableTradeOption) ?? disableTradeOption;
    disableBulletin =
        sharedPreferences.getBool(PreferencesKey.disableBulletinKey) ?? disableBulletin;
    walletListOrder =
        FilterListOrderType.values[sharedPreferences.getInt(PreferencesKey.walletListOrder) ?? 0];
    contactListOrder =
    FilterListOrderType.values[sharedPreferences.getInt(PreferencesKey.contactListOrder) ?? 0];
    walletListAscending = sharedPreferences.getBool(PreferencesKey.walletListAscending) ?? true;
    contactListAscending = sharedPreferences.getBool(PreferencesKey.contactListAscending) ?? true;
    shouldShowMarketPlaceInDashboard =
        sharedPreferences.getBool(PreferencesKey.shouldShowMarketPlaceInDashboard) ??
            shouldShowMarketPlaceInDashboard;
    showAddressBookPopupEnabled =
        sharedPreferences.getBool(PreferencesKey.showAddressBookPopupEnabled) ??
            showAddressBookPopupEnabled;
    exchangeStatus = ExchangeApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.exchangeStatusKey) ??
            ExchangeApiMode.enabled.raw);
    currentTheme = ThemeList.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentTheme) ??
            (isMoneroOnly ? ThemeList.moneroDarkTheme.raw : ThemeList.brightTheme.raw));
    actionlistDisplayMode = ObservableList<ActionListDisplayMode>();
    actionlistDisplayMode.addAll(deserializeActionlistDisplayModes(
        sharedPreferences.getInt(PreferencesKey.displayActionListModeKey) ?? defaultActionsMode));
    var pinLength = sharedPreferences.getInt(PreferencesKey.currentPinLength);
    // If no value
    if (pinLength == null || pinLength == 0) {
      pinLength = pinCodeLength;
    }
    pinCodeLength = pinLength;

    languageCode = sharedPreferences.getString(PreferencesKey.currentLanguageCode) ?? languageCode;
    shouldShowYatPopup =
        sharedPreferences.getBool(PreferencesKey.shouldShowYatPopup) ?? shouldShowYatPopup;
    shouldShowRepWarning =
        sharedPreferences.getBool(PreferencesKey.shouldShowRepWarning) ?? shouldShowRepWarning;
    sortBalanceBy = SortBalanceBy
        .values[sharedPreferences.getInt(PreferencesKey.sortBalanceBy) ?? sortBalanceBy.index];
    pinNativeTokenAtTop = sharedPreferences.getBool(PreferencesKey.pinNativeTokenAtTop) ?? true;
    useEtherscan = sharedPreferences.getBool(PreferencesKey.useEtherscan) ?? true;
    usePolygonScan = sharedPreferences.getBool(PreferencesKey.usePolygonScan) ?? true;
    useTronGrid = sharedPreferences.getBool(PreferencesKey.useTronGrid) ?? true;
    useMempoolFeeAPI = sharedPreferences.getBool(PreferencesKey.useMempoolFeeAPI) ?? true;
    defaultNanoRep = sharedPreferences.getString(PreferencesKey.defaultNanoRep) ?? "";
    defaultBananoRep = sharedPreferences.getString(PreferencesKey.defaultBananoRep) ?? "";
    lookupsTwitter = sharedPreferences.getBool(PreferencesKey.lookupsTwitter) ?? true;
    lookupsZanoAlias = sharedPreferences.getBool(PreferencesKey.lookupsZanoAlias) ?? true;
    lookupsMastodon = sharedPreferences.getBool(PreferencesKey.lookupsMastodon) ?? true;
    lookupsYatService = sharedPreferences.getBool(PreferencesKey.lookupsYatService) ?? true;
    lookupsUnstoppableDomains =
        sharedPreferences.getBool(PreferencesKey.lookupsUnstoppableDomains) ?? true;
    lookupsOpenAlias = sharedPreferences.getBool(PreferencesKey.lookupsOpenAlias) ?? true;
    lookupsENS = sharedPreferences.getBool(PreferencesKey.lookupsENS) ?? true;
    lookupsWellKnown = sharedPreferences.getBool(PreferencesKey.lookupsWellKnown) ?? true;
    customBitcoinFeeRate = sharedPreferences.getInt(PreferencesKey.customBitcoinFeeRate) ?? 1;
    silentPaymentsCardDisplay =
        sharedPreferences.getBool(PreferencesKey.silentPaymentsCardDisplay) ?? true;
    silentPaymentsAlwaysScan =
        sharedPreferences.getBool(PreferencesKey.silentPaymentsAlwaysScan) ?? false;
    mwebAlwaysScan = sharedPreferences.getBool(PreferencesKey.mwebAlwaysScan) ?? false;
    mwebCardDisplay = sharedPreferences.getBool(PreferencesKey.mwebCardDisplay) ?? true;
    mwebEnabled = sharedPreferences.getBool(PreferencesKey.mwebEnabled) ?? false;
    hasEnabledMwebBefore = sharedPreferences.getBool(PreferencesKey.hasEnabledMwebBefore) ?? false;
    final nodeId = sharedPreferences.getInt(PreferencesKey.currentNodeIdKey);
    final bitcoinElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentBitcoinElectrumSererIdKey);
    final litecoinElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentLitecoinElectrumSererIdKey);
    final bitcoinCashElectrumServerId =
        sharedPreferences.getInt(PreferencesKey.currentBitcoinCashNodeIdKey);
    final havenNodeId = sharedPreferences.getInt(PreferencesKey.currentHavenNodeIdKey);
    final ethereumNodeId = sharedPreferences.getInt(PreferencesKey.currentEthereumNodeIdKey);
    final polygonNodeId = sharedPreferences.getInt(PreferencesKey.currentPolygonNodeIdKey);
    final nanoNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoNodeIdKey);
    final solanaNodeId = sharedPreferences.getInt(PreferencesKey.currentSolanaNodeIdKey);
    final tronNodeId = sharedPreferences.getInt(PreferencesKey.currentTronNodeIdKey);
    final wowneroNodeId = sharedPreferences.getInt(PreferencesKey.currentWowneroNodeIdKey);
    final zanoNodeId = sharedPreferences.getInt(PreferencesKey.currentZanoNodeIdKey);
    final moneroNode = nodeSource.get(nodeId);
    final bitcoinElectrumServer = nodeSource.get(bitcoinElectrumServerId);
    final litecoinElectrumServer = nodeSource.get(litecoinElectrumServerId);
    final havenNode = nodeSource.get(havenNodeId);
    final ethereumNode = nodeSource.get(ethereumNodeId);
    final polygonNode = nodeSource.get(polygonNodeId);
    final bitcoinCashNode = nodeSource.get(bitcoinCashElectrumServerId);
    final nanoNode = nodeSource.get(nanoNodeId);   
    final solanaNode = nodeSource.get(solanaNodeId);
    final tronNode = nodeSource.get(tronNodeId);
    final wowneroNode = nodeSource.get(wowneroNodeId);
    final zanoNode = nodeSource.get(zanoNodeId);

    if (moneroNode != null) {
      nodes[WalletType.monero] = moneroNode;
    }

    if (bitcoinElectrumServer != null) {
      nodes[WalletType.bitcoin] = bitcoinElectrumServer;
    }

    if (litecoinElectrumServer != null) {
      nodes[WalletType.litecoin] = litecoinElectrumServer;
    }

    if (havenNode != null) {
      nodes[WalletType.haven] = havenNode;
    }

    if (ethereumNode != null) {
      nodes[WalletType.ethereum] = ethereumNode;
    }

    if (polygonNode != null) {
      nodes[WalletType.polygon] = polygonNode;
    }

    if (bitcoinCashNode != null) {
      nodes[WalletType.bitcoinCash] = bitcoinCashNode;
    }

    if (nanoNode != null) {
      nodes[WalletType.nano] = nanoNode;
    }

    if (solanaNode != null) {
      nodes[WalletType.solana] = solanaNode;
    }

    if (tronNode != null) {
      nodes[WalletType.tron] = tronNode;
    }

    if (wowneroNode != null) {
      nodes[WalletType.wownero] = wowneroNode;

    }

    if (zanoNode != null) {
      nodes[WalletType.zano] = zanoNode;
    }

    // MIGRATED:

    useTOTP2FA = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.useTOTP2FA,
        ) ??
        useTOTP2FA;

    totpSecretKey = await SecureKey.getString(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.totpSecretKey,
        ) ??
        totpSecretKey;

    final timeOutDuration = await SecureKey.getInt(
      secureStorage: _secureStorage,
      sharedPreferences: sharedPreferences,
      key: SecureKey.pinTimeOutDuration,
    );

    pinTimeOutDuration = timeOutDuration != null
        ? PinCodeRequiredDuration.deserialize(raw: timeOutDuration)
        : defaultPinCodeTimeOutDuration;

    allowBiometricalAuthentication = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.allowBiometricalAuthenticationKey,
        ) ??
        allowBiometricalAuthentication;

    selectedCake2FAPreset = Cake2FAPresetsOptions.deserialize(
        raw: await SecureKey.getInt(
              secureStorage: _secureStorage,
              sharedPreferences: sharedPreferences,
              key: SecureKey.selectedCake2FAPreset,
            ) ??
            Cake2FAPresetsOptions.normal.raw);

    shouldRequireTOTP2FAForAccessingWallet = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAccessingWallet,
        ) ??
        false;
    shouldRequireTOTP2FAForSendsToContact = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToContact,
        ) ??
        false;

    shouldRequireTOTP2FAForSendsToNonContact = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToNonContact,
        ) ??
        false;
    shouldRequireTOTP2FAForSendsToInternalWallets = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForSendsToInternalWallets,
        ) ??
        false;
    shouldRequireTOTP2FAForExchangesToInternalWallets = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForExchangesToInternalWallets,
        ) ??
        false;
    shouldRequireTOTP2FAForExchangesToExternalWallets = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForExchangesToExternalWallets,
        ) ??
        false;
    shouldRequireTOTP2FAForAddingContacts = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAddingContacts,
        ) ??
        false;
    shouldRequireTOTP2FAForCreatingNewWallets = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForCreatingNewWallets,
        ) ??
        false;
    shouldRequireTOTP2FAForAllSecurityAndBackupSettings = await SecureKey.getBool(
          secureStorage: _secureStorage,
          sharedPreferences: sharedPreferences,
          key: SecureKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        ) ??
        false;
  }

  Future<void> _saveCurrentNode(Node node, WalletType walletType) async {
    switch (walletType) {
      case WalletType.bitcoin:
        await _sharedPreferences.setInt(
            PreferencesKey.currentBitcoinElectrumSererIdKey, node.key as int);
        break;
      case WalletType.litecoin:
        await _sharedPreferences.setInt(
            PreferencesKey.currentLitecoinElectrumSererIdKey, node.key as int);
        break;
      case WalletType.monero:
        await _sharedPreferences.setInt(PreferencesKey.currentNodeIdKey, node.key as int);
        break;
      case WalletType.haven:
        await _sharedPreferences.setInt(PreferencesKey.currentHavenNodeIdKey, node.key as int);
        break;
      case WalletType.ethereum:
        await _sharedPreferences.setInt(PreferencesKey.currentEthereumNodeIdKey, node.key as int);
        break;
      case WalletType.bitcoinCash:
        await _sharedPreferences.setInt(
            PreferencesKey.currentBitcoinCashNodeIdKey, node.key as int);
        break;
      case WalletType.nano:
        await _sharedPreferences.setInt(PreferencesKey.currentNanoNodeIdKey, node.key as int);
        break;
      case WalletType.polygon:
        await _sharedPreferences.setInt(PreferencesKey.currentPolygonNodeIdKey, node.key as int);
        break;
      case WalletType.solana:
        await _sharedPreferences.setInt(PreferencesKey.currentSolanaNodeIdKey, node.key as int);
        break;
      case WalletType.tron:
        await _sharedPreferences.setInt(PreferencesKey.currentTronNodeIdKey, node.key as int);
        break;
      case WalletType.wownero:
        await _sharedPreferences.setInt(PreferencesKey.currentWowneroNodeIdKey, node.key as int);
        break;
      case WalletType.zano:
        await _sharedPreferences.setInt(PreferencesKey.currentZanoNodeIdKey, node.key as int);
      default:
        break;
    }

    nodes[walletType] = node;
  }

  Future<void> _saveCurrentPowNode(Node node, WalletType walletType) async {
    switch (walletType) {
      case WalletType.nano:
        await _sharedPreferences.setInt(PreferencesKey.currentNanoPowNodeIdKey, node.key as int);
        break;
      default:
        break;
    }

    powNodes[walletType] = node;
  }

  void initializeTrocadorProviderStates() {
    for (var provider in TrocadorExchangeProvider.availableProviders) {
      final savedState = _sharedPreferences.getBool(provider) ?? true;
      trocadorProviderStates[provider] = savedState;
    }
  }

  void saveTrocadorProviderState(String providerName, bool state) {
    _sharedPreferences.setBool(providerName, state);
    trocadorProviderStates[providerName] = state;
  }

  static Future<String?> _getDeviceName() async {
    String? deviceName = '';
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceName = '${androidInfo.brand}%20${androidInfo.manufacturer}%20${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceName = iosInfo.model;
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      deviceName = linuxInfo.prettyName;
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfoPlugin.macOsInfo;
      deviceName = macInfo.computerName;
    } else if (Platform.isWindows) {
      try {
        final windowsInfo = await deviceInfoPlugin.windowsInfo;
        deviceName = windowsInfo.productName;
      } catch (e) {
        printV(e);
        printV(
            'likely digitalProductId is null wait till https://github.com/fluttercommunity/plus_plugins/pull/3188 is merged');
        deviceName = "Windows Device";
      }
    }

    return deviceName;
  }
}
