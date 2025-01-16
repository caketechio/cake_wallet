import 'dart:io';
import 'package:cw_core/keyable.dart';
import 'package:cw_core/utils/http_client.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:http/io_client.dart' as ioc;
import 'package:tor/tor.dart' as tor;

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
    this.path = '',
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

  @HiveField(10)
  bool? supportsMweb;

  bool get isSSL => useSSL ?? false;

  bool get useSocksProxy => socksProxyAddress == null ? false : socksProxyAddress!.isNotEmpty;

  Uri get uri {
    switch (type) {
      case WalletType.monero:
      case WalletType.haven:
      case WalletType.wownero:
        return Uri.http(uriRaw, '');
      case WalletType.bitcoin:
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        return createUriFromElectrumAddress(uriRaw, path!);
      case WalletType.nano:
      case WalletType.banano:
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.tron:
        return Uri.parse(
            "http${isSSL ? "s" : ""}://$uriRaw${path!.startsWith("/") ? path : "/$path"}");
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
          return requestNanoNode();
        case WalletType.bitcoin:
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
      final authenticatingClient = getHttpClient();

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

      if ((response.body.contains("400 Bad Request") // Some other generic error
              ||
              response.body.contains("plain HTTP request was sent to HTTPS port") // Cloudflare
              ||
              response.headers["location"] != null // Generic reverse proxy
              ||
              response.body
                  .contains("301 Moved Permanently") // Poorly configured generic reverse proxy
          ) &&
          !(useSSL ?? false)) {
        final oldUseSSL = useSSL;
        useSSL = true;
        try {
          final ret = await requestMoneroNode();
          if (ret == true) {
            await save();
            return ret;
          }
          useSSL = oldUseSSL;
        } catch (e) {
          useSSL = oldUseSSL;
        }
      }

      final resBody = json.decode(response.body) as Map<String, dynamic>;
      return !(resBody['result']['offline'] as bool);
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNodeWithProxy() async {
    if (!isValidProxyAddress && !tor.Tor.instance.enabled) {
      return false;
    }

    String? proxy = socksProxyAddress;

    if ((proxy?.isEmpty ?? true) && tor.Tor.instance.enabled) {
      proxy = "${InternetAddress.loopbackIPv4.address}:${tor.Tor.instance.port}";
    }
    printV("proxy: $proxy");
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

  // TODO: this will return true most of the time, even if the node has useSSL set to true while
  // it doesn't support SSL or vice versa, because it will connect normally, but it will fail if
  // you try to communicate with it
  Future<bool> requestElectrumServer() async {
    try {
      final Socket socket;
      if (useSSL == true) {
        socket = await SecureSocket.connect(uri.host, uri.port,
            timeout: Duration(seconds: 5), onBadCertificate: (_) => true);
      } else {
        socket = await Socket.connect(uri.host, uri.port, timeout: Duration(seconds: 5));
      }

      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNanoNode() async {
    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "nano-app": "cake-wallet"
        },
        body: jsonEncode(
          {
            "action": "account_balance",
            "account": "nano_38713x95zyjsqzx6nm1dsom1jmm668owkeb9913ax6nfgj15az3nu8xkx579",
          },
        ),
      );
      final data = await jsonDecode(response.body);
      if (response.statusCode != 200 ||
          data["error"] != null ||
          data["balance"] == null ||
          data["receivable"] == null) {
        throw Exception(
            "Error while trying to get balance! ${data["error"] != null ? data["error"] : ""}");
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestEthereumServer() async {
    try {
      final req = await getHttpClient()
        .getUrl(uri,)
        .timeout(Duration(seconds: 15));
      final response = await req.close();

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (err) {
      printV("Failed to request ethereum server: $err");
      return false;
    }
  }
}
