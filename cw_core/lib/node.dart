import 'dart:io';
import 'package:cw_core/keyable.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:http/io_client.dart' as ioc;

// import 'package:tor/tor.dart';

part 'node.g.dart';

Uri createUriFromElectrumAddress(String address, String path) =>
    Uri.tryParse('tcp://$address$path')!;

@HiveType(typeId: Node.typeId)
class Node extends HiveObject with Keyable {
  Node({
    this.login,
    this.password,
    this.useSSL,
    this.trusted = false,
    this.socksProxyAddress,
    String? uri,
    String? path,
    WalletType? type,
  }) {
    if (uri != null) {
      uriRaw = uri;
    }
    if (type != null) {
      this.type = type;
    }
    if (path != null) {
      this.path = path;
    }
  }

  Node.fromMap(Map<String, Object?> map)
      : uriRaw = map['uri'] as String? ?? '',
        path = map['path'] as String? ?? '',
        login = map['login'] as String?,
        password = map['password'] as String?,
        useSSL = map['useSSL'] as bool?,
        trusted = map['trusted'] as bool? ?? false,
        socksProxyAddress = map['socksProxyPort'] as String?;

  static const typeId = NODE_TYPE_ID;
  static const boxName = 'Nodes';

  @HiveField(0, defaultValue: '')
  late String uriRaw;

  @HiveField(1)
  String? login;

  @HiveField(2)
  String? password;

  @HiveField(3, defaultValue: 0)
  late int typeRaw;

  @HiveField(4)
  bool? useSSL;

  @HiveField(5, defaultValue: false)
  bool trusted;

  @HiveField(6)
  String? socksProxyAddress;

  @HiveField(7, defaultValue: '')
  String? path;

  @HiveField(8)
  bool? isElectrs;

  @HiveField(9)
  bool? supportsSilentPayments;

  bool get isSSL => useSSL ?? false;

  bool get useSocksProxy => socksProxyAddress == null ? false : socksProxyAddress!.isNotEmpty;

  Uri get uri {
    switch (type) {
      case WalletType.monero:
      case WalletType.haven:
      case WalletType.wownero:
        return Uri.http(uriRaw, '');
      case WalletType.bitcoin:
      case WalletType.lightning:
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        return createUriFromElectrumAddress(uriRaw, path ?? '');
      case WalletType.nano:
      case WalletType.banano:
        if (isSSL) {
          return Uri.https(uriRaw, path ?? '');
        } else {
          return Uri.http(uriRaw, path ?? '');
        }
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.tron:
        return Uri.https(uriRaw, path ?? '');
      case WalletType.none:
        throw Exception('Unexpected type ${type.toString()} for Node uri');
    }
  }

  bool get isValidProxyAddress => socksProxyAddress?.contains(':') ?? false;

  @override
  bool operator ==(other) =>
      other is Node &&
      (other.uriRaw == uriRaw &&
          other.login == login &&
          other.password == password &&
          other.typeRaw == typeRaw &&
          other.useSSL == useSSL &&
          other.trusted == trusted &&
          other.socksProxyAddress == socksProxyAddress &&
          other.path == path);

  @override
  int get hashCode =>
      uriRaw.hashCode ^
      login.hashCode ^
      password.hashCode ^
      typeRaw.hashCode ^
      useSSL.hashCode ^
      trusted.hashCode ^
      socksProxyAddress.hashCode ^
      path.hashCode;

  @override
  dynamic get keyIndex {
    _keyIndex ??= key;
    return _keyIndex;
  }

  WalletType get type => deserializeFromInt(typeRaw);

  set type(WalletType type) => typeRaw = serializeToInt(type);

  dynamic _keyIndex;

  Future<bool> requestNode() async {
    try {
      switch (type) {
        case WalletType.monero:
        case WalletType.haven:
        case WalletType.wownero:
          return requestMoneroNode();
        case WalletType.nano:
        case WalletType.banano:
        case WalletType.bitcoin:
        case WalletType.lightning:
        case WalletType.litecoin:
        case WalletType.bitcoinCash:
        case WalletType.ethereum:
        case WalletType.polygon:
        case WalletType.solana:
        case WalletType.tron:
          return requestElectrumServer();
        case WalletType.none:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestMoneroNode() async {
    if (uri.toString().contains(".onion") || useSocksProxy) {
      return await requestNodeWithProxy();
    }
    final path = '/json_rpc';
    final rpcUri = isSSL ? Uri.https(uri.authority, path) : Uri.http(uri.authority, path);
    final realm = 'monero-rpc';
    final body = {'jsonrpc': '2.0', 'id': '0', 'method': 'get_info'};

    try {
      final authenticatingClient = HttpClient();

      authenticatingClient.badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

      authenticatingClient.addCredentials(
        rpcUri,
        realm,
        HttpClientDigestCredentials(login ?? '', password ?? ''),
      );

      final http.Client client = ioc.IOClient(authenticatingClient);

      final response = await client.post(
        rpcUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      client.close();

      final resBody = json.decode(response.body) as Map<String, dynamic>;
      return !(resBody['result']['offline'] as bool);
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNodeWithProxy() async {
    if (!isValidProxyAddress /* && !Tor.instance.enabled*/) {
      return false;
    }

    String? proxy = socksProxyAddress;

    // if ((proxy?.isEmpty ?? true) && Tor.instance.enabled) {
    //   proxy = "${InternetAddress.loopbackIPv4.address}:${Tor.instance.port}";
    // }
    if (proxy == null) {
      return false;
    }
    final proxyAddress = proxy!.split(':')[0];
    final proxyPort = int.parse(proxy.split(':')[1]);
    try {
      final socket = await Socket.connect(proxyAddress, proxyPort, timeout: Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // TODO: this will return true most of the time, even if the node has useSSL set to true while
  // it doesn't support SSL or vice versa, because it will connect normally, but it will fail if
  // you try to communicate with it
  Future<bool> requestElectrumServer() async {
    try {
      if (useSSL == true) {
        await SecureSocket.connect(uri.host, uri.port,
            timeout: Duration(seconds: 5), onBadCertificate: (_) => true);
      } else {
        await Socket.connect(uri.host, uri.port, timeout: Duration(seconds: 5));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestEthereumServer() async {
    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
