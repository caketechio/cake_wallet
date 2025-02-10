import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/entities/qr_scanner.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:collection/collection.dart';
import 'package:cake_wallet/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';

part 'node_create_or_edit_view_model.g.dart';

class NodeCreateOrEditViewModel = NodeCreateOrEditViewModelBase with _$NodeCreateOrEditViewModel;

abstract class NodeCreateOrEditViewModelBase with Store {
  NodeCreateOrEditViewModelBase(this._nodeSource, this._walletType, this._settingsStore)
      : state = InitialExecutionState(),
        connectionState = InitialExecutionState(),
        useSSL = false,
        address = '',
        path = '',
        port = '',
        login = '',
        password = '',
        trusted = false,
        useSocksProxy = false,
        socksProxyAddress = '';

  @observable
  ExecutionState state;

  @observable
  String address;

  @observable
  String path;

  @observable
  String port;

  @observable
  String login;

  @observable
  String password;

  @observable
  ExecutionState connectionState;

  @observable
  bool useSSL;

  @observable
  bool trusted;

  @observable
  bool useSocksProxy;

  @observable
  String socksProxyAddress;

  @computed
  bool get isReady =>
      (address.isNotEmpty && port.isNotEmpty) ||
      _walletType == WalletType.decred; // Allow an empty address.

  bool get hasAuthCredentials =>
      _walletType == WalletType.monero || _walletType == WalletType.wownero || _walletType == WalletType.haven;

  bool get hasPathSupport {
    switch (_walletType) {
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.banano:
      case WalletType.nano:
      case WalletType.tron:
        return true;
      case WalletType.none:
      case WalletType.monero:
      case WalletType.wownero:
      case WalletType.haven:
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
      case WalletType.bitcoin:
      case WalletType.zano:
      case WalletType.decred:
        return false;
    }
  }

  String get uri {
    var uri = address;

    if (port.isNotEmpty) {
      uri += ':' + port;
    }

    return uri;
  }

  final WalletType _walletType;
  final Box<Node> _nodeSource;
  final SettingsStore _settingsStore;

  @action
  void reset() {
    address = '';
    path = '';
    port = '';
    login = '';
    password = '';
    useSSL = false;
    trusted = false;
    useSocksProxy = false;
    socksProxyAddress = '';
  }

  @action
  void setPort(String val) => port = val;

  @action
  void setAddress(String val) => address = val;

  @action
  void setPath(String val) => path = val;

  @action
  void setLogin(String val) => login = val;

  @action
  void setPassword(String val) => password = val;

  @action
  void setSSL(bool val) => useSSL = val;

  @action
  void setTrusted(bool val) => trusted = val;

  @action
  void setSocksProxy(bool val) => useSocksProxy = val;

  @action
  void setSocksProxyAddress(String val) => socksProxyAddress = val;

  @action
  Future<void> save({Node? editingNode, bool saveAsCurrent = false}) async {
    final node = Node(
        uri: uri,
        path: path,
        type: _walletType,
        login: login,
        password: password,
        useSSL: useSSL,
        trusted: trusted,
        socksProxyAddress: socksProxyAddress);
    try {
      state = IsExecutingState();
      if (editingNode != null) {
        await _nodeSource.put(editingNode.key, node);
      } else if (_existingNode(node) != null) {
        setAsCurrent(_existingNode(node)!);
      } else {
        await _nodeSource.add(node);
        setAsCurrent(_nodeSource.values.last);
      }
      if (saveAsCurrent) {
        setAsCurrent(node);
      }

      state = ExecutedSuccessfullyState();
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  @action
  Future<void> connect() async {
    final node = Node(
        uri: uri,
        path: path,
        type: _walletType,
        login: login,
        password: password,
        useSSL: useSSL,
        trusted: trusted,
        socksProxyAddress: socksProxyAddress);
    try {
      connectionState = IsExecutingState();
      final isAlive = await node.requestNode();
      connectionState = ExecutedSuccessfullyState(payload: isAlive);
    } catch (e) {
      connectionState = FailureState(e.toString());
    }
  }

  Node? _existingNode(Node node) {
    final nodes = _nodeSource.values.toList();
    nodes.forEach((item) {
      item.login ??= '';
      item.password ??= '';
      item.useSSL ??= false;
    });
    return nodes.firstWhereOrNull((item) => item == node);
  }

  @action
  void setAsCurrent(Node node) => _settingsStore.nodes[_walletType] = node;

  @action
  Future<void> scanQRCodeForNewNode(BuildContext context) async {
    try {
      bool isCameraPermissionGranted =
          await PermissionHandler.checkPermission(Permission.camera, context);
      if (!isCameraPermissionGranted) return;
      String? code = await presentQRScanner(context);
      if (code == null) throw Exception("Unexpected QR code value: aborted");

      if (code.isEmpty) {
        throw Exception('Unexpected scan QR code value: value is empty');
      }

      if (!code.contains('://')) code = 'tcp://$code';

      final uri = Uri.tryParse(code);
      if (uri == null || uri.host.isEmpty) {
        throw Exception('Invalid QR code: Unable to parse or missing host.');
      }

      final userInfo = uri.userInfo;
      final rpcUser = userInfo.length == 2 ? userInfo[0] : '';
      final rpcPassword = userInfo.length == 2 ? userInfo[1] : '';
      final ipAddress = uri.host;
      final port = uri.hasPort ? uri.port.toString() : '';
      final path = uri.path;
      final queryParams = uri.queryParameters; // Currently not used

      await Future.delayed(Duration(milliseconds: 345));

      setAddress(ipAddress);
      setPath(path);
      setPassword(rpcPassword);
      setLogin(rpcUser);
      setPort(port);
    } on Exception catch (e) {
      connectionState = FailureState(e.toString());
    }
  }
}
