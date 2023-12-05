import 'package:cake_wallet/anonpay/anonpay_api.dart';
import 'package:cake_wallet/anonpay/anonpay_info_base.dart';
import 'package:cake_wallet/anonpay/anonpay_invoice_info.dart';
import 'package:cake_wallet/buy/moonpay/moonpay_buy_provider.dart';
import 'package:cake_wallet/buy/moonpay/moonpay_exchange_provider.dart';
import 'package:cake_wallet/buy/onramper/onramper_buy_provider.dart';
import 'package:cake_wallet/bitcoin_cash/bitcoin_cash.dart';
import 'package:cake_wallet/buy/payfura/payfura_buy_provider.dart';
import 'package:cake_wallet/core/wallet_connect/wallet_connect_key_service.dart';
import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/buy/robinhood/robinhood_buy_provider.dart';
import 'package:cake_wallet/core/wallet_connect/web3wallet_service.dart';
import 'package:cake_wallet/core/yat_service.dart';
import 'package:cake_wallet/entities/background_tasks.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/parse_address_from_domain.dart';
import 'package:cake_wallet/entities/receive_page_option.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/nano/nano.dart';
import 'package:cake_wallet/ionia/ionia_anypay.dart';
import 'package:cake_wallet/ionia/ionia_gift_card.dart';
import 'package:cake_wallet/ionia/ionia_tip.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/anonpay_details/anonpay_details_page.dart';
import 'package:cake_wallet/src/screens/buy/buy_options_page.dart';
import 'package:cake_wallet/src/screens/buy/webview_page.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_dashboard_page.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_sidebar_wrapper.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_wallet_selection_dropdown.dart';
import 'package:cake_wallet/src/screens/dashboard/edit_token_page.dart';
import 'package:cake_wallet/src/screens/dashboard/home_settings_page.dart';
import 'package:cake_wallet/src/screens/exchange/exchange_options_page.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/transactions_page.dart';
import 'package:cake_wallet/src/screens/nano/nano_change_rep_page.dart';
import 'package:cake_wallet/src/screens/nano_accounts/nano_account_edit_or_create_page.dart';
import 'package:cake_wallet/src/screens/nano_accounts/nano_account_list_page.dart';
import 'package:cake_wallet/src/screens/nodes/pow_node_create_or_edit_page.dart';
import 'package:cake_wallet/src/screens/receive/anonpay_invoice_page.dart';
import 'package:cake_wallet/src/screens/receive/anonpay_receive_page.dart';
import 'package:cake_wallet/src/screens/restore/wallet_restore_choose_derivation.dart';
import 'package:cake_wallet/src/screens/settings/display_settings_page.dart';
import 'package:cake_wallet/src/screens/settings/domain_lookups_page.dart';
import 'package:cake_wallet/src/screens/settings/manage_nodes_page.dart';
import 'package:cake_wallet/src/screens/settings/other_settings_page.dart';
import 'package:cake_wallet/src/screens/settings/privacy_page.dart';
import 'package:cake_wallet/src/screens/settings/security_backup_page.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_custom_redeem_page.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_gift_card_detail_page.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_more_options_page.dart';
import 'package:cake_wallet/src/screens/settings/connection_sync_page.dart';
import 'package:cake_wallet/src/screens/settings/trocador_providers_page.dart';
import 'package:cake_wallet/src/screens/settings/tor_page.dart';
import 'package:cake_wallet/src/screens/setup_2fa/modify_2fa_page.dart';
import 'package:cake_wallet/src/screens/setup_2fa/setup_2fa_qr_page.dart';
import 'package:cake_wallet/src/screens/setup_2fa/setup_2fa.dart';
import 'package:cake_wallet/src/screens/setup_2fa/setup_2fa_enter_code_page.dart';
import 'package:cake_wallet/src/screens/support_chat/support_chat_page.dart';
import 'package:cake_wallet/src/screens/support_other_links/support_other_links_page.dart';
import 'package:cake_wallet/src/screens/wallet/wallet_edit_page.dart';
import 'package:cake_wallet/src/screens/wallet_connect/wc_connections_listing_view.dart';
import 'package:cake_wallet/themes/theme_list.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/store/anonpay/anonpay_transactions_store.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/dashboard/desktop_sidebar_view_model.dart';
import 'package:cake_wallet/view_model/anon_invoice_page_view_model.dart';
import 'package:cake_wallet/view_model/anonpay_details_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/home_settings_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/market_place_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/nft_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/receive_option_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_auth_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_buy_card_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_custom_tip_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_custom_redeem_view_model.dart';
import 'package:cake_wallet/ionia/ionia_service.dart';
import 'package:cake_wallet/ionia/ionia_api.dart';
import 'package:cake_wallet/ionia/ionia_merchant.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_account_cards_page.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_account_page.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_custom_tip_page.dart';
import 'package:cake_wallet/src/screens/ionia/ionia.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/balance_page.dart';
import 'package:cake_wallet/view_model/ionia/ionia_account_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_gift_cards_list_view_model.dart';
import 'package:cake_wallet/view_model/ionia/ionia_purchase_merch_view_model.dart';
import 'package:cake_wallet/view_model/nano_account_list/nano_account_edit_or_create_view_model.dart';
import 'package:cake_wallet/view_model/nano_account_list/nano_account_list_view_model.dart';
import 'package:cake_wallet/view_model/node_list/pow_node_list_view_model.dart';
import 'package:cake_wallet/view_model/set_up_2fa_viewmodel.dart';
import 'package:cake_wallet/view_model/restore/restore_from_qr_vm.dart';
import 'package:cake_wallet/view_model/settings/display_settings_view_model.dart';
import 'package:cake_wallet/view_model/settings/other_settings_view_model.dart';
import 'package:cake_wallet/view_model/settings/privacy_settings_view_model.dart';
import 'package:cake_wallet/view_model/settings/security_settings_view_model.dart';
import 'package:cake_wallet/view_model/advanced_privacy_settings_view_model.dart';
import 'package:cake_wallet/view_model/settings/trocador_providers_view_model.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_edit_view_model.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_restore_choose_derivation_view_model.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/nano_account.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cake_wallet/core/backup_service.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cake_wallet/entities/biometric_auth.dart';
import 'package:cake_wallet/entities/contact_record.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cake_wallet/entities/transaction_description.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cw_core/node.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/reactions/on_authentication_state_change.dart';
import 'package:cake_wallet/src/screens/backup/backup_page.dart';
import 'package:cake_wallet/src/screens/backup/edit_backup_password_page.dart';
import 'package:cake_wallet/src/screens/buy/buy_webview_page.dart';
import 'package:cake_wallet/src/screens/contact/contact_list_page.dart';
import 'package:cake_wallet/src/screens/contact/contact_page.dart';
import 'package:cake_wallet/src/screens/exchange_trade/exchange_confirm_page.dart';
import 'package:cake_wallet/src/screens/exchange_trade/exchange_trade_page.dart';
import 'package:cake_wallet/src/screens/faq/faq_page.dart';
import 'package:cake_wallet/src/screens/new_wallet/new_wallet_type_page.dart';
import 'package:cake_wallet/src/screens/nodes/node_create_or_edit_page.dart';
import 'package:cake_wallet/src/screens/order_details/order_details_page.dart';
import 'package:cake_wallet/src/screens/pin_code/pin_code_widget.dart';
import 'package:cake_wallet/src/screens/rescan/rescan_page.dart';
import 'package:cake_wallet/src/screens/restore/restore_from_backup_page.dart';
import 'package:cake_wallet/src/screens/restore/restore_options_page.dart';
import 'package:cake_wallet/src/screens/restore/wallet_restore_page.dart';
import 'package:cake_wallet/src/screens/seed/pre_seed_page.dart';
import 'package:cake_wallet/src/screens/seed/wallet_seed_page.dart';
import 'package:cake_wallet/src/screens/send/send_template_page.dart';
import 'package:cake_wallet/src/screens/setup_pin_code/setup_pin_code.dart';
import 'package:cake_wallet/src/screens/support/support_page.dart';
import 'package:cake_wallet/src/screens/trade_details/trade_details_page.dart';
import 'package:cake_wallet/src/screens/transaction_details/transaction_details_page.dart';
import 'package:cake_wallet/src/screens/unspent_coins/unspent_coins_details_page.dart';
import 'package:cake_wallet/src/screens/unspent_coins/unspent_coins_list_page.dart';
import 'package:cake_wallet/src/screens/wallet_keys/wallet_keys_page.dart';
import 'package:cake_wallet/src/screens/exchange/exchange_page.dart';
import 'package:cake_wallet/src/screens/exchange/exchange_template_page.dart';
import 'package:cake_wallet/store/dashboard/orders_store.dart';
import 'package:cake_wallet/store/node_list_store.dart';
import 'package:cake_wallet/store/secret_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/core/key_service.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cake_wallet/src/screens/monero_accounts/monero_account_list_page.dart';
import 'package:cake_wallet/src/screens/monero_accounts/monero_account_edit_or_create_page.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/src/screens/dashboard/dashboard_page.dart';
import 'package:cake_wallet/src/screens/receive/receive_page.dart';
import 'package:cake_wallet/src/screens/send/send_page.dart';
import 'package:cake_wallet/src/screens/subaddress/address_edit_or_create_page.dart';
import 'package:cake_wallet/src/screens/wallet_list/wallet_list_page.dart';
import 'package:cake_wallet/store/wallet_list_store.dart';
import 'package:cake_wallet/store/yat/yat_store.dart';
import 'package:cake_wallet/view_model/backup_view_model.dart';
import 'package:cake_wallet/view_model/buy/buy_amount_view_model.dart';
import 'package:cake_wallet/view_model/buy/buy_view_model.dart';
import 'package:cake_wallet/view_model/contact_list/contact_list_view_model.dart';
import 'package:cake_wallet/view_model/contact_list/contact_view_model.dart';
import 'package:cake_wallet/view_model/edit_backup_password_view_model.dart';
import 'package:cake_wallet/view_model/exchange/exchange_trade_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/account_list_item.dart';
import 'package:cake_wallet/view_model/node_list/node_list_view_model.dart';
import 'package:cake_wallet/view_model/node_list/node_create_or_edit_view_model.dart';
import 'package:cake_wallet/view_model/order_details_view_model.dart';
import 'package:cake_wallet/view_model/rescan_view_model.dart';
import 'package:cake_wallet/view_model/restore_from_backup_view_model.dart';
import 'package:cake_wallet/view_model/send/send_template_view_model.dart';
import 'package:cake_wallet/view_model/setup_pin_code_view_model.dart';
import 'package:cake_wallet/view_model/support_view_model.dart';
import 'package:cake_wallet/view_model/transaction_details_view_model.dart';
import 'package:cake_wallet/view_model/trade_details_view_model.dart';
import 'package:cake_wallet/view_model/unspent_coins/unspent_coins_details_view_model.dart';
import 'package:cake_wallet/view_model/unspent_coins/unspent_coins_item.dart';
import 'package:cake_wallet/view_model/unspent_coins/unspent_coins_list_view_model.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_edit_or_create_view_model.dart';
import 'package:cake_wallet/view_model/auth_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_edit_or_create_view_model.dart';
import 'package:cake_wallet/view_model/monero_account_list/monero_account_list_view_model.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:cake_wallet/view_model/wallet_keys_view_model.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cake_wallet/view_model/wallet_restore_view_model.dart';
import 'package:cake_wallet/view_model/wallet_seed_view_model.dart';
import 'package:cake_wallet/view_model/exchange/exchange_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cake_wallet/core/wallet_creation_service.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/view_model/wallet_new_vm.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cake_wallet/store/dashboard/trade_filter_store.dart';
import 'package:cake_wallet/store/dashboard/transaction_filter_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/templates/send_template_store.dart';
import 'package:cake_wallet/store/templates/exchange_template_store.dart';
import 'package:cake_wallet/entities/template.dart';
import 'package:cake_wallet/exchange/exchange_template.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/src/screens/dashboard/pages/address_page.dart';
import 'package:cake_wallet/anypay/anypay_api.dart';
import 'package:cake_wallet/view_model/ionia/ionia_gift_card_details_view_model.dart';
import 'package:cake_wallet/src/screens/ionia/cards/ionia_payment_status_page.dart';
import 'package:cake_wallet/view_model/ionia/ionia_payment_status_view_model.dart';
import 'package:cake_wallet/anypay/any_pay_payment_committed_info.dart';
import 'package:cake_wallet/ionia/ionia_any_pay_payment_info.dart';
import 'package:cake_wallet/src/screens/receive/fullscreen_qr_page.dart';
import 'package:cake_wallet/core/wallet_loading_service.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/entities/qr_view_data.dart';

