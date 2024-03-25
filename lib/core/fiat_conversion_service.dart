import 'dart:io';

import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'dart:convert';
import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:flutter/foundation.dart';

const _fiatApiClearNetAuthority = 'fiat-api.cakewallet.com';
const _fiatApiOnionAuthority = 'n4z7bdcmwk2oyddxvzaap3x2peqcplh3pzdy7tpkk5ejz5n4mhfvoxqd.onion';
const _fiatApiPath = '/v2/rates';

Future<double> _fetchPrice(Map<String, dynamic> args) async {
  final crypto = args['crypto'] as String;
  final fiat = args['fiat'] as String;
  final mainThreadProxyPort = args['port'] as int;
  final torConnectionMode = TorConnectionMode.deserialize(raw: args['torConnectionMode'] as int);
  final torConnectionStatus = TorConnectionStatus.deserialize(raw: args['torConnectionStatus'] as int);


  final Map<String, String> queryParams = {
    'interval_count': '1',
    'base': crypto.split(".").first,
    'quote': fiat,
    'key': secrets.fiatApiKey,
  };

  num price = 0.0;

  try {
    final Uri onionUri = Uri.http(_fiatApiOnionAuthority, _fiatApiPath, queryParams);
    final Uri clearnetUri = Uri.https(_fiatApiClearNetAuthority, _fiatApiPath, queryParams);

    ProxyWrapper proxy = ProxyWrapper();

    late HttpClientResponse httpResponse;
    late String responseBody;
    late int statusCode;

    // the proxywrapper class wraps all of the complexity of retrying on clearnet / settings handling:
    try {
      httpResponse = await proxy.get(
        onionUri: onionUri,
        clearnetUri: clearnetUri,
        portOverride: mainThreadProxyPort,
        torConnectionMode: torConnectionMode,
        torConnectionStatus: torConnectionStatus,
      );

      responseBody = await utf8.decodeStream(httpResponse);
      statusCode = httpResponse.statusCode;
    } catch (e) {
      // we weren't able to get a response with these settings:
      return 0.0;
    }

    if (statusCode != 200) {
      return 0.0;
    }

    final responseJSON = json.decode(responseBody) as Map<String, dynamic>;
    final results = responseJSON['results'] as Map<String, dynamic>;

    if (results.isNotEmpty) {
      price = results.values.first as num;
    }

    return price.toDouble();
  } catch (e) {
    return price.toDouble();
  }
}

Future<double> _fetchPriceAsync(CryptoCurrency crypto, FiatCurrency fiat) async {
  final settingsStore = getIt.get<SettingsStore>();
  final mode = settingsStore.torConnectionMode;
  final status = getIt.get<TorViewModel>().torConnectionStatus;
  ProxyWrapper proxy = await getIt.get<ProxyWrapper>();
  return compute(_fetchPrice, {
    'fiat': fiat.toString(),
    'crypto': crypto.toString(),
    'port': proxy.getPort(),
    'torConnectionMode': mode.raw,
    'torConnectionStatus': status.raw,
  });
}

class FiatConversionService {
  static Future<double> fetchPrice({
    required CryptoCurrency crypto,
    required FiatCurrency fiat,
  }) async =>
      await _fetchPriceAsync(crypto, fiat);
}
