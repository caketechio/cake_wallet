import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/wallet_loading_service.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/di.dart';

const initialNotificationTitle = "Cake Background Sync";
const standbyMessage = "On standby - app is in the foreground";
const readyMessage = "Ready to sync - waiting until the app has been in the background for a while";
const startMessage = "Starting sync - app is in the background";
const allWalletsSyncedMessage = "All wallets synced - waiting for next queue refresh";
const notificationId = 888;
const notificationChannelId = "cake_service";
const notificationChannelName = "CAKE BACKGROUND SERVICE";
const notificationChannelDescription = "Cake Wallet Background Service";
const DELAY_SECONDS_BEFORE_SYNC_START = 15;
const spNodeNotificationMessage =
    "Currently configured Bitcoin node does not support Silent Payments. skipping wallet";
const SYNC_THRESHOLD = 0.98;
Duration REFRESH_QUEUE_DURATION = Duration(hours: 1);
bool syncOnBattery = false;
bool syncOnData = false;

void setMainNotification(
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin, {
  required String title,
  required String content,
}) async {
  flutterLocalNotificationsPlugin.show(
    notificationId,
    title,
    content,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelName,
        icon: "ic_bg_service_small",
        ongoing: true,
        silent: true,
      ),
    ),
  );
}

void setNotificationStandby(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: standbyMessage,
  );
}

void setNotificationReady(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: readyMessage,
  );
}

void setNotificationStarting(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: startMessage,
  );
}

void setNotificationWalletsSynced(
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
  flutterLocalNotificationsPlugin.cancelAll();
  setMainNotification(
    flutterLocalNotificationsPlugin,
    title: initialNotificationTitle,
    content: allWalletsSyncedMessage,
  );
}

void setWalletNotification(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
    {required String title, required String content, required int walletNum}) async {
  flutterLocalNotificationsPlugin.show(
    notificationId + walletNum,
    title,
    content,
    NotificationDetails(
      android: AndroidNotificationDetails(
        "${notificationChannelId}_$walletNum",
        "${notificationChannelName}_$walletNum",
        icon: "ic_bg_service_small",
        ongoing: true,
        silent: true,
      ),
    ),
  );
}

AppLifecycleState appStateFromString(String state) {
  switch (state) {
    case "AppLifecycleState.paused":
      return AppLifecycleState.paused;
    case "AppLifecycleState.resumed":
      return AppLifecycleState.resumed;
    case "AppLifecycleState.hidden":
      return AppLifecycleState.hidden;
    case "AppLifecycleState.detached":
      return AppLifecycleState.detached;
    case "AppLifecycleState.inactive":
      return AppLifecycleState.inactive;
  }
  throw Exception("unknown app state: $state");
}

