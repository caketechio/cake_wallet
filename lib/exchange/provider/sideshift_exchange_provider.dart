import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
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

class SideShiftExchangeProvider extends ExchangeProvider {
  SideShiftExchangeProvider() : super(pairList: supportedPairs(_notSupported));

  static const List<CryptoCurrency> _notSupported = [
    CryptoCurrency.xhv,
    CryptoCurrency.dcr,
    CryptoCurrency.kmd,
    CryptoCurrency.oxt,
    CryptoCurrency.pivx,
    CryptoCurrency.rune,
    CryptoCurrency.rvn,
    CryptoCurrency.scrt,
    CryptoCurrency.stx,
    CryptoCurrency.bttc,
    CryptoCurrency.usdt,
    CryptoCurrency.eos,
    CryptoCurrency.xmr,
  ];

  static const affiliateId = secrets.sideShiftAffiliateId;
  static const apiBaseUrl = 'https://sideshift.ai/api';
  static const rangePath = '/v2/pair';
  static const orderPath = '/v2/shifts';
  static const quotePath = '/v2/quotes';
  static const permissionPath = '/v2/permissions';

  @override
  String get title => 'SideShift';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => true;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.sideShift;

  @override
  Future<bool> checkIsAvailable() async {
    const url = apiBaseUrl + permissionPath;
    final uri = Uri.parse(url);
    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();
    if (response.statusCode == 500) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['error']['message'] as String;

      throw Exception('$error');
    }

