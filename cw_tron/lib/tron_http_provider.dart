import 'dart:convert';
import 'dart:io';

import 'package:cw_core/utils/http_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as ioc;
import 'package:on_chain/tron/tron.dart';
import '.secrets.g.dart' as secrets;

class TronHTTPProvider implements TronServiceProvider {
  TronHTTPProvider(
      {required this.url,
      this.defaultRequestTimeout = const Duration(seconds: 30)});
  @override
  final String url;
  final httpClient = getHttpClient();
  late final http.Client client = ioc.IOClient(httpClient);
  final Duration defaultRequestTimeout;

  @override
  Future<Map<String, dynamic>> get(TronRequestDetails params, [Duration? timeout]) async {
    final response = await client.get(Uri.parse(params.url(url)), headers: {
      'Content-Type': 'application/json',
      if (url.contains("trongrid")) 'TRON-PRO-API-KEY': secrets.tronGridApiKey,
      if (url.contains("nownodes")) 'api-key': secrets.tronNowNodesApiKey,
    }).timeout(timeout ?? defaultRequestTimeout);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data;
  }

  @override
  Future<Map<String, dynamic>> post(TronRequestDetails params, [Duration? timeout]) async {
    final response = await client
        .post(Uri.parse(params.url(url)),
            headers: {
              'Content-Type': 'application/json',
              if (url.contains("trongrid")) 'TRON-PRO-API-KEY': secrets.tronGridApiKey,
              if (url.contains("nownodes")) 'api-key': secrets.tronNowNodesApiKey,
            },
            body: params.toRequestBody())
        .timeout(timeout ?? defaultRequestTimeout);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data;
  }
}
