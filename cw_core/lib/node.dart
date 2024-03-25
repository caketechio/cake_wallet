import 'dart:io';
import 'package:cw_core/keyable.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:http/io_client.dart' as ioc;

part 'node.g.dart';

Uri createUriFromElectrumAddress(String address) => Uri.tryParse('tcp://$address')!;

@HiveType(typeId: Node.typeId)
class Node extends HiveObject with Keyable {
  Node({
    this.login,
    this.password,
    this.useSSL,
    this.trusted = false,
    this.socksProxyAddress,
    String? uri,
    WalletType? type,
  }) {
    if (uri != null) {
      uriRaw = uri;
    }
    if (type != null) {
      this.type = type;
    }
  }

  Node.fromMap(Map<String, Object?> map)
      : uriRaw = map['uri'] as String? ?? '',
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

  bool get isSSL => useSSL ?? false;

  bool get useSocksProxy => socksProxyAddress == null ? false : socksProxyAddress!.isNotEmpty;

  Uri get uri {
    switch (type) {
      case WalletType.monero:
      case WalletType.haven:
        return Uri.http(uriRaw, '');
      case WalletType.bitcoin:
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        return createUriFromElectrumAddress(uriRaw);
      case WalletType.nano:
      case WalletType.banano:
        if (isSSL) {
          return Uri.https(uriRaw, '');
        } else {
          return Uri.http(uriRaw, '');
        }
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
        return Uri.https(uriRaw, '');
      default:
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
          other.socksProxyAddress == socksProxyAddress);

  @override
  int get hashCode =>
      uriRaw.hashCode ^
      login.hashCode ^
      password.hashCode ^
      typeRaw.hashCode ^
      useSSL.hashCode ^
      trusted.hashCode ^
      socksProxyAddress.hashCode;

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
          return requestMoneroNode();
        case WalletType.nano:
        case WalletType.banano:
          return requestNanoNode();
        case WalletType.bitcoin:
        case WalletType.litecoin:
        case WalletType.bitcoinCash:
        case WalletType.ethereum:
        case WalletType.polygon:
        case WalletType.solana:
          return requestElectrumServer();
        default:
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

  Future<bool> requestNanoNode() async {
    http.Response response = await http.post(
      uri,
      headers: {'Content-type': 'application/json'},
      body: json.encode(
        {
          "action": "block_count",
        },
      ),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> requestNodeWithProxy() async {
    if (!isValidProxyAddress) {
      return false;
    }

    String? proxy = socksProxyAddress;

    if (proxy == null) {
      return false;
    }
    final proxyAddress = proxy.split(':')[0];
    final proxyPort = int.parse(proxy.split(':')[1]);
    try {
      final socket = await Socket.connect(proxyAddress, proxyPort, timeout: Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestElectrumServer() async {
    try {
      await SecureSocket.connect(uri.host, uri.port,
          timeout: Duration(seconds: 5), onBadCertificate: (_) => true);
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
