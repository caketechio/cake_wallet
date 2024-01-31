import 'dart:async';
import 'package:cake_wallet/anonpay/anonpay_invoice_info.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cake_wallet/locales/locale.dart';
import 'package:cake_wallet/store/yat/yat_store.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cw_core/address_info.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cw_core/root_dir.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:cake_wallet/di.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/core/secure_storage.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/router.dart' as Router;
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/reactions/bootstrap.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/entities/transaction_description.dart';
import 'package:cake_wallet/entities/get_encryption_key.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cake_wallet/entities/default_settings_migration.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/entities/template.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/exchange_template.dart';
import 'package:cake_wallet/src/screens/root/root.dart';
import 'package:uni_links/uni_links.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cake_wallet/core/flatpak.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final rootKey = GlobalKey<RootState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = ExceptionHandler.onError;

    /// A callback that is invoked when an unhandled error occurs in the root
    /// isolate.
    PlatformDispatcher.instance.onError = (error, stack) {
      ExceptionHandler.onError(FlutterErrorDetails(exception: error, stack: stack));

      return true;
    };

    await CakeHive.close();

    await initializeAppConfigs();

    runApp(App());
  }, (error, stackTrace) async {
    ExceptionHandler.onError(FlutterErrorDetails(exception: error, stack: stackTrace));
  });
}

Future<void> initializeAppConfigs() async {
  setRootDirFromEnv();
  final appDir = await getAppDir(isFlatpak: isFlatpak);
  await CakeHive.close();
  CakeHive.init(appDir.path);

  if (!CakeHive.isAdapterRegistered(Contact.typeId)) {
    CakeHive.registerAdapter(ContactAdapter());
  }

  if (!CakeHive.isAdapterRegistered(Node.typeId)) {
    CakeHive.registerAdapter(NodeAdapter());
  }

  if (!CakeHive.isAdapterRegistered(TransactionDescription.typeId)) {
    CakeHive.registerAdapter(TransactionDescriptionAdapter());
  }

  if (!CakeHive.isAdapterRegistered(Trade.typeId)) {
    CakeHive.registerAdapter(TradeAdapter());
  }

  if (!CakeHive.isAdapterRegistered(AddressInfo.typeId)) {
    CakeHive.registerAdapter(AddressInfoAdapter());
  }

  if (!CakeHive.isAdapterRegistered(WalletInfo.typeId)) {
    CakeHive.registerAdapter(WalletInfoAdapter());
  }

  if (!CakeHive.isAdapterRegistered(DERIVATION_TYPE_TYPE_ID)) {
    CakeHive.registerAdapter(DerivationTypeAdapter());
  }

  if (!CakeHive.isAdapterRegistered(WALLET_TYPE_TYPE_ID)) {
    CakeHive.registerAdapter(WalletTypeAdapter());
  }

  if (!CakeHive.isAdapterRegistered(Template.typeId)) {
    CakeHive.registerAdapter(TemplateAdapter());
  }

  if (!CakeHive.isAdapterRegistered(ExchangeTemplate.typeId)) {
    CakeHive.registerAdapter(ExchangeTemplateAdapter());
  }

  if (!CakeHive.isAdapterRegistered(Order.typeId)) {
    CakeHive.registerAdapter(OrderAdapter());
  }

  if (!CakeHive.isAdapterRegistered(UnspentCoinsInfo.typeId)) {
    CakeHive.registerAdapter(UnspentCoinsInfoAdapter());
  }

  if (!CakeHive.isAdapterRegistered(AnonpayInvoiceInfo.typeId)) {
    CakeHive.registerAdapter(AnonpayInvoiceInfoAdapter());
  }

  final secureStorage = secureStorageShared;
  final transactionDescriptionsBoxKey =
      await getEncryptionKey(secureStorage: secureStorage, forKey: TransactionDescription.boxKey);
  final tradesBoxKey = await getEncryptionKey(secureStorage: secureStorage, forKey: Trade.boxKey);
  final ordersBoxKey = await getEncryptionKey(secureStorage: secureStorage, forKey: Order.boxKey);
  final contacts = await CakeHive.openBox<Contact>(Contact.boxName);
  final nodes = await CakeHive.openBox<Node>(Node.boxName);
  final powNodes =
      await CakeHive.openBox<Node>(Node.boxName + "pow"); // must be different from Node.boxName
  final transactionDescriptions = await CakeHive.openBox<TransactionDescription>(
      TransactionDescription.boxName,
      encryptionKey: transactionDescriptionsBoxKey);
  final trades = await CakeHive.openBox<Trade>(Trade.boxName, encryptionKey: tradesBoxKey);
  final orders = await CakeHive.openBox<Order>(Order.boxName, encryptionKey: ordersBoxKey);
  final walletInfoSource = await CakeHive.openBox<WalletInfo>(WalletInfo.boxName);
  final templates = await CakeHive.openBox<Template>(Template.boxName);
  final exchangeTemplates = await CakeHive.openBox<ExchangeTemplate>(ExchangeTemplate.boxName);
  final anonpayInvoiceInfo = await CakeHive.openBox<AnonpayInvoiceInfo>(AnonpayInvoiceInfo.boxName);
  final unspentCoinsInfoSource = await CakeHive.openBox<UnspentCoinsInfo>(UnspentCoinsInfo.boxName);

  await initialSetup(
      sharedPreferences: await SharedPreferences.getInstance(),
      nodes: nodes,
      powNodes: powNodes,
      walletInfoSource: walletInfoSource,
      contactSource: contacts,
      tradesSource: trades,
      ordersSource: orders,
      unspentCoinsInfoSource: unspentCoinsInfoSource,
      // fiatConvertationService: fiatConvertationService,
      templates: templates,
      exchangeTemplates: exchangeTemplates,
      transactionDescriptions: transactionDescriptions,
      secureStorage: secureStorage,
      anonpayInvoiceInfo: anonpayInvoiceInfo,
      initialMigrationVersion: 26);
}

