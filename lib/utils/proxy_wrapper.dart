import 'dart:io';

import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:socks5_proxy/socks.dart';

class ProxyWrapper {
  ProxyWrapper({
    this.settingsStore,
    this.torViewModel,
  });

  SettingsStore? settingsStore;
  TorViewModel? torViewModel;

  HttpClient? _torClient;

  int getPort() {
    TorConnectionMode mode = settingsStore?.torConnectionMode ?? TorConnectionMode.disabled;
    if (mode == TorConnectionMode.disabled) {
      return -1;
    }
    return torViewModel?.torInstance.port ?? -1;
  }

  bool started = false;

  Future<HttpClient> getProxyHttpClient({int? portOverride}) async {
    if (portOverride == -1 || portOverride == null) {
      portOverride = torViewModel?.torInstance.port ?? -1;
    }

    if (!started) {
      started = true;
      _torClient = HttpClient();

      // Assign connection factory.
      SocksTCPClient.assignToHttpClient(_torClient!, [
        ProxySettings(
          InternetAddress.loopbackIPv4,
          portOverride,
          password: null,
        ),
      ]);
    }

    return _torClient!;
  }

  Future<HttpClientResponse> makeGet({
    required HttpClient client,
    required Uri uri,
    required Map<String, String>? headers,
  }) async {
    final request = await client.getUrl(uri);
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
    }
    return await request.close();
  }

  Future<HttpClientResponse> makePost({
    required HttpClient client,
    required Uri uri,
    required Map<String, String>? headers,
  }) async {
    final request = await client.postUrl(uri);
    if (headers != null) {
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
    }
    return await request.close();
  }

  Future<HttpClientResponse> get({
    Map<String, String>? headers,
    int? portOverride,
    TorConnectionMode? torConnectionMode,
    TorConnectionStatus? torConnectionStatus,
    Uri? clearnetUri,
    Uri? onionUri,
  }) async {
    HttpClient? torClient;
    late bool torEnabled;
    torConnectionMode ??= settingsStore?.torConnectionMode ?? TorConnectionMode.disabled;
    torConnectionStatus ??= torViewModel?.torConnectionStatus ?? TorConnectionStatus.disconnected;

    if (torConnectionMode == TorConnectionMode.torOnly ||
        torConnectionMode == TorConnectionMode.enabled) {
      torEnabled = true;
    } else {
      torEnabled = false;
    }

    if (torEnabled) {
      torConnectionMode = TorConnectionMode.torOnly;
    }

    if (torEnabled && torConnectionStatus == TorConnectionStatus.connecting) {
      throw Exception("Tor is still connecting");
    }

    // if tor is enabled, try to connect to the onion url first:
    if (torEnabled) {
      try {
        torClient = await getProxyHttpClient(portOverride: portOverride);
      } catch (_) {}

      if (onionUri != null) {
        try {
          return await makeGet(
            client: torClient!,
            uri: onionUri,
            headers: headers,
          );
        } catch (_) {}
      }

      if (clearnetUri != null) {
        try {
          return await makeGet(
            client: torClient!,
            uri: clearnetUri,
            headers: headers,
          );
        } catch (_) {}
      }
    }

    if (clearnetUri != null && torConnectionMode != TorConnectionMode.torOnly) {
      try {
        return HttpOverrides.runZoned(
          () async {
            return await makeGet(
              client: HttpClient(),
              uri: clearnetUri,
              headers: headers,
            );
          },
          createHttpClient: NullOverrides().createHttpClient,
        );
      } catch (_) {
        // we weren't able to get a response:
        rethrow;
      }
    }

    throw Exception("Unable to connect to server");
  }

  Future<HttpClientResponse> post({
    Map<String, String>? headers,
    int? portOverride,
    TorConnectionMode? torConnectionMode,
    TorConnectionStatus? torConnectionStatus,
    Uri? clearnetUri,
    Uri? onionUri,
  }) async {
    HttpClient? torClient;
    late bool torEnabled;
    torConnectionMode ??= settingsStore?.torConnectionMode ?? TorConnectionMode.disabled;
    torConnectionStatus ??= torViewModel?.torConnectionStatus ?? TorConnectionStatus.disconnected;

    if (torConnectionMode == TorConnectionMode.torOnly ||
        torConnectionMode == TorConnectionMode.enabled) {
      torEnabled = true;
    } else {
      torEnabled = false;
    }

    if (torEnabled) {
      torConnectionMode = TorConnectionMode.torOnly;
    }

    if (torEnabled && torConnectionStatus == TorConnectionStatus.connecting) {
      throw Exception("Tor is still connecting");
    }

    // if tor is enabled, try to connect to the onion url first:

    if (torEnabled) {
      try {
        torClient = await getProxyHttpClient(portOverride: portOverride);
      } catch (_) {}

      if (onionUri != null) {
        try {
          return await makePost(
            client: torClient!,
            uri: onionUri,
            headers: headers,
          );
        } catch (_) {}
      }

      if (clearnetUri != null) {
        try {
          return await makePost(
            client: torClient!,
            uri: clearnetUri,
            headers: headers,
          );
        } catch (_) {}
      }
    }

    if (clearnetUri != null && torConnectionMode != TorConnectionMode.torOnly) {
      try {
        return HttpOverrides.runZoned(
          () async {
            return await makePost(
              client: HttpClient(),
              uri: clearnetUri,
              headers: headers,
            );
          },
          createHttpClient: NullOverrides().createHttpClient,
        );
      } catch (_) {
        // we weren't able to get a response:
        rethrow;
      }
    }

    throw Exception("Unable to connect to server");
  }
}
