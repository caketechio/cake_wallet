import 'dart:convert';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart' as http;

class WellKnownRecord {
  WellKnownRecord({
    required this.address,
    required this.name,
  });

  final String name;
  final String address;

  static Future<String?> checkWellKnownUsername(String username, CryptoCurrency currency) async {
    String jsonLocation = "";
    switch (currency) {
      case CryptoCurrency.nano:
        jsonLocation = "nano-currency";
        break;
      // TODO: add other currencies
      default:
        return null;
    }

    // split the string by the @ symbol:
    try {
      final List<String> splitStrs = username.split("@");
      String name = splitStrs.first.toLowerCase();
      final String domain = splitStrs.last;

      if (splitStrs.length == 3) {
        // for username like @alice@domain.org instead of alice@domain.org
        name = splitStrs[1];
      }

      if (name.isEmpty) {
        name = "_";
      }

      // lookup domain/.well-known/nano-currency.json and check if it has a nano address:
      final http.Response response = await http.get(
        Uri.parse("https://$domain/.well-known/$jsonLocation.json?names=$name"),
        headers: <String, String>{"Accept": "application/json"},
      );

      if (response.statusCode != 200) {
        return null;
      }
      final Map<String, dynamic> decoded = json.decode(response.body) as Map<String, dynamic>;

      // Access the first element in the names array and retrieve its address
      final List<dynamic> names = decoded["names"] as List<dynamic>;
      for (final dynamic item in names) {
        if (item["name"].toLowerCase() == name) {
          return item["address"] as String;
        }
      }
    } catch (e) {
      printV("error checking well-known username: $e");
    }
    return null;
  }

  static String formatDomainName(String name) {
    String formattedName = name;

    if (name.contains("@")) {
      formattedName = name.replaceAll("@", ".");
    }

    return formattedName;
  }

  static Future<WellKnownRecord?> fetchAddressAndName({
    required String formattedName,
    required CryptoCurrency currency,
  }) async {
    String name = formattedName;

    printV("formattedName: $formattedName");

    final address = await checkWellKnownUsername(formattedName, currency);

    if (address == null) {
      return null;
    }

    return WellKnownRecord(address: address, name: name);
  }
}