Future<void> initialSetup(
    {required SharedPreferences sharedPreferences,
    required Box<Node> nodes,
    required Box<Node> powNodes,
    required Box<WalletInfo> walletInfoSource,
    required Box<Contact> contactSource,
    required Box<Trade> tradesSource,
    required Box<Order> ordersSource,
    // required FiatConvertationService fiatConvertationService,
    required Box<Template> templates,
    required Box<ExchangeTemplate> exchangeTemplates,
    required Box<TransactionDescription> transactionDescriptions,
    required SecureStorage secureStorage,
    required Box<AnonpayInvoiceInfo> anonpayInvoiceInfo,
    required Box<UnspentCoinsInfo> unspentCoinsInfoSource,
    int initialMigrationVersion = 15}) async {
  LanguageService.loadLocaleList();
  await defaultSettingsMigration(
      secureStorage: secureStorage,
      version: initialMigrationVersion,
      sharedPreferences: sharedPreferences,
      walletInfoSource: walletInfoSource,
      contactSource: contactSource,
      tradeSource: tradesSource,
      nodes: nodes,
      powNodes: powNodes);
  await setup(
      walletInfoSource: walletInfoSource,
      nodeSource: nodes,
      powNodeSource: powNodes,
      contactSource: contactSource,
      tradesSource: tradesSource,
      templates: templates,
      exchangeTemplates: exchangeTemplates,
      transactionDescriptionBox: transactionDescriptions,
      ordersSource: ordersSource,
      anonpayInvoiceInfoSource: anonpayInvoiceInfo,
      unspentCoinsInfoSource: unspentCoinsInfoSource);
  await bootstrap(navigatorKey);
  monero?.onStartup();
}

class App extends StatefulWidget {
  @override
  AppState createState() => AppState();
}

class AppState extends State<App> with SingleTickerProviderStateMixin {
  AppState() : yatStore = getIt.get<YatStore>();

  YatStore yatStore;
  StreamSubscription? stream;

  @override
  void initState() {
    super.initState();
    //_handleIncomingLinks();
    //_handleInitialUri();
  }

  Future<void> _handleInitialUri() async {
    try {
      final uri = await getInitialUri();
      print('uri: $uri');
      if (uri == null) {
        return;
      }
      if (!mounted) return;
      //_fetchEmojiFromUri(uri);
    } catch (e) {
      if (!mounted) return;
      print(e.toString());
    }
  }

  void _handleIncomingLinks() {
    if (!kIsWeb) {
      stream = getUriLinksStream().listen((Uri? uri) {
        print('uri: $uri');
        if (!mounted) return;
        //_fetchEmojiFromUri(uri);
      }, onError: (Object error) {
        if (!mounted) return;
        print('Error: $error');
      });
    }
  }

  void _fetchEmojiFromUri(Uri uri) {
    //final queryParameters = uri.queryParameters;
    //if (queryParameters?.isEmpty ?? true) {
    //  return;
    //}
    //final emoji = queryParameters['eid'];
    //final refreshToken = queryParameters['refresh_token'];
    //if ((emoji?.isEmpty ?? true)||(refreshToken?.isEmpty ?? true)) {
    //  return;
    //}
    //yatStore.emoji = emoji;
    //yatStore.refreshToken = refreshToken;
    //yatStore.emojiIncommingSC.add(emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (BuildContext context) {
      final appStore = getIt.get<AppStore>();
      final authService = getIt.get<AuthService>();
      final settingsStore = appStore.settingsStore;
      final statusBarColor = Colors.transparent;
      final authenticationStore = getIt.get<AuthenticationStore>();
      final initialRoute = authenticationStore.state == AuthenticationState.uninitialized
          ? Routes.disclaimer
          : Routes.login;
      final currentTheme = settingsStore.currentTheme;
      final statusBarBrightness =
          currentTheme.type == ThemeType.dark ? Brightness.light : Brightness.dark;
      final statusBarIconBrightness =
          currentTheme.type == ThemeType.dark ? Brightness.light : Brightness.dark;
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: statusBarColor,
          statusBarBrightness: statusBarBrightness,
          statusBarIconBrightness: statusBarIconBrightness));

      return Root(
          key: rootKey,
          appStore: appStore,
          authenticationStore: authenticationStore,
          navigatorKey: navigatorKey,
          authService: authService,
          child: MaterialApp(
            navigatorObservers: [routeObserver],
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: settingsStore.theme,
            localizationsDelegates: localizationDelegates,
            supportedLocales: S.delegate.supportedLocales,
            locale: Locale(settingsStore.languageCode),
            onGenerateRoute: (settings) => Router.createRoute(settings),
            initialRoute: initialRoute,
            home: _Home(),
          ));
    });
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void didChangeDependencies() {
    _setOrientation(context);

    super.didChangeDependencies();
  }

  void _setOrientation(BuildContext context) {
    if (!DeviceInfo.instance.isDesktop) {
      if (responsiveLayoutUtil.shouldRenderMobileUI) {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      } else {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
