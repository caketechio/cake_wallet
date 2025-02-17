import 'dart:convert';
import 'package:http/http.dart';
import 'package:on_chain/solana/solana.dart';

class SolanaRPCHTTPService implements SolanaJSONRPCService {
  SolanaRPCHTTPService(
      {required this.url, Client? client, this.defaultRequestTimeout = const Duration(seconds: 30)})
      : client = client ?? Client();
  @override
  final String url;
  final Client client;
  final Duration defaultRequestTimeout;

  @override
  Future<Map<String, dynamic>> call(SolanaRequestDetails params, [Duration? timeout]) async {
    final response = await client.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json',
    }).timeout(timeout ?? defaultRequestTimeout);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data;
  }
}
