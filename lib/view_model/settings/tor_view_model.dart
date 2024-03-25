import 'dart:io';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:tor/tor.dart';

part 'tor_view_model.g.dart';

class TorViewModel = TorViewModelBase with _$TorViewModel;

abstract class TorViewModelBase with Store {
  TorViewModelBase(this._settingsStore, this.nodes) {
    reaction((_) => torConnectionMode, (TorConnectionMode mode) async {
      if (mode == TorConnectionMode.enabled || mode == TorConnectionMode.torOnly) {
        startTor();
      } else {
        stopTor();
      }
    });
    reaction((_) => torConnectionStatus, (TorConnectionStatus status) async {
      if (status == TorConnectionStatus.connecting) {
        await disconnectFromNode();
      }
      if (status == TorConnectionStatus.connected) {
        await connectOrDisconnectNodeToProxy(connect: true);
      }
    });
    this.nodes.observe((change) async {
      if (change.newValue != null && change.key != null) {
        await connectOrDisconnectNodeToProxy(connect: true);
      }
    });
  }

  bool torStarted = false;
  final SettingsStore _settingsStore;
  final ObservableMap<WalletType, Node> nodes;
  Tor torInstance = Tor.instance;

  bool get supportsNodeProxy => !([WalletType.bitcoin, WalletType.litecoin, WalletType.bitcoinCash].contains(getIt.get<AppStore>().wallet?.type));

  @computed
  TorConnectionMode get torConnectionMode => _settingsStore.torConnectionMode;

  @observable
  TorConnectionStatus torConnectionStatus = TorConnectionStatus.disconnected;

  @action
  void setTorConnectionMode(TorConnectionMode mode) => _settingsStore.torConnectionMode = mode;

  Future<void> connectOrDisconnectNodeToProxy({required bool connect}) async {
    final appStore = getIt.get<AppStore>();
    if (appStore.wallet == null) {
      return;
    }
    final node = _settingsStore.getCurrentNode(appStore.wallet!.type);
    if (connect && (node.socksProxyAddress?.isEmpty ?? true)) {
      node.socksProxyAddress = "${InternetAddress.loopbackIPv4.address}:${torInstance.port}";
    } else if (!connect) {
      node.socksProxyAddress = null;
    }

    bool torOnly = _settingsStore.torConnectionMode == TorConnectionMode.torOnly;
    if ([WalletType.bitcoin, WalletType.litecoin, WalletType.bitcoinCash]
        .contains(appStore.wallet!.type)) {
      bitcoin!.setTorOnly(appStore.wallet!, torOnly);
    }

    await appStore.wallet!.connectToNode(node: node);
  }

  Future<void> disconnectFromNode() async {
    final appStore = getIt.get<AppStore>();
    appStore.wallet?.syncStatus = NotConnectedSyncStatus();
    await appStore.wallet?.connectToNode(node: Node(uri: "http://127.0.0.1"));
  }

  @action
  Future<void> startTor() async {
    try {
      torConnectionStatus = TorConnectionStatus.connecting;

      if (!torStarted) {
        torStarted = true;
        torInstance = await Tor.init();
      }

      await torInstance.enable();

      SocksTCPClient.setProxy(proxies: [
        ProxySettings(
          InternetAddress.loopbackIPv4,
          torInstance.port,
          password: null,
        ),
      ]);

      torConnectionStatus = TorConnectionStatus.connected;

      // connect to node through the proxy:
      await connectOrDisconnectNodeToProxy(connect: true);
    } catch (e) {
      torConnectionStatus = TorConnectionStatus.disconnected;
    }
  }

  @action
  Future<void> stopTor() async {
    torInstance.disable();
    torConnectionStatus = TorConnectionStatus.disconnected;
    SocksTCPClient.removeProxy();
    await connectOrDisconnectNodeToProxy(connect: false);
  }
}
