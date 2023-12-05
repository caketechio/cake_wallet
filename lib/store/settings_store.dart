import 'dart:io';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/bitcoin_cash/bitcoin_cash.dart';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/buy_provider_types.dart';
import 'package:cake_wallet/entities/cake_2fa_preset_options.dart';
import 'package:cake_wallet/entities/background_tasks.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/exchange_provider_types.dart';
import 'package:cake_wallet/entities/pin_code_required_duration.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/entities/seed_phrase_length.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/entities/sort_balance_types.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/exchange/provider/trocador_exchange_provider.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/themes/theme_list.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:package_info/package_info.dart';
import 'package:cake_wallet/di.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cw_core/node.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/entities/action_list_display_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cw_core/set_app_secure_native.dart';

part 'settings_store.g.dart';

class SettingsStore = SettingsStoreBase with _$SettingsStore;

abstract class SettingsStoreBase with Store {
  SettingsStoreBase(
      {required BackgroundTasks backgroundTasks,
      required SharedPreferences sharedPreferences,
      required bool initialShouldShowMarketPlaceInDashboard,
      required FiatCurrency initialFiatCurrency,
      required BalanceDisplayMode initialBalanceDisplayMode,
      required bool initialSaveRecipientAddress,
      required AutoGenerateSubaddressStatus initialAutoGenerateSubaddressStatus,
      required SeedType initialMoneroSeedType,
      required bool initialAppSecure,
      required bool initialDisableBuy,
      required bool initialDisableSell,
      required BuyProviderType initialDefaultBuyProvider,
      required ExchangeProviderType initialDefaultExchangeProvider,
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
      // required String initialCurrentLocale,
      required this.appVersion,
      required this.deviceName,
      required Map<WalletType, Node> nodes,
      required Map<WalletType, Node> powNodes,
      required this.shouldShowYatPopup,
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
      required this.defaultNanoRep,
      required this.defaultBananoRep,
      required this.lookupsTwitter,
      required this.lookupsMastodon,
      required this.lookupsYatService,
      required this.lookupsUnstoppableDomains,
      required this.lookupsOpenAlias,
      required this.lookupsENS,
      TransactionPriority? initialBitcoinTransactionPriority,
      TransactionPriority? initialMoneroTransactionPriority,
      TransactionPriority? initialHavenTransactionPriority,
      TransactionPriority? initialLitecoinTransactionPriority,
      TransactionPriority? initialEthereumTransactionPriority,
      TransactionPriority? initialPolygonTransactionPriority,
      TransactionPriority? initialBitcoinCashTransactionPriority})
      : nodes = ObservableMap<WalletType, Node>.of(nodes),
        powNodes = ObservableMap<WalletType, Node>.of(powNodes),
        _sharedPreferences = sharedPreferences,
        _backgroundTasks = backgroundTasks,
        fiatCurrency = initialFiatCurrency,
        balanceDisplayMode = initialBalanceDisplayMode,
        shouldSaveRecipientAddress = initialSaveRecipientAddress,
        autoGenerateSubaddressStatus = initialAutoGenerateSubaddressStatus,
        moneroSeedType = initialMoneroSeedType,
        fiatApiMode = initialFiatMode,
        allowBiometricalAuthentication = initialAllowBiometricalAuthentication,
        selectedCake2FAPreset = initialCake2FAPresetOptions,
        totpSecretKey = initialTotpSecretKey,
        useTOTP2FA = initialUseTOTP2FA,
        numberOfFailedTokenTrials = initialFailedTokenTrial,
        isAppSecure = initialAppSecure,
        disableBuy = initialDisableBuy,
        disableSell = initialDisableSell,
        defaultBuyProvider = initialDefaultBuyProvider,
        defaultExchangeProvider = initialDefaultExchangeProvider,
        shouldShowMarketPlaceInDashboard = initialShouldShowMarketPlaceInDashboard,
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
        priority = ObservableMap<WalletType, TransactionPriority>() {
    //this.nodes = ObservableMap<WalletType, Node>.of(nodes);

    if (initialMoneroTransactionPriority != null) {
      priority[WalletType.monero] = initialMoneroTransactionPriority;
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

    initializeTrocadorProviderStates();

    reaction(
        (_) => fiatCurrency,
        (FiatCurrency fiatCurrency) => sharedPreferences.setString(
            PreferencesKey.currentFiatCurrencyKey, fiatCurrency.serialize()));

    reaction(
        (_) => shouldShowYatPopup,
        (bool shouldShowYatPopup) =>
            sharedPreferences.setBool(PreferencesKey.shouldShowYatPopup, shouldShowYatPopup));

    priority.observe((change) {
      final String? key;
      switch (change.key) {
        case WalletType.monero:
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

    reaction((_) => disableBuy,
        (bool disableBuy) => sharedPreferences.setBool(PreferencesKey.disableBuyKey, disableBuy));

    reaction(
        (_) => disableSell,
        (bool disableSell) =>
            sharedPreferences.setBool(PreferencesKey.disableSellKey, disableSell));

    reaction(
        (_) => defaultBuyProvider,
        (BuyProviderType defaultBuyProvider) =>
            sharedPreferences.setInt(PreferencesKey.defaultBuyProvider, defaultBuyProvider.index));

    reaction(
        (_) => defaultExchangeProvider,
        (ExchangeProviderType defaultExchangeProvider) => sharedPreferences.setInt(
            PreferencesKey.defaultExchangeProvider, defaultExchangeProvider.index));

    reaction(
        (_) => autoGenerateSubaddressStatus,
        (AutoGenerateSubaddressStatus autoGenerateSubaddressStatus) => sharedPreferences.setInt(
            PreferencesKey.autoGenerateSubaddressStatusKey, autoGenerateSubaddressStatus.value));

    reaction(
        (_) => moneroSeedType,
        (SeedType moneroSeedType) =>
            sharedPreferences.setInt(PreferencesKey.moneroSeedType, moneroSeedType.raw));

    reaction(
        (_) => fiatApiMode,
        (FiatApiMode mode) =>
            sharedPreferences.setInt(PreferencesKey.currentFiatApiModeKey, mode.serialize()));

    reaction((_) => currentTheme,
        (ThemeBase theme) => sharedPreferences.setInt(PreferencesKey.currentTheme, theme.raw));

    reaction(
        (_) => allowBiometricalAuthentication,
        (bool biometricalAuthentication) => sharedPreferences.setBool(
            PreferencesKey.allowBiometricalAuthenticationKey, biometricalAuthentication));

    reaction(
        (_) => selectedCake2FAPreset,
        (Cake2FAPresetsOptions selectedCake2FAPreset) => sharedPreferences.setInt(
            PreferencesKey.selectedCake2FAPreset, selectedCake2FAPreset.serialize()));

    reaction(
        (_) => shouldRequireTOTP2FAForAccessingWallet,
        (bool requireTOTP2FAForAccessingWallet) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForAccessingWallet,
            requireTOTP2FAForAccessingWallet));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToContact,
        (bool requireTOTP2FAForSendsToContact) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForSendsToContact, requireTOTP2FAForSendsToContact));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToNonContact,
        (bool requireTOTP2FAForSendsToNonContact) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForSendsToNonContact,
            requireTOTP2FAForSendsToNonContact));

