import 'dart:convert';

class ProxyToDaemonResult {
  final String body;
  final int responseCode;

  ProxyToDaemonResult({required this.body, required this.responseCode});

  factory ProxyToDaemonResult.fromJson(Map<String, dynamic> json) => ProxyToDaemonResult(
        body: utf8.decode(base64Decode(json['base64_body'] as String? ?? '')),
        responseCode: json['response_code'] as int? ?? 0,
      );
}