@pragma("vm:entry-point")
Future<void> onStart(ServiceInstance service) async {
  printV("BACKGROUND SERVICE STARTED");
  bool bgSyncStarted = false;
  Timer? _syncTimer;
  Timer? _stuckSyncTimer;
  Timer? _queueTimer;
  Timer? _appStateTimer;
  List<WalletBase> syncingWallets = [];
  List<WalletBase> standbyWallets = [];
  Timer? _bgTimer;
  AppLifecycleState lastAppState = AppLifecycleState.resumed;
  final List<AppLifecycleState> lastAppStates = [];
  String serviceState = "NOT_RUNNING";

  // commented because the behavior appears to be bugged:
  // DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> stopAllSyncing() async {
    _syncTimer?.cancel();
    _stuckSyncTimer?.cancel();
    _queueTimer?.cancel();
    try {
      // stop all syncing wallets:
      for (int i = 0; i < syncingWallets.length; i++) {
        final wallet = syncingWallets[i];
        await wallet.stopSync(isBackgroundSync: true);
      }
      // stop all standby wallets (just in case):
      for (int i = 0; i < standbyWallets.length; i++) {
        final wallet = standbyWallets[i];
        await wallet.stopSync(isBackgroundSync: true);
      }
    } catch (e) {
      printV("error stopping sync: $e");
    }
    printV("done stopping sync");
  }

  service.on("stopService").listen((event) async {
    printV("STOPPING BACKGROUND SERVICE");
    await stopAllSyncing();
    // stop the service itself:
    service.invoke("serviceState", {"state": "NOT_RUNNING"});
    await service.stopSelf();
  });

  service.on("status").listen((event) async {
    printV(event);
  });

  Future<void> setForeground() async {
    serviceState = "FOREGROUND";
    bgSyncStarted = false;
    setNotificationStandby(flutterLocalNotificationsPlugin);
  }

  service.on("setForeground").listen((event) async {
    await setForeground();
    service.invoke("serviceState", {"state": "FOREGROUND"});
  });

  void setReady() {
    if (serviceState != "READY" && serviceState != "BACKGROUND") {
      serviceState = "READY";
      setNotificationReady(flutterLocalNotificationsPlugin);
    }
  }

  service.on("setReady").listen((event) async {
    setReady();
  });

  service.on("appState").listen((event) async {
    printV("APP STATE: ${event?["state"]}");
    lastAppState = appStateFromString(event?["state"] as String);
  });

  // we have entered the background, start the sync:
  void setBackground() async {
    // only runs once per service instance:
    if (bgSyncStarted) return;
    bgSyncStarted = true;
    serviceState = "BACKGROUND";

    await Future.delayed(const Duration(seconds: DELAY_SECONDS_BEFORE_SYNC_START));
    printV("STARTING SYNC FROM BG");
    setNotificationStarting(flutterLocalNotificationsPlugin);

    try {
      await initializeAppConfigs(loadWallet: false);
    } catch (_) {
      // these errors still show up in logs which doesn't really make sense to me
    }

    printV("INITIALIZED APP CONFIGS");

    // final currentWallet = getIt.get<AppStore>().wallet;
    // // don't start syncing immediately:
    // await currentWallet?.stopSync();

    final walletLoadingService = getIt.get<WalletLoadingService>();
    final settingsStore = getIt.get<SettingsStore>();
    final walletListViewModel = getIt.get<WalletListViewModel>();

    // get all Monero / Wownero wallets and add them
    final List<WalletListItem> moneroWallets = walletListViewModel.wallets
        .where((element) => [WalletType.monero, WalletType.wownero].contains(element.type))
        .toList();

    printV("LOADING MONERO WALLETS");

    for (int i = 0; i < moneroWallets.length; i++) {
      final wallet = await walletLoadingService.load(moneroWallets[i].type, moneroWallets[i].name);
      // stop regular sync process if it's been started
      // await wallet.stopSync(isBackgroundSync: false);
      syncingWallets.add(wallet);
    }

    printV("MONERO WALLETS LOADED");

    // get all litecoin wallets and add them:
    final List<WalletListItem> litecoinWallets = walletListViewModel.wallets
        .where((element) => element.type == WalletType.litecoin)
        .toList();

    // we only need to sync the first litecoin wallet since they share the same collection of blocks
    if (litecoinWallets.isNotEmpty) {
      try {
        final firstWallet = litecoinWallets.first;
        final wallet = await walletLoadingService.load(firstWallet.type, firstWallet.name);
        await wallet.stopSync();
        if (bitcoin!.getMwebEnabled(wallet)) {
          syncingWallets.add(wallet);
        }
      } catch (e) {
        // couldn't connect to mwebd (most likely)
        printV("error syncing litecoin wallet: $e");
      }
    }

    // get all bitcoin wallets and add them:
    final List<WalletListItem> bitcoinWallets =
        walletListViewModel.wallets.where((element) => element.type == WalletType.bitcoin).toList();
    for (int i = 0; i < bitcoinWallets.length; i++) {
      try {
        final wallet =
            await walletLoadingService.load(bitcoinWallets[i].type, bitcoinWallets[i].name);
        var node = settingsStore.getCurrentNode(WalletType.bitcoin);
        await wallet.connectToNode(node: node);

        bool nodeSupportsSP = await (wallet as ElectrumWallet).getNodeSupportsSilentPayments();
        if (!nodeSupportsSP) {
          // printV("Configured node does not support silent payments, skipping wallet");
          // setWalletNotification(
          //   flutterLocalNotificationsPlugin,
          //   title: initialNotificationTitle,
          //   content: spNodeNotificationMessage,
          //   walletNum: syncingWallets.length + 1,
          // );
          // spSupported = false;
          // continue;
          node = Node(uri: "electrs.cakewallet.com:50001");
          await wallet.connectToNode(node: node);
        }

        await wallet.stopSync();

        syncingWallets.add(wallet);
      } catch (e) {
        printV("error syncing bitcoin wallet_$i: $e");
      }
    }

    printV("STARTING SYNC TIMER");
    int syncedTicks = 0;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      for (int i = 0; i < syncingWallets.length; i++) {
        final wallet = syncingWallets[i];
        final syncStatus = wallet.syncStatus;
        final progress = wallet.syncStatus.progress();
        final progressPercent = (progress * 100).toStringAsPrecision(5) + "%";
        bool shouldSync = i == 0;

        String title = "${walletTypeToCryptoCurrency(wallet.type).title} - ${wallet.name}";
        late String content;

        if (shouldSync) {
          if (syncStatus is NotConnectedSyncStatus) {
            printV("${wallet.name} NOT CONNECTED");
            final node = settingsStore.getCurrentNode(wallet.type);
            await wallet.connectToNode(node: node);
            wallet.startSync(isBackgroundSync: true);
            printV("STARTED SYNC");
          }

          if (progress > 0.999 || syncStatus is SyncedSyncStatus) {
            syncedTicks++;
            if (syncedTicks > 5) {
              syncedTicks = 0;
              printV("WALLET $i SYNCED");
              try {
                await wallet.stopSync(isBackgroundSync: true);
              } catch (e) {
                printV("error stopping sync: $e");
              }
              // pop the first wallet from the list
              standbyWallets.add(syncingWallets.removeAt(i));
              flutterLocalNotificationsPlugin.cancelAll();

              // if all wallets are synced, show a one time notification saying so:
              if (syncingWallets.isEmpty) {
                setNotificationWalletsSynced(flutterLocalNotificationsPlugin);
              }
              continue;
            }
          } else {
            syncedTicks = 0;
          }

          if (syncStatus is SyncingSyncStatus) {
            final blocksLeft = syncStatus.blocksLeft;
            content = "$blocksLeft Blocks Left";
          } else if (syncStatus is SyncedSyncStatus) {
            content = "Synced";
          } else if (syncStatus is SyncedTipSyncStatus) {
            final tip = syncStatus.tip;
            content = "Scanned Tip: $tip";
          } else if (syncStatus is NotConnectedSyncStatus) {
            content = "Still Not Connected";
          } else if (syncStatus is AttemptingSyncStatus) {
            content = "Attempting Sync";
          } else if (syncStatus is StartingScanSyncStatus) {
            content = "Starting Scan";
          } else if (syncStatus is SyncronizingSyncStatus) {
            content = "Syncronizing";
          } else if (syncStatus is FailedSyncStatus) {
            content = "Failed Sync";
          } else if (syncStatus is ConnectingSyncStatus) {
            content = "Connecting";
          } else {
            // throw Exception("sync type not covered");
            content = "Unknown Sync Status ${syncStatus.runtimeType}";
          }

          if (syncedTicks > 0) {
            content += " - Finishing up...";
          }
        } else {
          if (syncStatus is! NotConnectedSyncStatus) {
            wallet.stopSync(isBackgroundSync: true);
          }
          if (progress < SYNC_THRESHOLD) {
            content = "$progressPercent - Waiting in sync queue";
          } else {
            content = "$progressPercent - This shouldn't happen, wallet is > SYNC_THRESHOLD";
          }
        }

        // content += " - ${DateFormat("hh:mm:ss").format(DateTime.now())}";

        if (i == 0) {
          setWalletNotification(
            flutterLocalNotificationsPlugin,
            title: title,
            content: content,
            walletNum: i,
          );
        }
      }

      // for (int i = 0; i < standbyWallets.length; i++) {
      //   int notificationIndex = syncingWallets.length + i + 1;
      //   final wallet = standbyWallets[i];
      //   final title = "${walletTypeToCryptoCurrency(wallet.type).title} - ${wallet.name}";
      //   String content = "Synced - on standby until next queue refresh";

      //   setWalletNotification(
      //     flutterLocalNotificationsPlugin,
      //     title: title,
      //     content: content,
      //     walletNum: notificationIndex,
      //   );
      // }
    });

    _queueTimer?.cancel();
    // add a timer that checks all wallets and adds them to the queue if they are less than SYNC_THRESHOLD synced:
    _queueTimer = Timer.periodic(REFRESH_QUEUE_DURATION, (timer) async {
      final batteryState = await Battery().batteryState;
      bool onBattery = batteryState == BatteryState.connectedNotCharging ||
          batteryState == BatteryState.discharging;

      ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
      bool onData = connectivityResult == ConnectivityResult.mobile;

      if (onBattery && !syncOnBattery) {
        return;
      }

      if (onData && !syncOnData) {
        return;
      }

      // don't refresh the queue until we've finished syncing all wallets:
      if (syncingWallets.isNotEmpty) {
        return;
      }

      for (int i = 0; i < standbyWallets.length; i++) {
        final wallet = standbyWallets[i];
        final syncStatus = wallet.syncStatus;
        // connect to the node if we haven't already:
        if (syncStatus is NotConnectedSyncStatus) {
          final node = settingsStore.getCurrentNode(wallet.type);
          await wallet.connectToNode(node: node);
          await wallet.startSync(isBackgroundSync: true);
        }

        // wait a while before checking progress:
        await Future.delayed(const Duration(seconds: 20));

        if (syncStatus.progress() < SYNC_THRESHOLD) {
          syncingWallets.add(standbyWallets.removeAt(i));
        }
      }
    });

    // setup a watch dog to restart the wallet sync process if it appears to get stuck:
    List<double> lastFewProgresses = [];
    List<String> stuckWallets = [];
    _stuckSyncTimer?.cancel();
    _stuckSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (syncingWallets.isEmpty) return;
      final wallet = syncingWallets.first;
      final syncStatus = wallet.syncStatus;
      if (syncStatus is! SyncingSyncStatus) return;
      lastFewProgresses.add(syncStatus.progress());
      if (lastFewProgresses.length < 10) return;
      // limit list size to 10:
      while (lastFewProgresses.length > 10) {
        lastFewProgresses.removeAt(0);
      }
      // if the progress is the same over the last 100 seconds, restart the sync:
      if (lastFewProgresses.every((p) => p == lastFewProgresses.first)) {
        printV("syncing appears to be stuck, restarting...");
        try {
          stuckWallets.add(wallet.name);
          await wallet.stopSync(isBackgroundSync: true);
        } catch (e) {
          printV("error restarting sync: $e");
        }
        // if this wallet has been stuck more than twice, don't restart it, instead, add it to the standby list and try again on next queue refresh:
        // check if stuckWallets contains wallet.name more than 2 times:
        if (stuckWallets.where((name) => name == wallet.name).length > 2) {
          printV("wallet ${wallet.name} has been stuck more than 2 times, adding to standby list");
          standbyWallets.add(syncingWallets.removeAt(0));
          stuckWallets = [];
          return;
        }
        wallet.startSync(isBackgroundSync: true);
      }
    });
  }

  service.on("setBackground").listen((event) async {
    setBackground();
  });

  // if the app state changes to paused, setReady()
  // if the app state has been paused for more than 10 seconds, setBackground()
  _appStateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    lastAppStates.add(lastAppState);
    if (lastAppStates.length > 10) {
      lastAppStates.removeAt(0);
    }
    // printV(lastAppStates);
    // if (lastAppState == AppLifecycleState.resumed && serviceState != "FOREGROUND") {
    //   setForeground();
    // }
    if (lastAppStates.length < 5) {
      service.invoke("serviceState", {"state": serviceState});
      return;
    }
    if (lastAppState == AppLifecycleState.paused && serviceState != "READY") {
      setReady();
    }
    // if all 10 states are paused, setBackground()
    if (lastAppStates.every((state) => state == AppLifecycleState.paused) && !bgSyncStarted) {
      setBackground();
    }
    service.invoke("serviceState", {"state": serviceState});
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}

