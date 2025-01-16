import 'dart:convert';
import 'dart:io';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_not_found_exception.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/distribution_info.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart';

class ChangeNowExchangeProvider extends ExchangeProvider {
  ChangeNowExchangeProvider({required SettingsStore settingsStore})
      : _settingsStore = settingsStore,
        _lastUsedRateId = '',
        super(pairList: supportedPairs(_notSupported));

  static const List<CryptoCurrency> _notSupported = [
    CryptoCurrency.zaddr,
    CryptoCurrency.xhv,
  ];

  static final apiKey =
      DeviceInfo.instance.isMobile ? secrets.changeNowApiKey : secrets.changeNowApiKeyDesktop;
  static const apiAuthority = 'api.changenow.io';
  static const createTradePath = '/v2/exchange';
  static const findTradeByIdPath = '/v2/exchange/by-id';
  static const estimatedAmountPath = '/v2/exchange/estimated-amount';
  static const rangePath = '/v2/exchange/range';
  static const apiHeaderKey = 'x-changenow-api-key';

  final SettingsStore _settingsStore;
  String _lastUsedRateId;

  @override
  String get title => 'ChangeNOW';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => true;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.changeNow;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final headers = {apiHeaderKey: apiKey};
    final params = <String, String>{
      'fromCurrency': _normalizeCurrency(from),
      'toCurrency': _normalizeCurrency(to),
      'fromNetwork': _networkFor(from),
      'toNetwork': _networkFor(to),
      'flow': _getFlow(isFixedRateMode)
    };
    final uri = Uri.https(apiAuthority, rangePath, params);
    final response = await ProxyWrapper().get(clearnetUri: uri, headers: headers);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode == 400) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['error'] as String;
      final message = responseJSON['message'] as String;
      throw Exception('${error}\n$message');
    }

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    return Limits(
        min: responseJSON['minAmount'] as double?, max: responseJSON['maxAmount'] as double?);
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

      final headers = {apiHeaderKey: apiKey};
      final isReverse = isReceiveAmount;
      final type = isReverse ? 'reverse' : 'direct';
      final params = <String, String>{
        'fromCurrency': _normalizeCurrency(from),
        'toCurrency': _normalizeCurrency(to),
        'fromNetwork': _networkFor(from),
        'toNetwork': _networkFor(to),
        'type': type,
        'flow': _getFlow(isFixedRateMode)
      };

      if (isReverse)
        params['toAmount'] = amount.toString();
      else
        params['fromAmount'] = amount.toString();

      final uri = Uri.https(apiAuthority, estimatedAmountPath, params);
      final response = await ProxyWrapper().get(clearnetUri: uri, headers: headers);
      final responseString = await response.transform(utf8.decoder).join();
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final fromAmount = double.parse(responseJSON['fromAmount'].toString());
      final toAmount = double.parse(responseJSON['toAmount'].toString());
      final rateId = responseJSON['rateId'] as String? ?? '';

      if (rateId.isNotEmpty) _lastUsedRateId = rateId;

      return isReverse ? (amount / fromAmount) : (toAmount / amount);
    } catch (e) {
      printV(e.toString());
      return 0.0;
    }
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
    final distributionPath = await DistributionInfo.instance.getDistributionPath();
    final formattedAppVersion = int.tryParse(_settingsStore.appVersion.replaceAll('.', '')) ?? 0;
    final payload = {
      'app': isMoneroOnly ? 'monerocom' : 'cakewallet',
      'device': Platform.operatingSystem,
      'distribution': distributionPath,
      'version': formattedAppVersion
    };
    final headers = {apiHeaderKey: apiKey, 'Content-Type': 'application/json'};
    final type = isFixedRateMode ? 'reverse' : 'direct';
    final body = <String, dynamic>{
      'fromCurrency': _normalizeCurrency(request.fromCurrency),
      'toCurrency': _normalizeCurrency(request.toCurrency),
      'fromNetwork': _networkFor(request.fromCurrency),
      'toNetwork': _networkFor(request.toCurrency),
      if (!isFixedRateMode) 'fromAmount': request.fromAmount,
      if (isFixedRateMode) 'toAmount': request.toAmount,
      'address': request.toAddress,
      'flow': _getFlow(isFixedRateMode),
      'type': type,
      'refundAddress': request.refundAddress,
      'payload': payload,
    };

    if (isFixedRateMode) {
      // since we schedule to calculate the rate every 5 seconds we need to ensure that
      // we have the latest rate id with the given inputs before creating the trade
      await fetchRate(
        from: request.fromCurrency,
        to: request.toCurrency,
        amount: double.tryParse(request.toAmount) ?? 0,
        isFixedRateMode: true,
        isReceiveAmount: true,
      );
      body['rateId'] = _lastUsedRateId;
    }

    final uri = Uri.https(apiAuthority, createTradePath);
    final response = await post(uri, headers: headers, body: json.encode(body));

    if (response.statusCode == 400) {
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final error = responseJSON['error'] as String;
      final message = responseJSON['message'] as String;
      throw Exception('${error}\n$message');
    }

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final id = responseJSON['id'] as String;
    final inputAddress = responseJSON['payinAddress'] as String;
    final refundAddress = responseJSON['refundAddress'] as String;
    final extraId = responseJSON['payinExtraId'] as String?;
    final payoutAddress = responseJSON['payoutAddress'] as String;
    final fromAmount = responseJSON['fromAmount']?.toString();
    final toAmount = responseJSON['toAmount']?.toString();

    return Trade(
      id: id,
      from: request.fromCurrency,
      to: request.toCurrency,
      provider: description,
      inputAddress: inputAddress,
      refundAddress: refundAddress,
      extraId: extraId,
      createdAt: DateTime.now(),
      amount: fromAmount ?? request.fromAmount,
      receiveAmount: toAmount ?? request.toAmount,
      state: TradeState.created,
      payoutAddress: payoutAddress,
      isSendAll: isSendAll,
    );
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final headers = {apiHeaderKey: apiKey};
    final params = <String, String>{'id': id};
    final uri = Uri.https(apiAuthority, findTradeByIdPath, params);
    final response = await ProxyWrapper().get(clearnetUri: uri, headers: headers);
    final responseString = await response.transform(utf8.decoder).join();

    if (response.statusCode == 404) throw TradeNotFoundException(id, provider: description);

    if (response.statusCode == 400) {
      final responseJSON = json.decode(responseString) as Map<String, dynamic>;
      final error = responseJSON['message'] as String;

      throw TradeNotFoundException(id, provider: description, description: error);
    }

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(responseString) as Map<String, dynamic>;
    final fromCurrency = responseJSON['fromCurrency'] as String;
    final from = CryptoCurrency.fromString(fromCurrency);
    final toCurrency = responseJSON['toCurrency'] as String;
    final to = CryptoCurrency.fromString(toCurrency);
    final inputAddress = responseJSON['payinAddress'] as String;
    final expectedSendAmount = responseJSON['expectedAmountFrom'].toString();
    final status = responseJSON['status'] as String;
    final state = TradeState.deserialize(raw: status);
    final extraId = responseJSON['payinExtraId'] as String?;
    final outputTransaction = responseJSON['payoutHash'] as String?;
    final expiredAtRaw = responseJSON['validUntil'] as String?;
    final payoutAddress = responseJSON['payoutAddress'] as String;
    final expiredAt = DateTime.tryParse(expiredAtRaw ?? '')?.toLocal();

    return Trade(
        id: id,
        from: from,
        to: to,
        provider: description,
        inputAddress: inputAddress,
        amount: expectedSendAmount,
        state: state,
        extraId: extraId,
        expiredAt: expiredAt,
        outputTransaction: outputTransaction,
        payoutAddress: payoutAddress);
  }

  String _getFlow(bool isFixedRate) => isFixedRate ? 'fixed-rate' : 'standard';

  String _networkFor(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.usdt:
        return 'btc';
      default:
        return currency.tag != null ? _normalizeTag(currency.tag!) : currency.title.toLowerCase();
    }
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    if (currency.title == "USDC" && currency.tag == "POLY") {
      throw "Only Bridged USDC (USDC.e) is allowed in ChangeNow";
    }
    switch (currency) {
      case CryptoCurrency.zec:
        return 'zec';
      default:
        return currency.title.toLowerCase();
    }
  }

  String _normalizeTag(String tag) {
    switch (tag) {
      case 'POLY':
        return 'matic';
      case 'LN':
        return 'lightning';
      case 'AVAXC':
        return 'cchain';
      default:
        return tag.toLowerCase();
    }
  }
}
