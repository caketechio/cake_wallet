import 'dart:convert';

class ProxyToDaemonParams {
  final String body;
  final String uri;

  ProxyToDaemonParams({required this.body, required this.uri});

  Map<String, dynamic> toJson() => {
        'base64_body': base64Encode(utf8.encode(body)),
        'uri': uri,
      };
}