Future<void> initializeService(FlutterBackgroundService bgService, bool useNotifications) async {
  if (useNotifications) {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          iOS: DarwinInitializationSettings(),
          android: AndroidInitializationSettings('ic_bg_service_small'),
        ),
      );
    }

    for (int i = 0; i < 10; i++) {
      AndroidNotificationChannel channel = AndroidNotificationChannel(
        "${notificationChannelId}_$i",
        "${notificationChannelName}_$i",
        description: notificationChannelDescription,
        importance: Importance.min,
        playSound: false,
        showBadge: false,
        enableVibration: false,
        enableLights: false,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    setNotificationStandby(flutterLocalNotificationsPlugin);
  }

  // notify the service that we are in the foreground:
  bgService.invoke("setForeground");

  try {
    bool isServiceRunning = await bgService.isRunning();
    if (isServiceRunning) {
      printV("Service is ALREADY running!");
      return;
    }
  } catch (_) {}

  printV("INITIALIZING SERVICE");

  await bgService.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: initialNotificationTitle,
      initialNotificationContent: standbyMessage,
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

class BackgroundTasks {
  FlutterBackgroundService bgService = FlutterBackgroundService();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static Timer? _pingTimer;
  static String serviceState = "NOT_RUNNING";

  void serviceBackground() {
    bgService.invoke("setBackground");
    _pingTimer?.cancel();
  }

  void foregroundPing() {
    bgService.invoke("foregroundPing");
  }

  void lastAppState(AppLifecycleState state) {
    bgService.invoke("appState", {"state": state.toString()});
  }

  Future<void> serviceForeground() async {
    printV("SERVICE FOREGROUNDED");
    final settingsStore = getIt.get<SettingsStore>();
    bool showNotifications = settingsStore.showSyncNotification;
    bgService.invoke("stopService");
    await Future.delayed(const Duration(seconds: 5));
    initializeService(bgService, showNotifications);
    bgService.invoke("setForeground");
  }

  Future<bool> isServiceRunning() async {
    return await bgService.isRunning();
  }

  Future<bool> isBackgroundSyncing() async {
    printV("serviceState: ${serviceState}");
    printV("isRunning: ${await bgService.isRunning()}");
    return await bgService.isRunning() && serviceState == "BACKGROUND";
  }

  void serviceReady() {
    final settingsStore = getIt.get<SettingsStore>();
    bool showNotifications = settingsStore.showSyncNotification;
    if (showNotifications) {
      bgService.invoke("setReady");
    }
  }

  void registerBackgroundService() async {
    printV("REGISTER BACKGROUND SERVICE");
    try {
      final settingsStore = getIt.get<SettingsStore>();
      final walletListViewModel = getIt.get<WalletListViewModel>();
      bool hasMonero =
          walletListViewModel.wallets.any((element) => element.type == WalletType.monero);

      bool hasLitecoin =
          walletListViewModel.wallets.any((element) => element.type == WalletType.litecoin);

      bool hasBitcoin =
          walletListViewModel.wallets.any((element) => element.type == WalletType.bitcoin);

      if (!settingsStore.silentPaymentsAlwaysScan) {
        hasBitcoin = false;
      }

      /// if its not android nor ios, or the user has no monero wallets; exit
      if (!DeviceInfo.instance.isMobile || (!hasMonero && !hasLitecoin && !hasBitcoin)) {
        return;
      }

      final SyncMode syncMode = settingsStore.currentSyncMode;
      final bool useNotifications = settingsStore.showSyncNotification;
      final bool syncEnabled = settingsStore.backgroundSyncEnabled;
      syncOnBattery = settingsStore.backgroundSyncOnBattery;
      syncOnData = settingsStore.backgroundSyncOnData;

      if (useNotifications) {
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      bgService.invoke("stopService");

      if (!syncEnabled || !FeatureFlag.isBackgroundSyncEnabled) {
        return;
      }

      REFRESH_QUEUE_DURATION = syncMode.frequency;

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        getIt.get<BackgroundTasks>().foregroundPing();
      });

      bgService.on("serviceState").listen((event) {
        printV("UPDATING SERVICE STATE: ${event?["state"]}");
        serviceState = event?["state"] as String;
      });

      await initializeService(bgService, useNotifications);
      bgService.invoke("setForeground");
    } catch (error, stackTrace) {
      printV(error);
      printV(stackTrace);
    }
  }
}