import 'core/totp_request_details.dart';
import 'src/screens/settings/desktop_settings/desktop_settings_page.dart';

final getIt = GetIt.instance;

var _isSetupFinished = false;
late Box<WalletInfo> _walletInfoSource;
late Box<Node> _nodeSource;
late Box<Node> _powNodeSource;
late Box<Contact> _contactSource;
late Box<Trade> _tradesSource;
late Box<Template> _templates;
late Box<ExchangeTemplate> _exchangeTemplates;
late Box<TransactionDescription> _transactionDescriptionBox;
late Box<Order> _ordersSource;
late Box<UnspentCoinsInfo> _unspentCoinsInfoSource;
late Box<AnonpayInvoiceInfo> _anonpayInvoiceInfoSource;

Future<void> setup({
  required Box<WalletInfo> walletInfoSource,
  required Box<Node> nodeSource,
  required Box<Node> powNodeSource,
  required Box<Contact> contactSource,
  required Box<Trade> tradesSource,
  required Box<Template> templates,
  required Box<ExchangeTemplate> exchangeTemplates,
  required Box<TransactionDescription> transactionDescriptionBox,
  required Box<Order> ordersSource,
  required Box<UnspentCoinsInfo> unspentCoinsInfoSource,
  required Box<AnonpayInvoiceInfo> anonpayInvoiceInfoSource,
  required FlutterSecureStorage secureStorage,
}) async {
  _walletInfoSource = walletInfoSource;
  _nodeSource = nodeSource;
  _powNodeSource = powNodeSource;
  _contactSource = contactSource;
  _tradesSource = tradesSource;
  _templates = templates;
  _exchangeTemplates = exchangeTemplates;
  _transactionDescriptionBox = transactionDescriptionBox;
  _ordersSource = ordersSource;
  _unspentCoinsInfoSource = unspentCoinsInfoSource;
  _anonpayInvoiceInfoSource = anonpayInvoiceInfoSource;

  if (!_isSetupFinished) {
    getIt.registerSingletonAsync<SharedPreferences>(() => SharedPreferences.getInstance());
  }
  if (!_isSetupFinished) {
    getIt.registerFactory(() => BackgroundTasks());
  }

  final isBitcoinBuyEnabled = (secrets.wyreSecretKey.isNotEmpty) &&
      (secrets.wyreApiKey.isNotEmpty) &&
      (secrets.wyreAccountId.isNotEmpty);

  final settingsStore = await SettingsStoreBase.load(
    nodeSource: _nodeSource,
    powNodeSource: _powNodeSource,
    isBitcoinBuyEnabled: isBitcoinBuyEnabled,
    // Enforce darkTheme on platforms other than mobile till the design for other themes is completed
    initialTheme: responsiveLayoutUtil.shouldRenderMobileUI && DeviceInfo.instance.isMobile
        ? null
        : ThemeList.darkTheme,
  );

  if (_isSetupFinished) {
    return;
  }

  getIt.registerFactory<Box<Node>>(() => _nodeSource);
  getIt.registerFactory<Box<Node>>(() => _powNodeSource, instanceName: Node.boxName + "pow");

  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);
  getIt.registerSingleton(AuthenticationStore());
  getIt.registerSingleton<WalletListStore>(WalletListStore());
  getIt.registerSingleton(NodeListStoreBase.instance);
  getIt.registerSingleton<SettingsStore>(settingsStore);
  getIt.registerSingleton<AppStore>(AppStore(
      authenticationStore: getIt.get<AuthenticationStore>(),
      walletList: getIt.get<WalletListStore>(),
      settingsStore: getIt.get<SettingsStore>(),
      nodeListStore: getIt.get<NodeListStore>()));
  getIt.registerSingleton<TradesStore>(
      TradesStore(tradesSource: _tradesSource, settingsStore: getIt.get<SettingsStore>()));
  getIt.registerSingleton<OrdersStore>(
      OrdersStore(ordersSource: _ordersSource, settingsStore: getIt.get<SettingsStore>()));
  getIt.registerSingleton<TradeFilterStore>(TradeFilterStore());
  getIt.registerSingleton<TransactionFilterStore>(TransactionFilterStore());
  getIt.registerSingleton<FiatConversionStore>(FiatConversionStore());
  getIt.registerSingleton<SendTemplateStore>(SendTemplateStore(templateSource: _templates));
  getIt.registerSingleton<ExchangeTemplateStore>(
      ExchangeTemplateStore(templateSource: _exchangeTemplates));
  getIt.registerSingleton<YatStore>(
      YatStore(appStore: getIt.get<AppStore>(), secureStorage: getIt.get<FlutterSecureStorage>())
        ..init());
  getIt.registerSingleton<AnonpayTransactionsStore>(
      AnonpayTransactionsStore(anonpayInvoiceInfoSource: _anonpayInvoiceInfoSource));

  final secretStore = await SecretStoreBase.load(getIt.get<FlutterSecureStorage>());

  getIt.registerSingleton<SecretStore>(secretStore);

  getIt.registerFactory<KeyService>(() => KeyService(getIt.get<FlutterSecureStorage>()));

  getIt.registerFactoryParam<WalletCreationService, WalletType, void>((type, _) =>
      WalletCreationService(
          initialType: type,
          keyService: getIt.get<KeyService>(),
          secureStorage: getIt.get<FlutterSecureStorage>(),
          sharedPreferences: getIt.get<SharedPreferences>(),
          settingsStore: getIt.get<SettingsStore>(),
          walletInfoSource: _walletInfoSource));

  getIt.registerFactory<WalletLoadingService>(() => WalletLoadingService(
      getIt.get<SharedPreferences>(),
      getIt.get<KeyService>(),
      (WalletType type) => getIt.get<WalletService>(param1: type)));

  getIt.registerFactoryParam<WalletNewVM, WalletType, void>((type, _) => WalletNewVM(
      getIt.get<AppStore>(), getIt.get<WalletCreationService>(param1: type), _walletInfoSource,
      type: type));

  getIt.registerFactoryParam<WalletRestorationFromQRVM, WalletType, void>((WalletType type, _) {
    return WalletRestorationFromQRVM(getIt.get<AppStore>(),
        getIt.get<WalletCreationService>(param1: type), _walletInfoSource, type);
  });

  getIt.registerFactory<WalletAddressListViewModel>(() => WalletAddressListViewModel(
      appStore: getIt.get<AppStore>(),
      yatStore: getIt.get<YatStore>(),
      fiatConversionStore: getIt.get<FiatConversionStore>()));

  getIt.registerFactory(() => BalanceViewModel(
      appStore: getIt.get<AppStore>(),
      settingsStore: getIt.get<SettingsStore>(),
      fiatConvertationStore: getIt.get<FiatConversionStore>()));

  getIt.registerFactory(() => DashboardViewModel(
      balanceViewModel: getIt.get<BalanceViewModel>(),
      appStore: getIt.get<AppStore>(),
      tradesStore: getIt.get<TradesStore>(),
      tradeFilterStore: getIt.get<TradeFilterStore>(),
      transactionFilterStore: getIt.get<TransactionFilterStore>(),
      settingsStore: settingsStore,
      yatStore: getIt.get<YatStore>(),
      ordersStore: getIt.get<OrdersStore>(),
      anonpayTransactionsStore: getIt.get<AnonpayTransactionsStore>()));

  getIt.registerFactory<AuthService>(
    () => AuthService(
      secureStorage: getIt.get<FlutterSecureStorage>(),
      sharedPreferences: getIt.get<SharedPreferences>(),
      settingsStore: getIt.get<SettingsStore>(),
    ),
  );

  getIt.registerFactory<AuthViewModel>(() => AuthViewModel(getIt.get<AuthService>(),
      getIt.get<SharedPreferences>(), getIt.get<SettingsStore>(), BiometricAuth()));

  getIt.registerFactoryParam<AuthPage, void Function(bool, AuthPageState), bool>(
      (onAuthFinished, closable) => AuthPage(getIt.get<AuthViewModel>(),
          onAuthenticationFinished: onAuthFinished, closable: closable));

  getIt.registerLazySingleton<Setup2FAViewModel>(
    () => Setup2FAViewModel(
      getIt.get<SettingsStore>(),
      getIt.get<SharedPreferences>(),
      getIt.get<AuthService>(),
    ),
  );

  getIt.registerFactoryParam<TotpAuthCodePage, TotpAuthArgumentsModel, void>(
    (totpAuthPageArguments, _) => TotpAuthCodePage(
      getIt.get<Setup2FAViewModel>(),
      totpArguments: totpAuthPageArguments,
    ),
  );

  getIt.registerFactory<AuthPage>(() {
    return AuthPage(getIt.get<AuthViewModel>(),
        onAuthenticationFinished: (isAuthenticated, AuthPageState authPageState) {
      if (!isAuthenticated) {
        return;
      } else {
        final authStore = getIt.get<AuthenticationStore>();
        final appStore = getIt.get<AppStore>();
        final useTotp = appStore.settingsStore.useTOTP2FA;
        final shouldUseTotp2FAToAccessWallets =
            appStore.settingsStore.shouldRequireTOTP2FAForAccessingWallet;
        if (useTotp && shouldUseTotp2FAToAccessWallets) {
          authPageState.close(
            route: Routes.totpAuthCodePage,
            arguments: TotpAuthArgumentsModel(
              isForSetup: false,
              isClosable: false,
              onTotpAuthenticationFinished: (bool isAuthenticatedSuccessfully,
                  TotpAuthCodePageState totpAuthPageState) async {
                if (!isAuthenticatedSuccessfully) {
                  return;
                }
                if (appStore.wallet != null) {
                  authStore.allowed();
                  return;
                }

                totpAuthPageState.changeProcessText('Loading the wallet');

                if (loginError != null) {
                  totpAuthPageState.changeProcessText('ERROR: ${loginError.toString()}');
                }

                ReactionDisposer? _reaction;
                _reaction = reaction((_) => appStore.wallet, (Object? _) {
                  _reaction?.reaction.dispose();
                  authStore.allowed();
                });
              },
            ),
          );
        } else {
          if (appStore.wallet != null) {
            authStore.allowed();
            return;
          }

          authPageState.changeProcessText('Loading the wallet');

          if (loginError != null) {
            authPageState.changeProcessText('ERROR: ${loginError.toString()}');
          }

          ReactionDisposer? _reaction;
          _reaction = reaction((_) => appStore.wallet, (Object? _) {
            _reaction?.reaction.dispose();
            authStore.allowed();
          });
        }
      }
    }, closable: false);
  }, instanceName: 'login');

  getIt.registerSingleton<BottomSheetService>(BottomSheetServiceImpl());

  final appStore = getIt.get<AppStore>();

  getIt.registerLazySingleton<WalletConnectKeyService>(() => KeyServiceImpl(appStore.wallet!));

  getIt.registerLazySingleton<Web3WalletService>(() {
    final Web3WalletService web3WalletService = Web3WalletService(
      getIt.get<BottomSheetService>(),
      getIt.get<WalletConnectKeyService>(),
      appStore,
    );
    web3WalletService.create();
    return web3WalletService;
  });

  getIt.registerFactory(() => BalancePage(
      nftViewModel: getIt.get<NFTViewModel>(),
      dashboardViewModel: getIt.get<DashboardViewModel>(),
      settingsStore: getIt.get<SettingsStore>()));

  getIt.registerFactory<DashboardPage>(() => DashboardPage(
        bottomSheetService: getIt.get<BottomSheetService>(),
        balancePage: getIt.get<BalancePage>(),
        dashboardViewModel: getIt.get<DashboardViewModel>(),
        addressListViewModel: getIt.get<WalletAddressListViewModel>(),
      ));

  getIt.registerFactory<DesktopSidebarWrapper>(() {
    final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
    return DesktopSidebarWrapper(
      bottomSheetService: getIt.get<BottomSheetService>(),
      dashboardViewModel: getIt.get<DashboardViewModel>(),
      desktopSidebarViewModel: getIt.get<DesktopSidebarViewModel>(),
      child: getIt.get<DesktopDashboardPage>(param1: _navigatorKey),
      desktopNavigatorKey: _navigatorKey,
    );
  });
  getIt.registerFactoryParam<DesktopDashboardPage, GlobalKey<NavigatorState>, void>(
      (desktopKey, _) => DesktopDashboardPage(
            balancePage: getIt.get<BalancePage>(),
            dashboardViewModel: getIt.get<DashboardViewModel>(),
            addressListViewModel: getIt.get<WalletAddressListViewModel>(),
            desktopKey: desktopKey,
          ));

  getIt.registerFactory<TransactionsPage>(
      () => TransactionsPage(dashboardViewModel: getIt.get<DashboardViewModel>()));

  getIt.registerFactory<Setup2FAPage>(
      () => Setup2FAPage(setup2FAViewModel: getIt.get<Setup2FAViewModel>()));

  getIt.registerFactory<Setup2FAQRPage>(
      () => Setup2FAQRPage(setup2FAViewModel: getIt.get<Setup2FAViewModel>()));

  getIt.registerFactory<Modify2FAPage>(
      () => Modify2FAPage(setup2FAViewModel: getIt.get<Setup2FAViewModel>()));

  getIt.registerFactory<DesktopSettingsPage>(() => DesktopSettingsPage());

  getIt.registerFactoryParam<ReceiveOptionViewModel, ReceivePageOption?, void>(
      (pageOption, _) => ReceiveOptionViewModel(getIt.get<AppStore>().wallet!, pageOption));

  getIt.registerFactoryParam<AnonInvoicePageViewModel, List<dynamic>, void>((args, _) {
    final address = args.first as String;
    final pageOption = args.last as ReceivePageOption;
    return AnonInvoicePageViewModel(
      getIt.get<AnonPayApi>(),
      address,
      getIt.get<SettingsStore>(),
      getIt.get<AppStore>().wallet!,
      _anonpayInvoiceInfoSource,
      getIt.get<SharedPreferences>(),
      pageOption,
    );
  });

  getIt.registerFactoryParam<AnonPayInvoicePage, List<dynamic>, void>((List<dynamic> args, _) {
    final pageOption = args.last as ReceivePageOption;
    return AnonPayInvoicePage(getIt.get<AnonInvoicePageViewModel>(param1: args),
        getIt.get<ReceiveOptionViewModel>(param1: pageOption));
  });

  getIt.registerFactory<ReceivePage>(
      () => ReceivePage(addressListViewModel: getIt.get<WalletAddressListViewModel>()));
  getIt.registerFactory<AddressPage>(() => AddressPage(
      addressListViewModel: getIt.get<WalletAddressListViewModel>(),
      dashboardViewModel: getIt.get<DashboardViewModel>(),
      receiveOptionViewModel: getIt.get<ReceiveOptionViewModel>()));

  getIt.registerFactoryParam<WalletAddressEditOrCreateViewModel, WalletAddressListItem?, void>(
      (WalletAddressListItem? item, _) =>
          WalletAddressEditOrCreateViewModel(wallet: getIt.get<AppStore>().wallet!, item: item));

  getIt.registerFactoryParam<AddressEditOrCreatePage, dynamic, void>((dynamic item, _) =>
      AddressEditOrCreatePage(
          addressEditOrCreateViewModel:
              getIt.get<WalletAddressEditOrCreateViewModel>(param1: item)));

  getIt.registerFactory<SendTemplateViewModel>(() => SendTemplateViewModel(
      getIt.get<AppStore>().wallet!,
      getIt.get<AppStore>().settingsStore,
      getIt.get<SendTemplateStore>(),
      getIt.get<FiatConversionStore>()));

  getIt.registerFactory<SendViewModel>(
    () => SendViewModel(
      getIt.get<AppStore>(),
      getIt.get<SendTemplateViewModel>(),
      getIt.get<FiatConversionStore>(),
      getIt.get<BalanceViewModel>(),
      getIt.get<ContactListViewModel>(),
      _transactionDescriptionBox,
    ),
  );

  getIt.registerFactoryParam<SendPage, PaymentRequest?, void>(
      (PaymentRequest? initialPaymentRequest, _) => SendPage(
            sendViewModel: getIt.get<SendViewModel>(),
            authService: getIt.get<AuthService>(),
            initialPaymentRequest: initialPaymentRequest,
          ));

  getIt.registerFactory(
      () => SendTemplatePage(sendTemplateViewModel: getIt.get<SendTemplateViewModel>()));

  if (DeviceInfo.instance.isMobile) {
    getIt.registerFactory(
      () => WalletListViewModel(
        _walletInfoSource,
        getIt.get<AppStore>(),
        getIt.get<WalletLoadingService>(),
        getIt.get<AuthService>(),
      ),
    );
  } else {
    // register wallet list view model as singleton on desktop since it can be accessed
    // from multiple places at the same time (Wallets DropDown, Wallets List in settings)
    getIt.registerLazySingleton(
      () => WalletListViewModel(
        _walletInfoSource,
        getIt.get<AppStore>(),
        getIt.get<WalletLoadingService>(),
        getIt.get<AuthService>(),
      ),
    );
  }

  getIt.registerFactory(() => WalletListPage(
        walletListViewModel: getIt.get<WalletListViewModel>(),
        authService: getIt.get<AuthService>(),
      ));

  getIt.registerFactoryParam<WalletEditViewModel, WalletListViewModel, void>(
      (WalletListViewModel walletListViewModel, _) =>
          WalletEditViewModel(walletListViewModel, getIt.get<WalletLoadingService>()));

  getIt.registerFactoryParam<WalletEditPage, List<dynamic>, void>((args, _) {
    final walletListViewModel = args.first as WalletListViewModel;
    final editingWallet = args.last as WalletListItem;
    return WalletEditPage(
        walletEditViewModel: getIt.get<WalletEditViewModel>(param1: walletListViewModel),
        authService: getIt.get<AuthService>(),
        walletNewVM: getIt.get<WalletNewVM>(param1: editingWallet.type),
        editingWallet: editingWallet);
  });

  getIt.registerFactory<NanoAccountListViewModel>(() {
    final wallet = getIt.get<AppStore>().wallet!;
    if (wallet.type == WalletType.nano || wallet.type == WalletType.banano) {
      return NanoAccountListViewModel(wallet);
    }
    throw Exception(
        'Unexpected wallet type: ${wallet.type} for generate Nano/Banano AccountListViewModel');
  });

  getIt.registerFactory<MoneroAccountListViewModel>(() {
    final wallet = getIt.get<AppStore>().wallet!;
    if (wallet.type == WalletType.monero || wallet.type == WalletType.haven) {
      return MoneroAccountListViewModel(wallet);
    }
    throw Exception(
        'Unexpected wallet type: ${wallet.type} for generate Monero AccountListViewModel');
  });

  getIt.registerFactory(
      () => MoneroAccountListPage(accountListViewModel: getIt.get<MoneroAccountListViewModel>()));

  getIt.registerFactory(
      () => NanoAccountListPage(accountListViewModel: getIt.get<NanoAccountListViewModel>()));

  /*getIt.registerFactory(() {
    final wallet = getIt.get<AppStore>().wallet;

    if (wallet is MoneroWallet) {
      return MoneroAccountEditOrCreateViewModel(wallet.accountList);
    }

    // FIXME: throw exception.
    return null;
  });

  getIt.registerFactory(() => MoneroAccountEditOrCreatePage(
      moneroAccountCreationViewModel:
          getIt.get<MoneroAccountEditOrCreateViewModel>()));*/

  getIt.registerFactoryParam<MoneroAccountEditOrCreateViewModel, AccountListItem?, void>(
      (AccountListItem? account, _) => MoneroAccountEditOrCreateViewModel(
          monero!.getAccountList(getIt.get<AppStore>().wallet!),
          haven?.getAccountList(getIt.get<AppStore>().wallet!),
          wallet: getIt.get<AppStore>().wallet!,
          accountListItem: account));

  getIt.registerFactoryParam<MoneroAccountEditOrCreatePage, AccountListItem?, void>(
      (AccountListItem? account, _) => MoneroAccountEditOrCreatePage(
          moneroAccountCreationViewModel:
              getIt.get<MoneroAccountEditOrCreateViewModel>(param1: account)));

  getIt.registerFactoryParam<NanoAccountEditOrCreateViewModel, NanoAccount?, void>(
      (NanoAccount? account, _) =>
          NanoAccountEditOrCreateViewModel(nano!.getAccountList(getIt.get<AppStore>().wallet!),
              // banano?.getAccountList(getIt.get<AppStore>().wallet!),
              wallet: getIt.get<AppStore>().wallet!,
              accountListItem: account));

  getIt.registerFactoryParam<NanoAccountEditOrCreatePage, NanoAccount?, void>(
      (NanoAccount? account, _) => NanoAccountEditOrCreatePage(
          nanoAccountCreationViewModel:
              getIt.get<NanoAccountEditOrCreateViewModel>(param1: account)));

  getIt.registerFactory(() {
    return DisplaySettingsViewModel(getIt.get<SettingsStore>());
  });

  getIt.registerFactory(() {
    return PrivacySettingsViewModel(getIt.get<SettingsStore>(), getIt.get<AppStore>().wallet!);
  });

  getIt.registerFactory(() => TrocadorProvidersViewModel(getIt.get<SettingsStore>()));

  getIt.registerFactory(() {
    return OtherSettingsViewModel(getIt.get<SettingsStore>(), getIt.get<AppStore>().wallet!);
  });

  getIt.registerFactory(() {
    return SecuritySettingsViewModel(getIt.get<SettingsStore>(), getIt.get<AuthService>());
  });

  getIt.registerFactory(() => WalletSeedViewModel(getIt.get<AppStore>().wallet!));

  getIt.registerFactoryParam<WalletSeedPage, bool, void>((bool isWalletCreated, _) =>
      WalletSeedPage(getIt.get<WalletSeedViewModel>(), isNewWalletCreated: isWalletCreated));

  getIt.registerFactory(() => WalletKeysViewModel(getIt.get<AppStore>()));

  getIt.registerFactory(() => WalletKeysPage(getIt.get<WalletKeysViewModel>()));

  getIt.registerFactoryParam<ContactViewModel, ContactRecord?, void>(
      (ContactRecord? contact, _) => ContactViewModel(_contactSource, contact: contact));

  getIt.registerFactoryParam<ContactListViewModel, CryptoCurrency?, void>(
      (CryptoCurrency? cur, _) =>
          ContactListViewModel(_contactSource, _walletInfoSource, cur, getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<ContactListPage, CryptoCurrency?, void>((CryptoCurrency? cur, _) =>
      ContactListPage(getIt.get<ContactListViewModel>(param1: cur), getIt.get<AuthService>()));

  getIt.registerFactoryParam<ContactPage, ContactRecord?, void>(
      (ContactRecord? contact, _) => ContactPage(getIt.get<ContactViewModel>(param1: contact)));

  getIt.registerFactory(() {
    final appStore = getIt.get<AppStore>();
    return NodeListViewModel(_nodeSource, appStore);
  });

  getIt.registerFactory(() {
    final appStore = getIt.get<AppStore>();
    return PowNodeListViewModel(_powNodeSource, appStore);
  });

  getIt.registerFactory(() {
    final wallet = getIt.get<AppStore>().wallet;
    return ConnectionSyncPage(
      getIt.get<DashboardViewModel>(),
      isEVMCompatibleChain(wallet!.type) ? getIt.get<Web3WalletService>() : null,
    );
  });

  getIt.registerFactory(
      () => SecurityBackupPage(getIt.get<SecuritySettingsViewModel>(), getIt.get<AuthService>()));

  getIt.registerFactory(() => PrivacyPage(getIt.get<PrivacySettingsViewModel>()));

  getIt.registerFactory(() => TrocadorProvidersPage(getIt.get<TrocadorProvidersViewModel>()));

  getIt.registerFactory(() => DomainLookupsPage(getIt.get<PrivacySettingsViewModel>()));

  getIt.registerFactory(() => DisplaySettingsPage(getIt.get<DisplaySettingsViewModel>()));

  getIt.registerFactory(() => OtherSettingsPage(getIt.get<OtherSettingsViewModel>()));

  getIt.registerFactory(() => NanoChangeRepPage(
        settingsStore: getIt.get<AppStore>().settingsStore,
        wallet: getIt.get<AppStore>().wallet!,
      ));

  getIt.registerFactoryParam<NodeCreateOrEditViewModel, WalletType?, bool?>(
      (WalletType? type, bool? isPow) => NodeCreateOrEditViewModel(
          (isPow ?? false) ? _powNodeSource : _nodeSource,
          type ?? getIt.get<AppStore>().wallet!.type,
          getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<NodeCreateOrEditPage, Node?, bool?>(
      (Node? editingNode, bool? isSelected) => NodeCreateOrEditPage(
          nodeCreateOrEditViewModel: getIt.get<NodeCreateOrEditViewModel>(param2: false),
          editingNode: editingNode,
          isSelected: isSelected));

  getIt.registerFactoryParam<PowNodeCreateOrEditPage, Node?, bool?>(
      (Node? editingNode, bool? isSelected) => PowNodeCreateOrEditPage(
          nodeCreateOrEditViewModel: getIt.get<NodeCreateOrEditViewModel>(param2: true),
          editingNode: editingNode,
          isSelected: isSelected));

  getIt.registerFactory<RobinhoodBuyProvider>(
      () => RobinhoodBuyProvider(wallet: getIt.get<AppStore>().wallet!));

  getIt.registerFactory<OnRamperBuyProvider>(() => OnRamperBuyProvider(
        settingsStore: getIt.get<AppStore>().settingsStore,
        wallet: getIt.get<AppStore>().wallet!,
      ));

  getIt.registerFactory<MoonPayExchangeProvider>(() => MoonPayExchangeProvider(
        settingsStore: getIt.get<AppStore>().settingsStore,
        wallet: getIt.get<AppStore>().wallet!,
      ));

  getIt.registerFactoryParam<WebViewPage, String, Uri>((title, uri) => WebViewPage(title, uri));

  getIt.registerFactory<PayfuraBuyProvider>(() => PayfuraBuyProvider(
        settingsStore: getIt.get<AppStore>().settingsStore,
        wallet: getIt.get<AppStore>().wallet!,
      ));

  getIt.registerFactory(() => ExchangeViewModel(
      getIt.get<AppStore>(),
      _tradesSource,
      getIt.get<ExchangeTemplateStore>(),
      getIt.get<TradesStore>(),
      getIt.get<AppStore>().settingsStore,
      getIt.get<SharedPreferences>(),
      getIt.get<ContactListViewModel>()));

  getIt.registerFactory(() => ExchangeTradeViewModel(
      wallet: getIt.get<AppStore>().wallet!,
      trades: _tradesSource,
      tradesStore: getIt.get<TradesStore>(),
      sendViewModel: getIt.get<SendViewModel>()));

  getIt.registerFactory(
      () => ExchangePage(getIt.get<ExchangeViewModel>(), getIt.get<AuthService>()));

  getIt.registerFactory(() => ExchangeConfirmPage(tradesStore: getIt.get<TradesStore>()));

  getIt.registerFactory(
      () => ExchangeTradePage(exchangeTradeViewModel: getIt.get<ExchangeTradeViewModel>()));

  getIt.registerFactory(() => ExchangeTemplatePage(getIt.get<ExchangeViewModel>()));

  getIt.registerFactoryParam<WalletService, WalletType, void>((WalletType param1, __) {
    switch (param1) {
      case WalletType.haven:
        return haven!.createHavenWalletService(_walletInfoSource);
      case WalletType.monero:
        return monero!.createMoneroWalletService(_walletInfoSource, _unspentCoinsInfoSource);
      case WalletType.bitcoin:
        return bitcoin!.createBitcoinWalletService(_walletInfoSource, _unspentCoinsInfoSource);
      case WalletType.litecoin:
        return bitcoin!.createLitecoinWalletService(_walletInfoSource, _unspentCoinsInfoSource);
      case WalletType.ethereum:
        return ethereum!.createEthereumWalletService(_walletInfoSource);
      case WalletType.bitcoinCash:
        return bitcoinCash!
            .createBitcoinCashWalletService(_walletInfoSource, _unspentCoinsInfoSource!);
      case WalletType.nano:
        return nano!.createNanoWalletService(_walletInfoSource);
      case WalletType.polygon:
        return polygon!.createPolygonWalletService(_walletInfoSource);
      default:
        throw Exception('Unexpected token: ${param1.toString()} for generating of WalletService');
    }
  });

  getIt.registerFactory<SetupPinCodeViewModel>(
      () => SetupPinCodeViewModel(getIt.get<AuthService>(), getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<SetupPinCodePage, void Function(PinCodeState<PinCodeWidget>, String),
          void>(
      (onSuccessfulPinSetup, _) => SetupPinCodePage(getIt.get<SetupPinCodeViewModel>(),
          onSuccessfulPinSetup: onSuccessfulPinSetup));

  getIt.registerFactory(() => RescanViewModel(getIt.get<AppStore>().wallet!));

  getIt.registerFactory(() => RescanPage(getIt.get<RescanViewModel>()));

  getIt.registerFactory(() => FaqPage(getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<WalletRestoreViewModel, WalletType, void>((type, _) =>
      WalletRestoreViewModel(
          getIt.get<AppStore>(), getIt.get<WalletCreationService>(param1: type), _walletInfoSource,
          type: type));

  getIt.registerFactoryParam<WalletRestorePage, WalletType, void>(
      (type, _) => WalletRestorePage(getIt.get<WalletRestoreViewModel>(param1: type)));

  getIt.registerFactoryParam<WalletRestoreChooseDerivationViewModel, List<DerivationInfo>, void>(
      (derivations, _) => WalletRestoreChooseDerivationViewModel(derivationInfos: derivations));

  getIt.registerFactoryParam<WalletRestoreChooseDerivationPage, List<DerivationInfo>, void>(
      (credentials, _) =>
          WalletRestoreChooseDerivationPage(getIt.get<WalletRestoreChooseDerivationViewModel>(
            param1: credentials,
          )));

  getIt.registerFactoryParam<TransactionDetailsViewModel, TransactionInfo, void>(
      (TransactionInfo transactionInfo, _) {
    final wallet = getIt.get<AppStore>().wallet!;
    return TransactionDetailsViewModel(
        transactionInfo: transactionInfo,
        transactionDescriptionBox: _transactionDescriptionBox,
        wallet: wallet,
        settingsStore: getIt.get<SettingsStore>());
  });

  getIt.registerFactoryParam<TransactionDetailsPage, TransactionInfo, void>(
      (TransactionInfo transactionInfo, _) => TransactionDetailsPage(
          transactionDetailsViewModel:
              getIt.get<TransactionDetailsViewModel>(param1: transactionInfo)));

  getIt.registerFactoryParam<NewWalletTypePage, void Function(BuildContext, WalletType), bool?>(
      (param1, isCreate) => NewWalletTypePage(onTypeSelected: param1, isCreate: isCreate ?? true));

  getIt.registerFactoryParam<PreSeedPage, WalletType, AdvancedPrivacySettingsViewModel>(
      (WalletType type, AdvancedPrivacySettingsViewModel advancedPrivacySettingsViewModel) =>
          PreSeedPage(type, advancedPrivacySettingsViewModel));

  getIt.registerFactoryParam<TradeDetailsViewModel, Trade, void>((trade, _) =>
      TradeDetailsViewModel(
          tradeForDetails: trade,
          trades: _tradesSource,
          settingsStore: getIt.get<SettingsStore>()));

  getIt.registerFactory(() => BackupService(getIt.get<FlutterSecureStorage>(), _walletInfoSource,
      getIt.get<KeyService>(), getIt.get<SharedPreferences>()));

  getIt.registerFactory(() => BackupViewModel(
      getIt.get<FlutterSecureStorage>(), getIt.get<SecretStore>(), getIt.get<BackupService>()));

  getIt.registerFactory(() => BackupPage(getIt.get<BackupViewModel>()));

  getIt.registerFactory(() =>
      EditBackupPasswordViewModel(getIt.get<FlutterSecureStorage>(), getIt.get<SecretStore>()));

  getIt.registerFactory(() => EditBackupPasswordPage(getIt.get<EditBackupPasswordViewModel>()));

  getIt.registerFactoryParam<RestoreOptionsPage, bool, void>(
      (bool isNewInstall, _) => RestoreOptionsPage(isNewInstall: isNewInstall));

  getIt.registerFactory(() => RestoreFromBackupViewModel(getIt.get<BackupService>()));

  getIt.registerFactory(() => RestoreFromBackupPage(getIt.get<RestoreFromBackupViewModel>()));

  getIt.registerFactoryParam<TradeDetailsPage, Trade, void>(
      (Trade trade, _) => TradeDetailsPage(getIt.get<TradeDetailsViewModel>(param1: trade)));

  getIt.registerFactory(() => BuyAmountViewModel());

  getIt.registerFactory(() => BuyOptionsPage());

  getIt.registerFactory(() => ExchangeOptionsPage());

  getIt.registerFactory(() {
    final wallet = getIt.get<AppStore>().wallet;

    return BuyViewModel(_ordersSource, getIt.get<OrdersStore>(), getIt.get<SettingsStore>(),
        getIt.get<BuyAmountViewModel>(),
        wallet: wallet!);
  });

  getIt.registerFactoryParam<BuyWebViewPage, List<dynamic>, void>((List<dynamic> args, _) {
    final url = args.first as String;
    final buyViewModel = args[1] as BuyViewModel;

    return BuyWebViewPage(
        buyViewModel: buyViewModel, ordersStore: getIt.get<OrdersStore>(), url: url);
  });

  getIt.registerFactoryParam<OrderDetailsViewModel, Order, void>((order, _) {
    final wallet = getIt.get<AppStore>().wallet;

    return OrderDetailsViewModel(wallet: wallet!, orderForDetails: order);
  });

  getIt.registerFactoryParam<OrderDetailsPage, Order, void>(
      (Order order, _) => OrderDetailsPage(getIt.get<OrderDetailsViewModel>(param1: order)));

  getIt.registerFactory(() => SupportViewModel());

  getIt.registerFactory(() => SupportPage(getIt.get<SupportViewModel>()));

  getIt.registerFactory(() => SupportChatPage(getIt.get<SupportViewModel>(),
      secureStorage: getIt.get<FlutterSecureStorage>()));

  getIt.registerFactory(() => SupportOtherLinksPage(getIt.get<SupportViewModel>()));

  getIt.registerFactory(() {
    final wallet = getIt.get<AppStore>().wallet;

    return UnspentCoinsListViewModel(wallet: wallet!, unspentCoinsInfo: _unspentCoinsInfoSource);
  });

  getIt.registerFactory(() =>
      UnspentCoinsListPage(unspentCoinsListViewModel: getIt.get<UnspentCoinsListViewModel>()));

  getIt.registerFactoryParam<UnspentCoinsDetailsViewModel, UnspentCoinsItem,
          UnspentCoinsListViewModel>(
      (item, model) =>
          UnspentCoinsDetailsViewModel(unspentCoinsItem: item, unspentCoinsListViewModel: model));

  getIt.registerFactoryParam<UnspentCoinsDetailsPage, List<dynamic>, void>((List<dynamic> args, _) {
    final item = args.first as UnspentCoinsItem;
    final unspentCoinsListViewModel = args[1] as UnspentCoinsListViewModel;

    return UnspentCoinsDetailsPage(
        unspentCoinsDetailsViewModel: getIt.get<UnspentCoinsDetailsViewModel>(
            param1: item, param2: unspentCoinsListViewModel));
  });

  getIt.registerFactory(() => YatService());

  getIt.registerFactory(() => AddressResolver(
      yatService: getIt.get<YatService>(),
      wallet: getIt.get<AppStore>().wallet!,
      settingsStore: getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<FullscreenQRPage, QrViewData, void>(
      (QrViewData viewData, _) => FullscreenQRPage(qrViewData: viewData));

  getIt.registerFactory(() => IoniaApi());

  getIt.registerFactory(() => AnyPayApi());

  getIt.registerFactory<IoniaService>(
      () => IoniaService(getIt.get<FlutterSecureStorage>(), getIt.get<IoniaApi>()));

  getIt.registerFactory<IoniaAnyPay>(() => IoniaAnyPay(
      getIt.get<IoniaService>(), getIt.get<AnyPayApi>(), getIt.get<AppStore>().wallet!));

  getIt.registerFactory(() => IoniaGiftCardsListViewModel(ioniaService: getIt.get<IoniaService>()));

  getIt.registerFactory(() => MarketPlaceViewModel(getIt.get<IoniaService>()));

  getIt.registerFactory(() => IoniaAuthViewModel(ioniaService: getIt.get<IoniaService>()));

  getIt.registerFactoryParam<IoniaMerchPurchaseViewModel, double, IoniaMerchant>(
      (double amount, merchant) {
    return IoniaMerchPurchaseViewModel(
        ioniaAnyPayService: getIt.get<IoniaAnyPay>(),
        amount: amount,
        ioniaMerchant: merchant,
        sendViewModel: getIt.get<SendViewModel>());
  });

  getIt.registerFactoryParam<IoniaBuyCardViewModel, IoniaMerchant, void>(
      (IoniaMerchant merchant, _) {
    return IoniaBuyCardViewModel(ioniaMerchant: merchant);
  });

  getIt.registerFactory(() => IoniaAccountViewModel(ioniaService: getIt.get<IoniaService>()));

  getIt.registerFactory(() => IoniaCreateAccountPage(getIt.get<IoniaAuthViewModel>()));

  getIt.registerFactory(() => IoniaLoginPage(getIt.get<IoniaAuthViewModel>()));

  getIt.registerFactoryParam<IoniaVerifyIoniaOtp, List<dynamic>, void>((List<dynamic> args, _) {
    final email = args.first as String;
    final isSignIn = args[1] as bool;

    return IoniaVerifyIoniaOtp(getIt.get<IoniaAuthViewModel>(), email, isSignIn);
  });

  getIt.registerFactory(() => IoniaWelcomePage());

  getIt.registerFactoryParam<IoniaBuyGiftCardPage, List<dynamic>, void>((List<dynamic> args, _) {
    final merchant = args.first as IoniaMerchant;

    return IoniaBuyGiftCardPage(getIt.get<IoniaBuyCardViewModel>(param1: merchant));
  });

  getIt.registerFactoryParam<IoniaBuyGiftCardDetailPage, List<dynamic>, void>(
      (List<dynamic> args, _) {
    final amount = args.first as double;
    final merchant = args.last as IoniaMerchant;
    return IoniaBuyGiftCardDetailPage(
        getIt.get<IoniaMerchPurchaseViewModel>(param1: amount, param2: merchant));
  });

  getIt.registerFactoryParam<IoniaGiftCardDetailsViewModel, IoniaGiftCard, void>(
      (IoniaGiftCard giftCard, _) {
    return IoniaGiftCardDetailsViewModel(
        ioniaService: getIt.get<IoniaService>(), giftCard: giftCard);
  });

  getIt.registerFactoryParam<IoniaCustomTipViewModel, List<dynamic>, void>((List<dynamic> args, _) {
    final amount = args[0] as double;
    final merchant = args[1] as IoniaMerchant;
    final tip = args[2] as IoniaTip;

    return IoniaCustomTipViewModel(amount: amount, tip: tip, ioniaMerchant: merchant);
  });

  getIt.registerFactoryParam<IoniaGiftCardDetailPage, IoniaGiftCard, void>(
      (IoniaGiftCard giftCard, _) {
    return IoniaGiftCardDetailPage(getIt.get<IoniaGiftCardDetailsViewModel>(param1: giftCard));
  });

  getIt.registerFactoryParam<IoniaMoreOptionsPage, List<dynamic>, void>((List<dynamic> args, _) {
    final giftCard = args.first as IoniaGiftCard;

    return IoniaMoreOptionsPage(giftCard);
  });

  getIt.registerFactoryParam<IoniaCustomRedeemViewModel, IoniaGiftCard, void>(
      (IoniaGiftCard giftCard, _) =>
          IoniaCustomRedeemViewModel(giftCard: giftCard, ioniaService: getIt.get<IoniaService>()));

  getIt.registerFactoryParam<IoniaCustomRedeemPage, List<dynamic>, void>((List<dynamic> args, _) {
    final giftCard = args.first as IoniaGiftCard;

    return IoniaCustomRedeemPage(getIt.get<IoniaCustomRedeemViewModel>(param1: giftCard));
  });

  getIt.registerFactoryParam<IoniaCustomTipPage, List<dynamic>, void>((List<dynamic> args, _) {
    return IoniaCustomTipPage(getIt.get<IoniaCustomTipViewModel>(param1: args));
  });

  getIt.registerFactory(() => IoniaManageCardsPage(getIt.get<IoniaGiftCardsListViewModel>()));

  getIt.registerFactory(() => IoniaDebitCardPage(getIt.get<IoniaGiftCardsListViewModel>()));

  getIt.registerFactory(() => IoniaActivateDebitCardPage(getIt.get<IoniaGiftCardsListViewModel>()));

  getIt.registerFactory(() => IoniaAccountPage(getIt.get<IoniaAccountViewModel>()));

  getIt.registerFactory(() => IoniaAccountCardsPage(getIt.get<IoniaAccountViewModel>()));

  getIt.registerFactory(() => AnonPayApi(
      useTorOnly: getIt.get<SettingsStore>().exchangeStatus == ExchangeApiMode.torOnly,
      wallet: getIt.get<AppStore>().wallet!));

  getIt.registerFactory(() =>
      DesktopWalletSelectionDropDown(getIt.get<WalletListViewModel>(), getIt.get<AuthService>()));

  getIt.registerFactory(() => DesktopSidebarViewModel());

  getIt.registerFactoryParam<AnonpayDetailsViewModel, AnonpayInvoiceInfo, void>(
      (AnonpayInvoiceInfo anonpayInvoiceInfo, _) => AnonpayDetailsViewModel(
            anonPayApi: getIt.get<AnonPayApi>(),
            anonpayInvoiceInfo: anonpayInvoiceInfo,
            settingsStore: getIt.get<SettingsStore>(),
          ));

  getIt.registerFactoryParam<AnonPayReceivePage, AnonpayInfoBase, void>(
      (AnonpayInfoBase anonpayInvoiceInfo, _) =>
          AnonPayReceivePage(invoiceInfo: anonpayInvoiceInfo));

  getIt.registerFactoryParam<AnonpayDetailsPage, AnonpayInvoiceInfo, void>(
      (AnonpayInvoiceInfo anonpayInvoiceInfo, _) => AnonpayDetailsPage(
          anonpayDetailsViewModel: getIt.get<AnonpayDetailsViewModel>(param1: anonpayInvoiceInfo)));

  getIt.registerFactoryParam<IoniaPaymentStatusViewModel, IoniaAnyPayPaymentInfo,
          AnyPayPaymentCommittedInfo>(
      (IoniaAnyPayPaymentInfo paymentInfo, AnyPayPaymentCommittedInfo committedInfo) =>
          IoniaPaymentStatusViewModel(getIt.get<IoniaService>(),
              paymentInfo: paymentInfo, committedInfo: committedInfo));

  getIt.registerFactoryParam<IoniaPaymentStatusPage, IoniaAnyPayPaymentInfo,
          AnyPayPaymentCommittedInfo>(
      (IoniaAnyPayPaymentInfo paymentInfo, AnyPayPaymentCommittedInfo committedInfo) =>
          IoniaPaymentStatusPage(
              getIt.get<IoniaPaymentStatusViewModel>(param1: paymentInfo, param2: committedInfo)));

  getIt.registerFactoryParam<AdvancedPrivacySettingsViewModel, WalletType, void>(
      (type, _) => AdvancedPrivacySettingsViewModel(type, getIt.get<SettingsStore>()));

  getIt.registerFactoryParam<HomeSettingsPage, BalanceViewModel, void>((balanceViewModel, _) =>
      HomeSettingsPage(getIt.get<HomeSettingsViewModel>(param1: balanceViewModel)));

  getIt.registerFactoryParam<HomeSettingsViewModel, BalanceViewModel, void>(
      (balanceViewModel, _) => HomeSettingsViewModel(getIt.get<SettingsStore>(), balanceViewModel));

  getIt.registerFactoryParam<EditTokenPage, HomeSettingsViewModel, Map<String, dynamic>>(
    (homeSettingsViewModel, arguments) => EditTokenPage(
      homeSettingsViewModel: homeSettingsViewModel,
      erc20token: arguments['token'] as Erc20Token?,
      initialContractAddress: arguments['contractAddress'] as String?,
    ),
  );

  getIt.registerFactoryParam<ManageNodesPage, bool, void>((bool isPow, _) {
    if (isPow) {
      return ManageNodesPage(isPow, powNodeListViewModel: getIt.get<PowNodeListViewModel>());
    }
    return ManageNodesPage(isPow, nodeListViewModel: getIt.get<NodeListViewModel>());
  });

  getIt.registerFactory(
      () => WalletConnectConnectionsView(web3walletService: getIt.get<Web3WalletService>()));

  getIt.registerFactory(() => NFTViewModel(appStore, getIt.get<BottomSheetService>()));
  getIt.registerFactory<TorPage>(() => TorPage(getIt.get<AppStore>()));

  _isSetupFinished = true;
}