    reaction(
        (_) => shouldRequireTOTP2FAForSendsToInternalWallets,
        (bool requireTOTP2FAForSendsToInternalWallets) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForSendsToInternalWallets,
            requireTOTP2FAForSendsToInternalWallets));

    reaction(
        (_) => shouldRequireTOTP2FAForExchangesToInternalWallets,
        (bool requireTOTP2FAForExchangesToInternalWallets) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForExchangesToInternalWallets,
            requireTOTP2FAForExchangesToInternalWallets));

    reaction(
        (_) => shouldRequireTOTP2FAForExchangesToExternalWallets,
        (bool requireTOTP2FAForExchangesToExternalWallets) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForExchangesToExternalWallets,
            requireTOTP2FAForExchangesToExternalWallets));

    reaction(
        (_) => shouldRequireTOTP2FAForAddingContacts,
        (bool requireTOTP2FAForAddingContacts) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForAddingContacts, requireTOTP2FAForAddingContacts));

    reaction(
        (_) => shouldRequireTOTP2FAForCreatingNewWallets,
        (bool requireTOTP2FAForCreatingNewWallets) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForCreatingNewWallets,
            requireTOTP2FAForCreatingNewWallets));

    reaction(
        (_) => shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
        (bool requireTOTP2FAForAllSecurityAndBackupSettings) => sharedPreferences.setBool(
            PreferencesKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings,
            requireTOTP2FAForAllSecurityAndBackupSettings));

    reaction(
        (_) => useTOTP2FA, (bool use) => sharedPreferences.setBool(PreferencesKey.useTOTP2FA, use));

    reaction((_) => totpSecretKey,
        (String totpKey) => sharedPreferences.setString(PreferencesKey.totpSecretKey, totpKey));
    reaction(
        (_) => numberOfFailedTokenTrials,
        (int failedTokenTrail) =>
            sharedPreferences.setInt(PreferencesKey.failedTotpTokenTrials, failedTokenTrail));

    reaction(
        (_) => shouldShowMarketPlaceInDashboard,
        (bool value) =>
            sharedPreferences.setBool(PreferencesKey.shouldShowMarketPlaceInDashboard, value));

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
        (_) => pinTimeOutDuration,
        (PinCodeRequiredDuration pinCodeInterval) =>
            sharedPreferences.setInt(PreferencesKey.pinTimeOutDuration, pinCodeInterval.value));

    reaction(
        (_) => balanceDisplayMode,
        (BalanceDisplayMode mode) => sharedPreferences.setInt(
            PreferencesKey.currentBalanceDisplayModeKey, mode.serialize()));

    reaction((_) => currentSyncMode, (SyncMode syncMode) {
      sharedPreferences.setInt(PreferencesKey.syncModeKey, syncMode.type.index);

      _backgroundTasks.registerSyncTask(changeExisting: true);
    });

    reaction((_) => currentSyncAll, (bool syncAll) {
      sharedPreferences.setBool(PreferencesKey.syncAllKey, syncAll);

      _backgroundTasks.registerSyncTask(changeExisting: true);
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
  static const defaultPinCodeTimeOutDuration = PinCodeRequiredDuration.tenminutes;
  static const defaultAutoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.initialized;
  static const defaultSeedPhraseLength = SeedPhraseLength.twelveWords;
  static const defaultMoneroSeedType = SeedType.defaultSeedType;

  @observable
  FiatCurrency fiatCurrency;

  @observable
  bool shouldShowYatPopup;

  @observable
  bool shouldShowMarketPlaceInDashboard;

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
  SeedType moneroSeedType;

  @observable
  bool isAppSecure;

  @observable
  bool disableBuy;

  @observable
  bool disableSell;

  @observable
  BuyProviderType defaultBuyProvider;

  @observable
  ExchangeProviderType defaultExchangeProvider;

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
  String defaultNanoRep;

  @observable
  String defaultBananoRep;

  @observable
  bool lookupsTwitter;

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
  SyncMode currentSyncMode;

  @observable
  bool currentSyncAll;

  String appVersion;

  String deviceName;

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
    final backgroundTasks = getIt.get<BackgroundTasks>();
    final currentFiatCurrency = FiatCurrency.deserialize(
        raw: sharedPreferences.getString(PreferencesKey.currentFiatCurrencyKey)!);

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

    moneroTransactionPriority ??= monero?.getDefaultTransactionPriority();
    bitcoinTransactionPriority ??= bitcoin?.getMediumTransactionPriority();
    havenTransactionPriority ??= monero?.getDefaultTransactionPriority();
    litecoinTransactionPriority ??= bitcoin?.getLitecoinTransactionPriorityMedium();
    ethereumTransactionPriority ??= ethereum?.getDefaultTransactionPriority();
    bitcoinCashTransactionPriority ??= bitcoinCash?.getDefaultTransactionPriority();
    polygonTransactionPriority ??= polygon?.getDefaultTransactionPriority();

    final currentBalanceDisplayMode = BalanceDisplayMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey)!);
    // FIX-ME: Check for which default value we should have here
    final shouldSaveRecipientAddress =
        sharedPreferences.getBool(PreferencesKey.shouldSaveRecipientAddressKey) ?? false;
    final isAppSecure = sharedPreferences.getBool(PreferencesKey.isAppSecureKey) ?? false;
    final disableBuy = sharedPreferences.getBool(PreferencesKey.disableBuyKey) ?? false;
    final disableSell = sharedPreferences.getBool(PreferencesKey.disableSellKey) ?? false;
    final defaultBuyProvider =
        BuyProviderType.values[sharedPreferences.getInt(PreferencesKey.defaultBuyProvider) ?? 0];
    final defaultExchangeProvider = ExchangeProviderType
        .values[sharedPreferences.getInt(PreferencesKey.defaultExchangeProvider) ?? 0];
    final currentFiatApiMode = FiatApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentFiatApiModeKey) ??
            FiatApiMode.enabled.raw);
    final allowBiometricalAuthentication =
        sharedPreferences.getBool(PreferencesKey.allowBiometricalAuthenticationKey) ?? false;
    final selectedCake2FAPreset = Cake2FAPresetsOptions.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.selectedCake2FAPreset) ??
            Cake2FAPresetsOptions.normal.raw);
    final shouldRequireTOTP2FAForAccessingWallet =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForAccessingWallet) ?? false;
    final shouldRequireTOTP2FAForSendsToContact =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToContact) ?? false;
    final shouldRequireTOTP2FAForSendsToNonContact =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToNonContact) ?? false;
    final shouldRequireTOTP2FAForSendsToInternalWallets =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToInternalWallets) ??
            false;
    final shouldRequireTOTP2FAForExchangesToInternalWallets = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForExchangesToInternalWallets) ??
        false;
    final shouldRequireTOTP2FAForExchangesToExternalWallets = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForExchangesToExternalWallets) ??
        false;
    final shouldRequireTOTP2FAForAddingContacts =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForAddingContacts) ?? false;
    final shouldRequireTOTP2FAForCreatingNewWallets =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForCreatingNewWallets) ??
            false;
    final shouldRequireTOTP2FAForAllSecurityAndBackupSettings = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings) ??
        false;
    final useTOTP2FA = sharedPreferences.getBool(PreferencesKey.useTOTP2FA) ?? false;
    final totpSecretKey = sharedPreferences.getString(PreferencesKey.totpSecretKey) ?? '';
    final tokenTrialNumber = sharedPreferences.getInt(PreferencesKey.failedTotpTokenTrials) ?? 0;
    final shouldShowMarketPlaceInDashboard =
        sharedPreferences.getBool(PreferencesKey.shouldShowMarketPlaceInDashboard) ?? true;
    final exchangeStatus = ExchangeApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.exchangeStatusKey) ??
            ExchangeApiMode.enabled.raw);
    final legacyTheme = (sharedPreferences.getBool(PreferencesKey.isDarkThemeLegacy) ?? false)
        ? ThemeType.dark.index
        : ThemeType.bright.index;
    final savedTheme = initialTheme ??
        ThemeList.deserialize(
            raw: sharedPreferences.getInt(PreferencesKey.currentTheme) ?? legacyTheme);
    final actionListDisplayMode = ObservableList<ActionListDisplayMode>();
    actionListDisplayMode.addAll(deserializeActionlistDisplayModes(
        sharedPreferences.getInt(PreferencesKey.displayActionListModeKey) ?? defaultActionsMode));
    var pinLength = sharedPreferences.getInt(PreferencesKey.currentPinLength);
    final timeOutDuration = sharedPreferences.getInt(PreferencesKey.pinTimeOutDuration);
    final seedPhraseCount = sharedPreferences.getInt(PreferencesKey.currentSeedPhraseLength);
    final pinCodeTimeOutDuration = timeOutDuration != null
        ? PinCodeRequiredDuration.deserialize(raw: timeOutDuration)
        : defaultPinCodeTimeOutDuration;
    final seedPhraseWordCount = seedPhraseCount != null
        ? SeedPhraseLength.deserialize(raw: seedPhraseCount)
        : defaultSeedPhraseLength;
    final sortBalanceBy =
        SortBalanceBy.values[sharedPreferences.getInt(PreferencesKey.sortBalanceBy) ?? 0];
    final pinNativeTokenAtTop =
        sharedPreferences.getBool(PreferencesKey.pinNativeTokenAtTop) ?? true;
    final useEtherscan = sharedPreferences.getBool(PreferencesKey.useEtherscan) ?? true;
    final usePolygonScan = sharedPreferences.getBool(PreferencesKey.usePolygonScan) ?? true;
    final defaultNanoRep = sharedPreferences.getString(PreferencesKey.defaultNanoRep) ?? "";
    final defaultBananoRep = sharedPreferences.getString(PreferencesKey.defaultBananoRep) ?? "";
    final lookupsTwitter = sharedPreferences.getBool(PreferencesKey.lookupsTwitter) ?? true;
    final lookupsMastodon = sharedPreferences.getBool(PreferencesKey.lookupsMastodon) ?? true;
    final lookupsYatService = sharedPreferences.getBool(PreferencesKey.lookupsYatService) ?? true;
    final lookupsUnstoppableDomains =
        sharedPreferences.getBool(PreferencesKey.lookupsUnstoppableDomains) ?? true;
    final lookupsOpenAlias = sharedPreferences.getBool(PreferencesKey.lookupsOpenAlias) ?? true;
    final lookupsENS = sharedPreferences.getBool(PreferencesKey.lookupsENS) ?? true;

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
    final moneroNode = nodeSource.get(nodeId);
    final bitcoinElectrumServer = nodeSource.get(bitcoinElectrumServerId);
    final litecoinElectrumServer = nodeSource.get(litecoinElectrumServerId);
    final havenNode = nodeSource.get(havenNodeId);
    final ethereumNode = nodeSource.get(ethereumNodeId);
    final polygonNode = nodeSource.get(polygonNodeId);
    final bitcoinCashElectrumServer = nodeSource.get(bitcoinCashElectrumServerId);
    final nanoNode = nodeSource.get(nanoNodeId);
    final nanoPowNode = powNodeSource.get(nanoPowNodeId);
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceName = await _getDeviceName() ?? '';
    final shouldShowYatPopup = sharedPreferences.getBool(PreferencesKey.shouldShowYatPopup) ?? true;

    final generateSubaddresses =
        sharedPreferences.getInt(PreferencesKey.autoGenerateSubaddressStatusKey);

    final autoGenerateSubaddressStatus = generateSubaddresses != null
        ? AutoGenerateSubaddressStatus.deserialize(raw: generateSubaddresses)
        : defaultAutoGenerateSubaddressStatus;

    final _moneroSeedType = sharedPreferences.getInt(PreferencesKey.moneroSeedType);

    final moneroSeedType = _moneroSeedType != null
        ? SeedType.deserialize(raw: _moneroSeedType)
        : defaultMoneroSeedType;

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

    final savedSyncMode = SyncMode.all.firstWhere((element) {
      return element.type.index == (sharedPreferences.getInt(PreferencesKey.syncModeKey) ?? 1);
    });
    final savedSyncAll = sharedPreferences.getBool(PreferencesKey.syncAllKey) ?? true;

    return SettingsStore(
        sharedPreferences: sharedPreferences,
        initialShouldShowMarketPlaceInDashboard: shouldShowMarketPlaceInDashboard,
        nodes: nodes,
        powNodes: powNodes,
        appVersion: packageInfo.version,
        deviceName: deviceName,
        isBitcoinBuyEnabled: isBitcoinBuyEnabled,
        initialFiatCurrency: currentFiatCurrency,
        initialBalanceDisplayMode: currentBalanceDisplayMode,
        initialSaveRecipientAddress: shouldSaveRecipientAddress,
        initialAutoGenerateSubaddressStatus: autoGenerateSubaddressStatus,
        initialMoneroSeedType: moneroSeedType,
        initialAppSecure: isAppSecure,
        initialDisableBuy: disableBuy,
        initialDisableSell: disableSell,
        initialDefaultBuyProvider: defaultBuyProvider,
        initialDefaultExchangeProvider: defaultExchangeProvider,
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
        defaultNanoRep: defaultNanoRep,
        defaultBananoRep: defaultBananoRep,
        lookupsTwitter: lookupsTwitter,
        lookupsMastodon: lookupsMastodon,
        lookupsYatService: lookupsYatService,
        lookupsUnstoppableDomains: lookupsUnstoppableDomains,
        lookupsOpenAlias: lookupsOpenAlias,
        lookupsENS: lookupsENS,
        initialMoneroTransactionPriority: moneroTransactionPriority,
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
        shouldShowYatPopup: shouldShowYatPopup);
  }

  Future<void> reload({required Box<Node> nodeSource}) async {
    final sharedPreferences = await getIt.getAsync<SharedPreferences>();

    fiatCurrency = FiatCurrency.deserialize(
        raw: sharedPreferences.getString(PreferencesKey.currentFiatCurrencyKey)!);

    priority[WalletType.monero] = monero?.deserializeMoneroTransactionPriority(
            raw: sharedPreferences.getInt(PreferencesKey.moneroTransactionPriority)!) ??
        priority[WalletType.monero]!;
    priority[WalletType.bitcoin] = bitcoin?.deserializeBitcoinTransactionPriority(
            sharedPreferences.getInt(PreferencesKey.moneroTransactionPriority)!) ??
        priority[WalletType.bitcoin]!;

    if (sharedPreferences.getInt(PreferencesKey.havenTransactionPriority) != null) {
      priority[WalletType.haven] = monero?.deserializeMoneroTransactionPriority(
              raw: sharedPreferences.getInt(PreferencesKey.havenTransactionPriority)!) ??
          priority[WalletType.haven]!;
    }
    if (sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority) != null) {
      priority[WalletType.litecoin] = bitcoin?.deserializeLitecoinTransactionPriority(
              sharedPreferences.getInt(PreferencesKey.litecoinTransactionPriority)!) ??
          priority[WalletType.litecoin]!;
    }
    if (sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority) != null) {
      priority[WalletType.ethereum] = ethereum?.deserializeEthereumTransactionPriority(
              sharedPreferences.getInt(PreferencesKey.ethereumTransactionPriority)!) ??
          priority[WalletType.ethereum]!;
    }
    if (sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority) != null) {
      priority[WalletType.polygon] = polygon?.deserializePolygonTransactionPriority(
              sharedPreferences.getInt(PreferencesKey.polygonTransactionPriority)!) ??
          priority[WalletType.polygon]!;
    }
    if (sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority) != null) {
      priority[WalletType.bitcoinCash] = bitcoinCash?.deserializeBitcoinCashTransactionPriority(
              sharedPreferences.getInt(PreferencesKey.bitcoinCashTransactionPriority)!) ??
          priority[WalletType.bitcoinCash]!;
    }

    final generateSubaddresses =
        sharedPreferences.getInt(PreferencesKey.autoGenerateSubaddressStatusKey);

    autoGenerateSubaddressStatus = generateSubaddresses != null
        ? AutoGenerateSubaddressStatus.deserialize(raw: generateSubaddresses)
        : defaultAutoGenerateSubaddressStatus;

    final _moneroSeedType = sharedPreferences.getInt(PreferencesKey.moneroSeedType);

    moneroSeedType = _moneroSeedType != null
        ? SeedType.deserialize(raw: _moneroSeedType)
        : defaultMoneroSeedType;

    balanceDisplayMode = BalanceDisplayMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentBalanceDisplayModeKey)!);
    shouldSaveRecipientAddress =
        sharedPreferences.getBool(PreferencesKey.shouldSaveRecipientAddressKey) ??
            shouldSaveRecipientAddress;
    useTOTP2FA = sharedPreferences.getBool(PreferencesKey.useTOTP2FA) ?? useTOTP2FA;
    totpSecretKey = sharedPreferences.getString(PreferencesKey.totpSecretKey) ?? totpSecretKey;
    numberOfFailedTokenTrials =
        sharedPreferences.getInt(PreferencesKey.failedTotpTokenTrials) ?? numberOfFailedTokenTrials;
    isAppSecure = sharedPreferences.getBool(PreferencesKey.isAppSecureKey) ?? isAppSecure;
    disableBuy = sharedPreferences.getBool(PreferencesKey.disableBuyKey) ?? disableBuy;
    disableSell = sharedPreferences.getBool(PreferencesKey.disableSellKey) ?? disableSell;
    defaultBuyProvider =
        BuyProviderType.values[sharedPreferences.getInt(PreferencesKey.defaultBuyProvider) ?? 0];
    allowBiometricalAuthentication =
        sharedPreferences.getBool(PreferencesKey.allowBiometricalAuthenticationKey) ??
            allowBiometricalAuthentication;
    selectedCake2FAPreset = Cake2FAPresetsOptions.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.selectedCake2FAPreset) ??
            Cake2FAPresetsOptions.normal.raw);
    shouldRequireTOTP2FAForAccessingWallet =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForAccessingWallet) ?? false;
    shouldRequireTOTP2FAForSendsToContact =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToContact) ?? false;
    shouldRequireTOTP2FAForSendsToNonContact =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToNonContact) ?? false;
    shouldRequireTOTP2FAForSendsToInternalWallets =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForSendsToInternalWallets) ??
            false;
    shouldRequireTOTP2FAForExchangesToInternalWallets = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForExchangesToInternalWallets) ??
        false;
    shouldRequireTOTP2FAForExchangesToExternalWallets = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForExchangesToExternalWallets) ??
        false;
    shouldRequireTOTP2FAForAddingContacts =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForAddingContacts) ?? false;
    shouldRequireTOTP2FAForCreatingNewWallets =
        sharedPreferences.getBool(PreferencesKey.shouldRequireTOTP2FAForCreatingNewWallets) ??
            false;
    shouldRequireTOTP2FAForAllSecurityAndBackupSettings = sharedPreferences
            .getBool(PreferencesKey.shouldRequireTOTP2FAForAllSecurityAndBackupSettings) ??
        false;
    shouldShowMarketPlaceInDashboard =
        sharedPreferences.getBool(PreferencesKey.shouldShowMarketPlaceInDashboard) ??
            shouldShowMarketPlaceInDashboard;
    selectedCake2FAPreset = Cake2FAPresetsOptions.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.selectedCake2FAPreset) ??
            Cake2FAPresetsOptions.narrow.raw);
    exchangeStatus = ExchangeApiMode.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.exchangeStatusKey) ??
            ExchangeApiMode.enabled.raw);
    final legacyTheme = (sharedPreferences.getBool(PreferencesKey.isDarkThemeLegacy) ?? false)
        ? ThemeType.dark.index
        : ThemeType.bright.index;
    currentTheme = ThemeList.deserialize(
        raw: sharedPreferences.getInt(PreferencesKey.currentTheme) ?? legacyTheme);
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
    sortBalanceBy = SortBalanceBy
        .values[sharedPreferences.getInt(PreferencesKey.sortBalanceBy) ?? sortBalanceBy.index];
    pinNativeTokenAtTop = sharedPreferences.getBool(PreferencesKey.pinNativeTokenAtTop) ?? true;
    useEtherscan = sharedPreferences.getBool(PreferencesKey.useEtherscan) ?? true;
    usePolygonScan = sharedPreferences.getBool(PreferencesKey.usePolygonScan) ?? true;
    defaultNanoRep = sharedPreferences.getString(PreferencesKey.defaultNanoRep) ?? "";
    defaultBananoRep = sharedPreferences.getString(PreferencesKey.defaultBananoRep) ?? "";
    lookupsTwitter = sharedPreferences.getBool(PreferencesKey.lookupsTwitter) ?? true;
    lookupsMastodon = sharedPreferences.getBool(PreferencesKey.lookupsMastodon) ?? true;
    lookupsYatService = sharedPreferences.getBool(PreferencesKey.lookupsYatService) ?? true;
    lookupsUnstoppableDomains =
        sharedPreferences.getBool(PreferencesKey.lookupsUnstoppableDomains) ?? true;
    lookupsOpenAlias = sharedPreferences.getBool(PreferencesKey.lookupsOpenAlias) ?? true;
    lookupsENS = sharedPreferences.getBool(PreferencesKey.lookupsENS) ?? true;

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
    final nanoPowNodeId = sharedPreferences.getInt(PreferencesKey.currentNanoNodeIdKey);
    final moneroNode = nodeSource.get(nodeId);
    final bitcoinElectrumServer = nodeSource.get(bitcoinElectrumServerId);
    final litecoinElectrumServer = nodeSource.get(litecoinElectrumServerId);
    final havenNode = nodeSource.get(havenNodeId);
    final ethereumNode = nodeSource.get(ethereumNodeId);
    final polygonNode = nodeSource.get(polygonNodeId);
    final bitcoinCashNode = nodeSource.get(bitcoinCashElectrumServerId);
    final nanoNode = nodeSource.get(nanoNodeId);

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
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      deviceName = windowsInfo.productName;
    }

    return deviceName;
  }
}
