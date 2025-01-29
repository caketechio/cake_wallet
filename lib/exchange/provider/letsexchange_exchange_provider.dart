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
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart' as http;

class LetsExchangeExchangeProvider extends ExchangeProvider {
  LetsExchangeExchangeProvider() : super(pairList: supportedPairs(_notSupported));

  static const List<CryptoCurrency> _notSupported = [];

  static const apiKey = secrets.letsExchangeBearerToken;
  static const _baseUrl = 'api.letsexchange.io';
  static const _infoPath = '/api/v1/info';
  static const _infoRevertPath = '/api/v1/info-revert';
  static const _createTransactionPath = '/api/v1/transaction';
  static const _createTransactionRevertPath = '/api/v1/transaction-revert';
  static const _getTransactionPath = '/api/v1/transaction';

  static const _affiliateId = secrets.letsExchangeAffiliateId;

  @override
  String get title => 'LetsExchange';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => true;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.letsExchange;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final networkFrom = _getNetworkType(from);
    final networkTo = _getNetworkType(to);

    try {
      final params = {
        'from': from.title,
        'to': to.title,
        if (networkFrom != null) 'network_from': networkFrom,
        if (networkTo != null) 'network_to': networkTo,
        'amount': '1',
        'affiliate_id': _affiliateId
      };

      final responseJSON = await _getInfo(params, isFixedRateMode);
      final min = double.tryParse(responseJSON['min_amount'] as String);
      final max = double.tryParse(responseJSON['max_amount'] as String);
      return Limits(min: min, max: max);
    } catch (e) {
      log(e.toString());
      throw Exception('Failed to fetch limits');
    }
  }

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    final networkFrom = _getNetworkType(from);
    final networkTo = _getNetworkType(to);
    try {
      final params = {
        'from': from.title,
        'to': to.title,
        if (networkFrom != null) 'network_from': networkFrom,
        if (networkTo != null) 'network_to': networkTo,
        'amount': amount.toString(),
        'affiliate_id': _affiliateId
      };

      final responseJSON = await _getInfo(params, isFixedRateMode);

      final amountToGet = double.tryParse(responseJSON['amount'] as String) ?? 0.0;

      if (amountToGet == 0.0) return 0.0;

      return isFixedRateMode ? amount / amountToGet : amountToGet / amount;
    } catch (e) {
      printV(e.toString());
      return 0.0;
    }
  }

  @override
  Future<Trade> createTrade(
      {required TradeRequest request,
      required bool isFixedRateMode,
      required bool isSendAll}) async {
    final networkFrom = _getNetworkType(request.fromCurrency);
    final networkTo = _getNetworkType(request.toCurrency);
    try {
      final params = {
        'from': request.fromCurrency.title,
        'to': request.toCurrency.title,
        if (networkFrom != null) 'network_from': networkFrom,
        if (networkTo != null) 'network_to': networkTo,
        'amount': isFixedRateMode ? request.toAmount.toString() : request.fromAmount.toString(),
        'affiliate_id': _affiliateId
      };

      final responseInfoJSON = await _getInfo(params, isFixedRateMode);
      final rateId = responseInfoJSON['rate_id'] as String;

      final withdrawalAddress = _normalizeBchAddress(request.toAddress);
      final returnAddress = _normalizeBchAddress(request.refundAddress);

      final tradeParams = {
        'coin_from': request.fromCurrency.title,
        'coin_to': request.toCurrency.title,
        if (!isFixedRateMode) 'deposit_amount': request.fromAmount.toString(),
        'withdrawal': withdrawalAddress,
        if (isFixedRateMode) 'withdrawal_amount': request.toAmount.toString(),
        'withdrawal_extra_id': '',
        'return': returnAddress,
        'rate_id': rateId,
        if (networkFrom != null) 'network_from': networkFrom,
        if (networkTo != null) 'network_to': networkTo,
        'affiliate_id': _affiliateId
      };

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': apiKey
      };

      final uri = Uri.https(_baseUrl,
          isFixedRateMode ? _createTransactionRevertPath : _createTransactionPath, tradeParams);
      final response = await http.post(uri, headers: headers);

      if (response.statusCode != 200) {
        throw Exception('LetsExchange create trade failed: ${response.body}');
      }
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final id = responseJSON['transaction_id'] as String;
      final from = responseJSON['coin_from'] as String;
      final to = responseJSON['coin_to'] as String;
      final payoutAddress = responseJSON['withdrawal'] as String;
      final depositAddress = responseJSON['deposit'] as String;
      final refundAddress = responseJSON['return'] as String;
      final depositAmount = responseJSON['deposit_amount'] as String;
      final receiveAmount = responseJSON['withdrawal_amount'] as String;
      final status = responseJSON['status'] as String;
      final createdAtString = responseJSON['created_at'] as String;
      final expiredAtTimestamp = responseJSON['expired_at'] as int;
      final extraId = responseJSON['deposit_extra_id'] as String?;

      final createdAt = DateTime.parse(createdAtString);
      final expiredAt = DateTime.fromMillisecondsSinceEpoch(expiredAtTimestamp * 1000);

      CryptoCurrency fromCurrency;
      if (request.fromCurrency.tag != null && request.fromCurrency.title == from) {
        fromCurrency = request.fromCurrency;
      } else {
        fromCurrency = CryptoCurrency.fromString(from);
      }

      CryptoCurrency toCurrency;
      if (request.toCurrency.tag != null && request.toCurrency.title == to) {
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
        amount: depositAmount,
        receiveAmount: receiveAmount,
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
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': apiKey
    };

    final url = Uri.https(_baseUrl, '$_getTransactionPath/$id');
    final response = await ProxyWrapper().get(clearnetUri: url, headers: headers);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception('LetsExchange fetch trade failed: ${responseString}');
    }
    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final from = responseJSON['coin_from'] as String;
    final to = responseJSON['coin_to'] as String;
    final payoutAddress = responseJSON['withdrawal'] as String;
    final depositAddress = responseJSON['deposit'] as String;
    final refundAddress = responseJSON['return'] as String;
    final depositAmount = responseJSON['deposit_amount'] as String;
    final receiveAmount = responseJSON['withdrawal_amount'] as String;
    final status = responseJSON['status'] as String;
    final createdAtString = responseJSON['created_at'] as String;
    final expiredAtTimestamp = responseJSON['expired_at'] as int;
    final extraId = responseJSON['deposit_extra_id'] as String?;

    final createdAt = DateTime.parse(createdAtString);
    final expiredAt = DateTime.fromMillisecondsSinceEpoch(expiredAtTimestamp * 1000);

    return Trade(
      id: id,
      from: CryptoCurrency.fromString(from),
      to: CryptoCurrency.fromString(to),
      provider: description,
      inputAddress: depositAddress,
      payoutAddress: payoutAddress,
      refundAddress: refundAddress,
      amount: depositAmount,
      receiveAmount: receiveAmount,
      state: TradeState.deserialize(raw: status),
      createdAt: createdAt,
      expiredAt: expiredAt,
      isRefund: status == 'refund',
      extraId: extraId,
    );
  }

  Future<Map<String, dynamic>> _getInfo(Map<String, String> params, bool isFixedRateMode) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': apiKey
    };

    try {
      final uri = Uri.https(_baseUrl, isFixedRateMode ? _infoRevertPath : _infoPath, params);
      final response = await http.post(uri, headers: headers);
      if (response.statusCode != 200) {
        throw Exception('LetsExchange fetch info failed: ${response.body}');
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('LetsExchange failed to fetch info ${e.toString()}');
    }
  }

  String? _getNetworkType(CryptoCurrency currency) {
    if (currency.tag != null && currency.tag!.isNotEmpty) {
      switch (currency.tag!) {
        case 'TRX':
          return 'TRC20';
        case 'ETH':
          return 'ERC20';
        case 'BSC':
          return 'BEP20';
        default:
          return currency.tag!;
      }
    }
    return currency.title;
  }

  String _normalizeBchAddress(String address) =>
      address.startsWith('bitcoincash:') ? address.substring(12) : address;
}
