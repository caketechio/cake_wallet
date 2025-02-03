import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_not_created_exception.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:http/http.dart' as http;

class StealthExExchangeProvider extends ExchangeProvider {
  StealthExExchangeProvider() : super(pairList: supportedPairs(_notSupported));

  static const List<CryptoCurrency> _notSupported = [];

  static final apiKey = secrets.stealthExBearerToken;
  static final _additionalFeePercent = double.tryParse(secrets.stealthExAdditionalFeePercent);
  static const _baseUrl = 'https://api.stealthex.io';
  static const _rangePath = '/v4/rates/range';
  static const _amountPath = '/v4/rates/estimated-amount';
  static const _exchangesPath = '/v4/exchanges';

  @override
  String get title => 'StealthEX';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => true;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.stealthEx;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final curFrom = isFixedRateMode ? to : from;
    final curTo = isFixedRateMode ? from : to;

    final headers = {'Authorization': apiKey, 'Content-Type': 'application/json'};
    final body = {
      'route': {
        'from': {'symbol': _getName(curFrom), 'network': _getNetwork(curFrom)},
        'to': {'symbol': _getName(curTo), 'network': _getNetwork(curTo)}
      },
      'estimation': isFixedRateMode ? 'reversed' : 'direct',
      'rate': isFixedRateMode ? 'fixed' : 'floating',
      'additional_fee_percent': _additionalFeePercent,
    };

