import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

const _fiatApiClearNetAuthority = 'fiat-api.cakewallet.com';
const _fiatApiOnionAuthority = 'n4z7bdcmwk2oyddxvzaap3x2peqcplh3pzdy7tpkk5ejz5n4mhfvoxqd.onion';
const _fiatApiPath = '/v2/rates';

Future<double> _fetchPrice(Map<String, dynamic> args) async {
  final crypto = args['crypto'] as String;
  final fiat = args['fiat'] as String;
  final torOnly = args['torOnly'] as bool;

  final Map<String, String> queryParams = {
    'interval_count': '1',
    'base': crypto.split(".").first,
    'quote': fiat,
    'key': secrets.fiatApiKey,
  };

  num price = 0.0;

  try {
    late final Uri uri;
    if (torOnly) {
      uri = Uri.http(_fiatApiOnionAuthority, _fiatApiPath, queryParams);
    } else {
      uri = Uri.https(_fiatApiClearNetAuthority, _fiatApiPath, queryParams);
    }

    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      return 0.0;
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final results = responseJSON['results'] as Map<String, dynamic>;

    if (results.isNotEmpty) {
      price = results.values.first as num;
    }

    return price.toDouble();
  } catch (e) {
    return price.toDouble();
  }
}

Future<double> _fetchPriceAsync(CryptoCurrency crypto, FiatCurrency fiat, bool torOnly) async =>
    compute(_fetchPrice, {
      'fiat': fiat.toString(),
      'crypto': crypto.toString(),
      'torOnly': torOnly,
    });

class FiatConversionService {
  static Future<double> fetchPrice({
    required CryptoCurrency crypto,
    required FiatCurrency fiat,
    required bool torOnly,
  }) async =>
      await _fetchPriceAsync(crypto, fiat, torOnly);
}
