import 'dart:async';
import 'dart:io';
import 'package:cake_wallet/anonpay/anonpay_invoice_info.dart';
import 'package:cake_wallet/app_scroll_behavior.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cake_wallet/entities/default_settings_migration.dart';
import 'package:cake_wallet/entities/get_encryption_key.dart';
import 'package:cake_wallet/core/secure_storage.dart';
import 'package:cake_wallet/entities/haven_seed_store.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/entities/template.dart';
import 'package:cake_wallet/entities/transaction_description.dart';
import 'package:cake_wallet/exchange/exchange_template.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/locales/locale.dart';
import 'package:cake_wallet/reactions/bootstrap.dart';
import 'package:cake_wallet/router.dart' as Router;
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/root/root.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cake_wallet/view_model/link_view_model.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cw_core/address_info.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/mweb_utxo.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/payjoin_session.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:hive/hive.dart';
import 'package:cw_core/root_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cw_core/window_size.dart';
import 'package:logging/logging.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final rootKey = GlobalKey<RootState>();
final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

Future<void> main({Key? topLevelKey}) async {
  await runAppWithZone(topLevelKey: topLevelKey);
}

Future<void> runAppWithZone({Key? topLevelKey}) async {
  bool isAppRunning = false;

  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = ExceptionHandler.onError;

    /// A callback that is invoked when an unhandled error occurs in the root
    /// isolate.
    PlatformDispatcher.instance.onError = (error, stack) {
      ExceptionHandler.onError(FlutterErrorDetails(exception: error, stack: stack));

      return true;
    };
    await initializeAppAtRoot();

    if (kDebugMode) {
      final appDocDir = await getAppDir();

      final ledgerFile = File('${appDocDir.path}/ledger_log.txt');
      if (!ledgerFile.existsSync()) ledgerFile.createSync();
      Logger.root.onRecord.listen((event) async {
        final content = ledgerFile.readAsStringSync();
        ledgerFile.writeAsStringSync("$content\n${event.message}");
      });
    }

    runApp(App(key: topLevelKey));
    isAppRunning = true;
  }, (error, stackTrace) async {
    if (!isAppRunning) {
      runApp(
        TopLevelErrorWidget(error: error, stackTrace: stackTrace),
      );
    }

    await ExceptionHandler.onError(FlutterErrorDetails(exception: error, stack: stackTrace));
  });
}

Future<void> initializeAppAtRoot({bool reInitializing = false}) async {
  if (!reInitializing) await setDefaultMinimumWindowSize();
  await CakeHive.close();
  await initializeAppConfigs();
}

Future<void> initializeAppConfigs() async {
  setRootDirFromEnv();
  final appDir = await getAppDir();
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

  if (!CakeHive.isAdapterRegistered(DERIVATION_INFO_TYPE_ID)) {
    CakeHive.registerAdapter(DerivationInfoAdapter());
  }

  if (!CakeHive.isAdapterRegistered(HARDWARE_WALLET_TYPE_TYPE_ID)) {
    CakeHive.registerAdapter(HardwareWalletTypeAdapter());
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

  if (!CakeHive.isAdapterRegistered(HavenSeedStore.typeId)) {
    CakeHive.registerAdapter(HavenSeedStoreAdapter());
  }

  if (!CakeHive.isAdapterRegistered(MwebUtxo.typeId)) {
    CakeHive.registerAdapter(MwebUtxoAdapter());
  }

  if (!CakeHive.isAdapterRegistered(PayjoinSession.typeId)) {
    CakeHive.registerAdapter(PayjoinSessionAdapter());
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
  final payjoinSessionSource = await CakeHive.openBox<PayjoinSession>(PayjoinSession.boxName);

  final havenSeedStoreBoxKey =
      await getEncryptionKey(secureStorage: secureStorage, forKey: HavenSeedStore.boxKey);
  final havenSeedStore = await CakeHive.openBox<HavenSeedStore>(
      HavenSeedStore.boxName,
      encryptionKey: havenSeedStoreBoxKey);

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
    payjoinSessionSource: payjoinSessionSource,
    anonpayInvoiceInfo: anonpayInvoiceInfo,
    havenSeedStore: havenSeedStore,
    initialMigrationVersion: 47,
  );
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
    required Box<PayjoinSession> payjoinSessionSource,
    required Box<HavenSeedStore> havenSeedStore,
    int initialMigrationVersion = 15, }) async {
  LanguageService.loadLocaleList();
  await defaultSettingsMigration(
      secureStorage: secureStorage,
      version: initialMigrationVersion,
      sharedPreferences: sharedPreferences,
      walletInfoSource: walletInfoSource,
      contactSource: contactSource,
      tradeSource: tradesSource,
      nodes: nodes,
      powNodes: powNodes,
      havenSeedStore: havenSeedStore);
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
    unspentCoinsInfoSource: unspentCoinsInfoSource,
    payjoinSessionSource: payjoinSessionSource,
    navigatorKey: navigatorKey,
    secureStorage: secureStorage,
  );
  await bootstrap(navigatorKey);
}

class App extends StatefulWidget {
  App({this.key});

  final Key? key;
  @override
  AppState createState() => AppState();
}

class AppState extends State<App> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Observer(builder: (BuildContext context) {
      final appStore = getIt.get<AppStore>();
      final authService = getIt.get<AuthService>();
      final linkViewModel = getIt.get<LinkViewModel>();
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
          key: widget.key ?? rootKey,
          appStore: appStore,
          authenticationStore: authenticationStore,
          navigatorKey: navigatorKey,
          authService: authService,
          linkViewModel: linkViewModel,
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
            scrollBehavior: AppScrollBehavior(),
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

class TopLevelErrorWidget extends StatelessWidget {
  const TopLevelErrorWidget({
    required this.error,
    required this.stackTrace,
    super.key,
  });

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            child: Column(
              children: [
                Text(
                  'Error:\n${error.toString()}',
                  style: TextStyle(fontSize: 22),
                ),
                Text(
                  'Stack trace:\n${stackTrace.toString()}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