    try {
      final response = await http.post(Uri.parse(_baseUrl + _rangePath),
          headers: headers, body: json.encode(body));
      if (response.statusCode != 200) {
        throw Exception('StealthEx fetch limits failed: ${response.body}');
      }
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final min = toDouble(responseJSON['min_amount']);
      final max = responseJSON['max_amount'] as double?;
      return Limits(min: min, max: max);
    } catch (e) {
      log(e.toString());
      throw Exception('StealthEx failed to fetch limits');
    }
  }

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    final response = await getEstimatedExchangeAmount(
        from: from, to: to, amount: amount, isFixedRateMode: isFixedRateMode);
    final estimatedAmount = response['estimated_amount'] as double? ?? 0.0;
    return estimatedAmount > 0.0
        ? isFixedRateMode
            ? amount / estimatedAmount
            : estimatedAmount / amount
        : 0.0;
  }

  @override
  Future<Trade> createTrade(
      {required TradeRequest request,
      required bool isFixedRateMode,
      required bool isSendAll}) async {
    String? rateId;
    String? validUntil;

    try {
      if (isFixedRateMode) {
        final response = await getEstimatedExchangeAmount(
            from: request.fromCurrency,
            to: request.toCurrency,
            amount: double.parse(request.toAmount),
            isFixedRateMode: isFixedRateMode);
        rateId = response['rate_id'] as String?;
        validUntil = response['valid_until'] as String?;
        if (rateId == null) throw TradeNotCreatedException(description);
      }

      final headers = {'Authorization': apiKey, 'Content-Type': 'application/json'};
      final body = {
        'route': {
          'from': {
            'symbol': _getName(request.fromCurrency),
            'network': _getNetwork(request.fromCurrency)
          },
          'to': {'symbol': _getName(request.toCurrency), 'network': _getNetwork(request.toCurrency)}
        },
        'estimation': isFixedRateMode ? 'reversed' : 'direct',
        'rate': isFixedRateMode ? 'fixed' : 'floating',
        if (isFixedRateMode) 'rate_id': rateId,
        'amount':
            isFixedRateMode ? double.parse(request.toAmount) : double.parse(request.fromAmount),
        'address': _normalizeAddress(request.toAddress),
        'refund_address': _normalizeAddress(request.refundAddress),
        'additional_fee_percent': _additionalFeePercent,
      };

      final response = await http.post(Uri.parse(_baseUrl + _exchangesPath),
          headers: headers, body: json.encode(body));

      if (response.statusCode != 201) {
        throw Exception('StealthEx create trade failed: ${response.body}');
      }
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final deposit = responseJSON['deposit'] as Map<String, dynamic>;
      final withdrawal = responseJSON['withdrawal'] as Map<String, dynamic>;

      final id = responseJSON['id'] as String;
      final from = deposit['symbol'] as String;
      final to = withdrawal['symbol'] as String;
      final payoutAddress = withdrawal['address'] as String;
      final depositAddress = deposit['address'] as String;
      final refundAddress = responseJSON['refund_address'] as String;
      final depositAmount = toDouble(deposit['amount']);
      final receiveAmount = toDouble(withdrawal['amount']);
      final status = responseJSON['status'] as String;
      final createdAtString = responseJSON['created_at'] as String;
      final extraId = deposit['extra_id'] as String?;

      final createdAt = DateTime.parse(createdAtString);
      final expiredAt = validUntil != null
          ? DateTime.parse(validUntil)
          : DateTime.now().add(Duration(minutes: 5));


      CryptoCurrency fromCurrency;
      if (request.fromCurrency.tag != null && request.fromCurrency.title.toLowerCase() == from) {
          fromCurrency = request.fromCurrency;
        } else {
          fromCurrency = CryptoCurrency.fromString(from);
        }

      CryptoCurrency toCurrency;
      if (request.toCurrency.tag != null && request.toCurrency.title.toLowerCase() == to) {
          toCurrency = request.toCurrency;
        } else {
          toCurrency = CryptoCurrency.fromString(to);
        }

      return Trade(
        id: id,
        from: fromCurrency,
        to: toCurrency,
        provider: description,
        inputAddress: depositAddress,
        payoutAddress: payoutAddress,
        refundAddress: refundAddress,
        amount: depositAmount.toString(),
        receiveAmount: receiveAmount.toString(),
        state: TradeState.deserialize(raw: status),
        createdAt: createdAt,
        expiredAt: expiredAt,
        extraId: extraId,
      );
    } catch (e) {
      log(e.toString());
      throw TradeNotCreatedException(description);
    }
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final headers = {'Authorization': apiKey, 'Content-Type': 'application/json'};

    final uri = Uri.parse('$_baseUrl$_exchangesPath/$id');
    final response = await ProxyWrapper().get(clearnetUri: uri, headers: headers);
    final responseString = await response.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      throw Exception('StealthEx fetch trade failed: ${responseString}');
    }
    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final deposit = responseJSON['deposit'] as Map<String, dynamic>;
    final withdrawal = responseJSON['withdrawal'] as Map<String, dynamic>;

    final respId = responseJSON['id'] as String;
    final from = deposit['symbol'] as String;
    final to = withdrawal['symbol'] as String;
    final payoutAddress = withdrawal['address'] as String;
    final depositAddress = deposit['address'] as String;
    final refundAddress = responseJSON['refund_address'] as String;
    final depositAmount = toDouble(deposit['amount']);
    final receiveAmount = toDouble(withdrawal['amount']);
    final status = responseJSON['status'] as String;
    final createdAtString = responseJSON['created_at'] as String;
    final createdAt = DateTime.parse(createdAtString);
    final extraId = deposit['extra_id'] as String?;

    return Trade(
      id: respId,
      from: CryptoCurrency.fromString(from),
      to: CryptoCurrency.fromString(to),
      provider: description,
      inputAddress: depositAddress,
      payoutAddress: payoutAddress,
      refundAddress: refundAddress,
      amount: depositAmount.toString(),
      receiveAmount: receiveAmount.toString(),
      state: TradeState.deserialize(raw: status),
      createdAt: createdAt,
      isRefund: status == 'refunded',
      extraId: extraId,
    );
  }

  Future<Map<String, dynamic>> getEstimatedExchangeAmount(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode}) async {
    final headers = {'Authorization': apiKey, 'Content-Type': 'application/json'};

    final body = {
      'route': {
        'from': {'symbol': _getName(from), 'network': _getNetwork(from)},
        'to': {'symbol': _getName(to), 'network': _getNetwork(to)}
      },
      'estimation': isFixedRateMode ? 'reversed' : 'direct',
      'rate': isFixedRateMode ? 'fixed' : 'floating',
      'amount': amount,
     'additional_fee_percent': _additionalFeePercent,
    };

    try {
      final response = await http.post(Uri.parse(_baseUrl + _amountPath),
          headers: headers, body: json.encode(body));
      if (response.statusCode != 200) return {};
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final rate = responseJSON['rate'] as Map<String, dynamic>?;
      return {
        'estimated_amount': responseJSON['estimated_amount'] as double?,
        if (rate != null) 'valid_until': rate['valid_until'] as String?,
        if (rate != null) 'rate_id': rate['id'] as String?
      };
    } catch (e) {
      log(e.toString());
      return {};
    }
  }

  double toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else {
      return 0.0;
    }
  }

  String _getName(CryptoCurrency currency) {
    if (currency == CryptoCurrency.usdcEPoly) return 'usdce';
    return currency.title.toLowerCase();
  }

  String _getNetwork(CryptoCurrency currency) {
    if (currency.tag == null) return 'mainnet';

    if (currency == CryptoCurrency.maticpoly) return 'mainnet';

    if (currency.tag == 'POLY') return 'matic';

    return currency.tag!.toLowerCase();
  }

  String _normalizeAddress(String address) =>
      address.startsWith('bitcoincash:') ? address.replaceFirst('bitcoincash:', '') : address;
}
