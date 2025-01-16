import 'dart:io';
import 'package:http/http.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:tor/tor.dart';

HttpClient getHttpClient() {
  final client = HttpClient();

  if (Tor.instance.enabled) {
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(InternetAddress.loopbackIPv4,
          Tor.instance.port,
          password: null,
        ),
    ]);
  }

  return client;
}
