import 'dart:convert';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart' as http;

class ZanoAlias {
  static Future<String?> fetchZanoAliasAddress(String alias) async {
    try {
      final uri = Uri.parse("https://zano.cakewallet.com:443/json_rpc");
      final response = await http.post(
        uri,
        body: json.encode({
          "id": 0,
          "jsonrpc": "2.0",
          "method": "get_alias_details",
          "params": {"alias": alias}
        }),
      );
      final jsonParsed = json.decode(response.body) as Map<String, dynamic>;

      return jsonParsed['result']['alias_details']['address'] as String?;
    } catch (e) {
      printV('Zano Alias error: ${e.toString()}');
    }

    return null;
  }
}
