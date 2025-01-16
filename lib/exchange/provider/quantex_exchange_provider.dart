import 'dart:convert';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_not_created_exception.dart';
import 'package:cake_wallet/exchange/trade_not_found_exception.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart';

class QuantexExchangeProvider extends ExchangeProvider {
  QuantexExchangeProvider() : super(pairList: supportedPairs(_notSupported));

  static final List<CryptoCurrency> _notSupported = [
    ...(CryptoCurrency.all
        .where((element) => ![
              CryptoCurrency.btc,
              CryptoCurrency.sol,
              CryptoCurrency.eth,
              CryptoCurrency.ltc,
              CryptoCurrency.ada,
              CryptoCurrency.bch,
              CryptoCurrency.usdt,
              CryptoCurrency.bnb,
              CryptoCurrency.xmr,
            ].contains(element))
        .toList())
  ];

  static final markup = secrets.quantexExchangeMarkup;

  static const apiAuthority = 'api.myquantex.com';
  static const getRate = '/api/swap/get-rate';
  static const getCoins = '/api/swap/get-coins';
  static const createOrder = '/api/swap/create-order';

  @override
  String get title => 'Quantex';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => false;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.quantex;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits({
    required CryptoCurrency from,
    required CryptoCurrency to,
    required bool isFixedRateMode,
  }) async {
    try {
      final uri = Uri.https(apiAuthority, getCoins);
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();

      final responseJSON = json.decode(responseString) as Map<String, dynamic>;

      if (response.statusCode != 200)
        throw Exception('Unexpected http status: ${response.statusCode}');

      final coinsInfo = responseJSON['data'] as List<dynamic>;

      for (var coin in coinsInfo) {
        if (coin['id'].toString().toUpperCase() == _normalizeCurrency(from)) {
          return Limits(
            min: double.parse(coin['min'].toString()),
            max: double.parse(coin['max'].toString()),
          );
        }
      }

      // coin not found:
      return Limits(min: 0, max: 0);
    } catch (e) {
      printV(e.toString());
      return Limits(min: 0, max: 0);
    }
  }

  @override
  Future<double> fetchRate({
    required CryptoCurrency from,
    required CryptoCurrency to,
    required double amount,
    required bool isFixedRateMode,
    required bool isReceiveAmount,
  }) async {
    try {
      if (amount == 0) return 0.0;

      final headers = <String, String>{};
      final params = <String, dynamic>{};
      final body = <String, String>{
        'coin_send': _normalizeCurrency(from),
        'coin_receive': _normalizeCurrency(to),
        'ref': 'cake',
      };

      final uri = Uri.https(apiAuthority, getRate, params);
      final response = await post(uri, body: body, headers: headers);
      final responseBody = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200)
        throw Exception('Unexpected http status: ${response.statusCode}');

      final data = responseBody['data'] as Map<String, dynamic>;
      double rate = double.parse(data['price'].toString());
      return rate;
    } catch (e) {
      printV("error fetching rate: ${e.toString()}");
      return 0.0;
    }
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
    try {
      final headers = <String, String>{};
      final params = <String, dynamic>{};
      var body = <String, dynamic>{
        'coin_send': _normalizeCurrency(request.fromCurrency),
        'coin_receive': _normalizeCurrency(request.toCurrency),
        'amount_send': request.fromAmount,
        'recipient': request.toAddress,
        'ref': 'cake',
        'markup': markup,
      };

      String? fromNetwork = _networkFor(request.fromCurrency);
      String? toNetwork = _networkFor(request.toCurrency);
      if (fromNetwork != null) body['coin_send_network'] = fromNetwork;
      if (toNetwork != null) body['coin_receive_network'] = toNetwork;

      final uri = Uri.https(apiAuthority, createOrder, params);
      final response = await post(uri, body: body, headers: headers);
      final responseBody = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 400 || responseBody["success"] == false) {
        final error = responseBody['errors'][0]['msg'] as String;
        throw TradeNotCreatedException(description, description: error);
      }

      if (response.statusCode != 200)
        throw Exception('Unexpected http status: ${response.statusCode}');

      final responseData = responseBody['data'] as Map<String, dynamic>;
      final receiveAmount = responseData["amount_receive"]?.toString();

      return Trade(
        id: responseData["order_id"] as String,
        inputAddress: responseData["server_address"] as String,
        amount: request.fromAmount,
        receiveAmount: receiveAmount ?? request.toAmount,
        from: request.fromCurrency,
        to: request.toCurrency,
        provider: description,
        createdAt: DateTime.now(),
        state: TradeState.created,
        payoutAddress: request.toAddress,
        isSendAll: isSendAll,
      );
    } catch (e) {
      printV("error creating trade: ${e.toString()}");
      throw TradeNotCreatedException(description, description: e.toString());
    }
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    try {
      final headers = <String, String>{};
      final params = <String, dynamic>{};
      var body = <String, dynamic>{
        'order_id': id,
      };

      final uri = Uri.https(apiAuthority, createOrder, params);
      final response = await post(uri, body: body, headers: headers);
      final responseBody = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 400 || responseBody["success"] == false) {
        final error = responseBody['errors'][0]['msg'] as String;
        throw TradeNotCreatedException(description, description: error);
      }

      if (response.statusCode != 200)
        throw Exception('Unexpected http status: ${response.statusCode}');

      final responseData = responseBody['data'] as Map<String, dynamic>;
      final fromCurrency = responseData['coin_send'] as String;
      final from = CryptoCurrency.fromString(fromCurrency);
      final toCurrency = responseData['coin_receive'] as String;
      final to = CryptoCurrency.fromString(toCurrency);
      final inputAddress = responseData['server_address'] as String;
      final status = responseData['status'] as String;
      final state = TradeState.deserialize(raw: status);
      final response_id = responseData['order_id'] as String;
      final expectedSendAmount = responseData['amount_send'] as String;

      return Trade(
        id: response_id,
        from: from,
        to: to,
        provider: description,
        inputAddress: inputAddress,
        amount: expectedSendAmount,
        state: state,
      );
    } catch (e) {
      printV("error getting trade: ${e.toString()}");
      throw TradeNotFoundException(
        id,
        provider: description,
        description: e.toString(),
      );
    }
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    switch (currency) {
      default:
        return currency.title.toUpperCase();
    }
  }

  String? _networkFor(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.usdt:
        return "USDT_ERC20";
      case CryptoCurrency.bnb:
        return "BNB_BSC";
      default:
        return null;
    }
  }
}
