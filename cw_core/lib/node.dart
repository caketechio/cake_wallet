import 'dart:io';
import 'package:cw_core/keyable.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:http/io_client.dart' as ioc;
import 'dart:math' as math;
import 'package:convert/convert.dart';

import 'package:crypto/crypto.dart';

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
      case WalletType.zano:
      case WalletType.decred:
        return Uri.parse(
            "http${isSSL ? "s" : ""}://$uriRaw${path!.startsWith("/") || path!.isEmpty ? path : "/$path"}");
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
        case WalletType.zano:
          return requestZanoNode();
        case WalletType.decred:
          return requestDecredNode();
        case WalletType.none:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestZanoNode() async {
    final path = '/json_rpc';
    final rpcUri = isSSL ? Uri.https(uri.authority, path) : Uri.http(uri.authority, path);
    final body = {'jsonrpc': '2.0', 'id': '0', 'method': "getinfo"};

    try {
      final authenticatingClient = HttpClient();
      authenticatingClient.badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

      final http.Client client = ioc.IOClient(authenticatingClient);

      final jsonBody = json.encode(body);

      final response = await client.post(
        rpcUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );

      printV("node check response: ${response.body}");

      final resBody = json.decode(response.body) as Map<String, dynamic>;
      return resBody['result']['height'] != null;
    } catch (e) {
      printV("error: $e");
      return false;
    }
  }

  Future<bool> requestMoneroNode({String methodName = 'get_info'}) async {
    if (useSocksProxy) {
      return await requestNodeWithProxy();
    }

    final path = '/json_rpc';
    final rpcUri = isSSL ? Uri.https(uri.authority, path) : Uri.http(uri.authority, path);
    final body = {'jsonrpc': '2.0', 'id': '0', 'method': methodName};

    try {
      final authenticatingClient = HttpClient();
      authenticatingClient.badCertificateCallback =
          ((X509Certificate cert, String host, int port) => true);

      final http.Client client = ioc.IOClient(authenticatingClient);

      final jsonBody = json.encode(body);

      final response = await client.post(
        rpcUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );
      // Check if we received a 401 Unauthorized response
      if (response.statusCode == 401) {
        final daemonRpc = DaemonRpc(
          rpcUri.toString(),
          username: login ?? '',
          password: password ?? '',
        );
        final response = await daemonRpc.call('get_info', {});
        return !(response['offline'] as bool);
      }

      printV("node check response: ${response.body}");

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
          final ret = await requestMoneroNode(methodName: methodName);
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
    } catch (e) {
      printV("error: $e");
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
        headers: {"Content-Type": "application/json", "nano-app": "cake-wallet"},
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
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestDecredNode() async {
  if (uri.host == "default-spv-nodes") {
    // Just show default port as ok. The wallet will connect to a list of known
    // nodes automatically.
    return true;
  }
  try {
    final socket = await Socket.connect(uri.host, uri.port, timeout: Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// https://github.com/ManyMath/digest_auth/
/// HTTP Digest authentication.
///
/// Adapted from https://github.com/dart-lang/http/issues/605#issue-963962341.
///
/// Created because http_auth was not working for Monero daemon RPC responses.
class DigestAuth {
  final String username;
  final String password;
  String? realm;
  String? nonce;
  String? uri;
  String? qop = "auth";
  int _nonceCount = 0;

  DigestAuth(this.username, this.password);

  /// Initialize Digest parameters from the `WWW-Authenticate` header.
  void initFromAuthorizationHeader(String authInfo) {
    final Map<String, String>? values = _splitAuthenticateHeader(authInfo);
    if (values != null) {
      realm = values['realm'];
      // Check if the nonce has changed.
      if (nonce != values['nonce']) {
        nonce = values['nonce'];
        _nonceCount = 0; // Reset nonce count when nonce changes.
      }
    }
  }

  /// Generate the Digest Authorization header.
  String getAuthString(String method, String uri) {
    this.uri = uri;
    _nonceCount++;
    String cnonce = _computeCnonce();
    String nc = _formatNonceCount(_nonceCount);

    String ha1 = md5Hash("$username:$realm:$password");
    String ha2 = md5Hash("$method:$uri");
    String response = md5Hash("$ha1:$nonce:$nc:$cnonce:$qop:$ha2");

    return 'Digest username="$username", realm="$realm", nonce="$nonce", uri="$uri", qop=$qop, nc=$nc, cnonce="$cnonce", response="$response"';
  }

  /// Helper to parse the `WWW-Authenticate` header.
  Map<String, String>? _splitAuthenticateHeader(String? header) {
    if (header == null || !header.startsWith('Digest ')) {
      return null;
    }
    String token = header.substring(7); // Remove 'Digest '.
    final Map<String, String> result = {};

    final components = token.split(',').map((token) => token.trim());
    for (final component in components) {
      final kv = component.split('=');
      final key = kv[0];
      final value = kv.sublist(1).join('=').replaceAll('"', '');
      result[key] = value;
    }
    return result;
  }

  /// Helper to compute a random cnonce.
  String _computeCnonce() {
    final math.Random rnd = math.Random();
    final List<int> values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return hex.encode(values);
  }

  /// Helper to format the nonce count.
  String _formatNonceCount(int count) => count.toRadixString(16).padLeft(8, '0');

  /// Compute the MD5 hash of a string.
  String md5Hash(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}

class DaemonRpc {
  final String rpcUrl;
  final String username;
  final String password;

  DaemonRpc(this.rpcUrl, {required this.username, required this.password});

  /// Perform a JSON-RPC call with Digest Authentication.
  Future<Map<String, dynamic>> call(String method, Map<String, dynamic> params) async {
    final http.Client client = http.Client();
    final DigestAuth digestAuth = DigestAuth(username, password);

    // Initial request to get the `WWW-Authenticate` header.
    final initialResponse = await client.post(
      Uri.parse(rpcUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': '0',
        'method': method,
        'params': params,
      }),
    );

    if (initialResponse.statusCode != 401 ||
        !initialResponse.headers.containsKey('www-authenticate')) {
      throw Exception('Unexpected response: ${initialResponse.body}');
    }

    // Extract Digest details from `WWW-Authenticate` header.
    final String authInfo = initialResponse.headers['www-authenticate']!;
    digestAuth.initFromAuthorizationHeader(authInfo);

    // Create Authorization header for the second request.
    String uri = Uri.parse(rpcUrl).path;
    String authHeader = digestAuth.getAuthString('POST', uri);

    // Make the authenticated request.
    final authenticatedResponse = await client.post(
      Uri.parse(rpcUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': '0',
        'method': method,
        'params': params,
      }),
    );

    if (authenticatedResponse.statusCode != 200) {
      throw Exception('RPC call failed: ${authenticatedResponse.body}');
    }

    final Map<String, dynamic> result =
        jsonDecode(authenticatedResponse.body) as Map<String, dynamic>;
    if (result['error'] != null) {
      throw Exception('RPC Error: ${result['error']}');
    }

    return result['result'] as Map<String, dynamic>;
  }
}