    if (response.statusCode != 200) return false;

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    return responseJSON['createShift'] as bool;
  }

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final fromCurrency = isFixedRateMode ? to : from;
    final toCurrency = isFixedRateMode ? from : to;

    final fromNetwork = _networkFor(fromCurrency);
    final toNetwork = _networkFor(toCurrency);

    final url =
        "$apiBaseUrl$rangePath/${fromCurrency.title.toLowerCase()}-$fromNetwork/${toCurrency.title.toLowerCase()}-$toNetwork";

    final uri = Uri.parse(url);
    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode == 500) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['error']['message'] as String;

      throw Exception('$error');
    }

    if (response.statusCode != 200) {
      throw Exception('Unexpected http status: ${response.statusCode}');
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final min = double.tryParse(responseJSON['min'] as String? ?? '');
    final max = double.tryParse(responseJSON['max'] as String? ?? '');

    if (isFixedRateMode) {
      final currentRate = double.parse(responseJSON['rate'] as String);
      return Limits(
        min: min != null ? (min * currentRate) : null,
        max: max != null ? (max * currentRate) : null,
      );
    }

    return Limits(min: min, max: max);
  }

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    try {
      if (amount == 0) return 0.0;

      final fromCurrency = from.title.toLowerCase();
      final toCurrency = to.title.toLowerCase();
      final depositNetwork = _networkFor(from);
      final settleNetwork = _networkFor(to);

      final url =
          "$apiBaseUrl$rangePath/$fromCurrency-$depositNetwork/$toCurrency-$settleNetwork?amount=$amount";

      final uri = Uri.parse(url);
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;

      if (response.statusCode == 500) {
        final responseJSON = json.decode(responseString) as Map<String, dynamic>;
        final error = responseJSON['error']['message'] as String;

        throw Exception('SideShift Internal Server Error: $error');
      }

      if (response.statusCode != 200) {
        throw Exception('Unexpected http status: ${response.statusCode}');
      }

      return double.parse(responseJSON['rate'] as String);
    } catch (e) {
      printV(e.toString());
      return 0.00;
    }
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
    String url = '';
    final body = {
      'affiliateId': affiliateId,
      'settleAddress': request.toAddress,
      'refundAddress': request.refundAddress,
    };

    if (isFixedRateMode) {
      final quoteId = await _createQuote(request);
      body['quoteId'] = quoteId;

      url = apiBaseUrl + orderPath + '/fixed';
    } else {
      url = apiBaseUrl + orderPath + '/variable';
      body["depositCoin"] = _normalizeCurrency(request.fromCurrency);
      body["settleCoin"] = _normalizeCurrency(request.toCurrency);
      body["settleNetwork"] = _networkFor(request.toCurrency);
      body["depositNetwork"] = _networkFor(request.fromCurrency);
    }
    final headers = {'Content-Type': 'application/json'};

    final uri = Uri.parse(url);
    final response = await post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode != 201) {
      if (response.statusCode == 400) {
        final responseJSON = json.decode(response.body) as Map<String, dynamic>;
        final error = responseJSON['error']['message'] as String;

        throw TradeNotCreatedException(description, description: error);
      }

      throw TradeNotCreatedException(description);
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final id = responseJSON['id'] as String;
    final inputAddress = responseJSON['depositAddress'] as String;
    final settleAddress = responseJSON['settleAddress'] as String;
    final depositAmount = responseJSON['depositAmount'] as String?;
    final depositMemo = responseJSON['depositMemo'] as String?;

    return Trade(
      id: id,
      provider: description,
      from: request.fromCurrency,
      to: request.toCurrency,
      inputAddress: inputAddress,
      refundAddress: settleAddress,
      state: TradeState.created,
      amount: depositAmount ?? request.fromAmount,
      receiveAmount: request.toAmount,
      payoutAddress: settleAddress,
      createdAt: DateTime.now(),
      isSendAll: isSendAll,
      extraId: depositMemo
    );
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final url = apiBaseUrl + orderPath + '/' + id;
    final uri = Uri.parse(url);
    final response = await ProxyWrapper().get(clearnetUri: uri);
    final responseString = await response.transform(utf8.decoder).join();
    if (response.statusCode == 404) {
      throw TradeNotFoundException(id, provider: description);
    }

    if (response.statusCode == 400) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['error']['message'] as String;

      throw TradeNotFoundException(id, provider: description, description: error);
    }

    if (response.statusCode != 200) {
      throw Exception('Unexpected http status: ${response.statusCode}');
    }

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final fromCurrency = responseJSON['depositCoin'] as String;
    final toCurrency = responseJSON['settleCoin'] as String;
    final inputAddress = responseJSON['depositAddress'] as String;
    final expectedSendAmount = responseJSON['depositAmount'] as String?;
    final status = responseJSON['status'] as String?;
    final settleAddress = responseJSON['settleAddress'] as String;
    final isVariable = (responseJSON['type'] as String) == 'variable';
    final expiredAtRaw = responseJSON['expiresAt'] as String;
    final expiredAt = isVariable ? null : DateTime.tryParse(expiredAtRaw)?.toLocal();
    final depositMemo = responseJSON['depositMemo'] as String?;

    return Trade(
        id: id,
        from: CryptoCurrency.fromString(fromCurrency),
        to: CryptoCurrency.fromString(toCurrency),
        provider: description,
        inputAddress: inputAddress,
        amount: expectedSendAmount ?? '',
        state: TradeState.deserialize(raw: status ?? 'created'),
        expiredAt: expiredAt,
        payoutAddress: settleAddress,
        extraId: depositMemo);
  }

  Future<String> _createQuote(TradeRequest request) async {
    final url = apiBaseUrl + quotePath;
    final headers = {'Content-Type': 'application/json'};
    final body = {
      'depositCoin': _normalizeCurrency(request.fromCurrency),
      'settleCoin': _normalizeCurrency(request.toCurrency),
      'affiliateId': affiliateId,
      'settleAmount': request.toAmount,
      'settleNetwork': _networkFor(request.toCurrency),
      'depositNetwork': _networkFor(request.fromCurrency),
    };
    final uri = Uri.parse(url);
    final response = await post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode != 201) {
      if (response.statusCode == 400) {
        final responseJSON = json.decode(response.body) as Map<String, dynamic>;
        final error = responseJSON['error']['message'] as String;

        throw TradeNotCreatedException(description, description: error);
      }

      throw TradeNotCreatedException(description);
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;

    return responseJSON['id'] as String;
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.usdcEPoly:
        return 'usdc';
      default:
        return currency.title.toLowerCase();
    }
  }

  String _networkFor(CryptoCurrency currency) =>
      currency.tag != null ? _normalizeTag(currency.tag!) : 'mainnet';

  String _normalizeTag(String tag) {
    switch (tag) {
      case 'ETH':
        return 'ethereum';
      case 'TRX':
        return 'tron';
      case 'LN':
        return 'lightning';
      case 'POLY':
        return 'polygon';
      case 'ZEC':
        return 'zcash';
      case 'AVAXC':
        return 'avax';
      default:
        return tag.toLowerCase();
    }
  }
}
