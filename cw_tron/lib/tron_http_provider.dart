import 'package:http/http.dart' as http;
import '.secrets.g.dart' as secrets;
import 'package:on_chain/tron/tron.dart';

class TronHTTPProvider implements TronServiceProvider {
  TronHTTPProvider(
      {required this.url,
      http.Client? client,
      this.defaultRequestTimeout = const Duration(seconds: 30)})
      : client = client ?? http.Client();

  final String url;
  final http.Client client;
  final Duration defaultRequestTimeout;

  @override
  Future<TronServiceResponse<T>> doRequest<T>(TronRequestDetails params,
      {Duration? timeout}) async {
    if (!params.type.isPostRequest) {
      final response = await client.get(
        params.toUri(url),
        headers: {
          'Content-Type': 'application/json',
          if (url.contains("trongrid")) 'TRON-PRO-API-KEY': secrets.tronGridApiKey,
          if (url.contains("nownodes")) 'api-key': secrets.tronNowNodesApiKey,
        },
      ).timeout(timeout ?? defaultRequestTimeout);
      return params.toResponse(response.bodyBytes, response.statusCode);
    }

    final response = await client
        .post(
          params.toUri(url),
          headers: {
            'Content-Type': 'application/json',
            if (url.contains("trongrid")) 'TRON-PRO-API-KEY': secrets.tronGridApiKey,
            if (url.contains("nownodes")) 'api-key': secrets.tronNowNodesApiKey,
          },
          body: params.body,
        )
        .timeout(timeout ?? defaultRequestTimeout);
    return params.toResponse(response.bodyBytes, response.statusCode);
  }
}
