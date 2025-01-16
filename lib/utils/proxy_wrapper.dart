import 'dart:io';

import 'package:cake_wallet/store/settings_store.dart';
import 'package:socks5_proxy/socks.dart';
import 'package:tor/tor.dart';

class ProxyWrapper {
  ProxyWrapper({
    this.settingsStore,
  });

  SettingsStore? settingsStore;


  int getPort() => Tor.instance.port;

  HttpClient getProxyHttpClient({int? portOverride}) {
    final torClient = HttpClient();

    if (Tor.instance.started) {
      // Assign connection factory.
      SocksTCPClient.assignToHttpClient(torClient, [
        ProxySettings(
          InternetAddress.loopbackIPv4,
          portOverride ?? getPort(),
          password: null,
        ),
      ]);
    }

    return torClient;
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
    Uri? clearnetUri,
    Uri? onionUri,
  }) async {
    HttpClient? torClient;
    bool torEnabled = Tor.instance.started;

    if (Tor.instance.started) {
      torEnabled = true;
    } else {
      torEnabled = false;
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

    if (clearnetUri != null) {
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
    Uri? clearnetUri,
    Uri? onionUri,
  }) async {
    HttpClient? torClient;
    bool torEnabled = Tor.instance.started;

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

    if (clearnetUri != null) {
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
