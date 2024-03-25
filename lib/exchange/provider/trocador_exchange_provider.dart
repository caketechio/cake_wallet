import 'dart:convert';
import 'dart:io';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/crypto_currency.dart';

class TrocadorExchangeProvider extends ExchangeProvider {
  TrocadorExchangeProvider({this.providerStates = const {}})
      : _lastUsedRateId = '',
        _provider = [],
        super(pairList: supportedPairs(_notSupported));

  final Map<String, bool> providerStates;

  static const List<String> availableProviders = [
    'Swapter',
    'StealthEx',
    'Simpleswap',
    'Swapuz'
        'ChangeNow',
    'Changehero',
    'FixedFloat',
    'LetsExchange',
    'Exolix',
    'Godex',
    'Exch',
    'CoinCraddle'
  ];

  static const List<CryptoCurrency> _notSupported = [
    CryptoCurrency.stx,
    CryptoCurrency.zaddr,
  ];

  static const apiKey = secrets.trocadorApiKey;
  static const onionApiAuthority = 'trocadorfyhlu27aefre5u7zri66gudtzdyelymftvr4yjwcxhfaqsid.onion';
  static const clearNetAuthority = 'trocador.app';
  static const markup = secrets.trocadorExchangeMarkup;
  static const newRatePath = '/api/new_rate';
  static const createTradePath = 'api/new_trade';
  static const tradePath = 'api/trade';
  static const coinPath = 'api/coin';

  String _lastUsedRateId;
  List<dynamic> _provider;

  @override
  String get title => 'Trocador';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => true;

  @override
  bool get supportsOnionAddress => true;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.trocador;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final params = {
      'api_key': apiKey,
      'ticker': _normalizeCurrency(from),
      'name': from.name,
    };

    final response = await proxyGet(coinPath, params);
    final responseBody = await utf8.decodeStream(response);

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(responseBody) as List<dynamic>;

    if (responseJSON.isEmpty) throw Exception('No data');

    final coinJson = responseJSON.first as Map<String, dynamic>;

    return Limits(
      min: coinJson['minimum'] as double,
      max: coinJson['maximum'] as double,
    );
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

      final params = <String, String>{
        'api_key': apiKey,
        'ticker_from': _normalizeCurrency(from),
        'ticker_to': _normalizeCurrency(to),
        'network_from': _networkFor(from),
        'network_to': _networkFor(to),
        if (!isFixedRateMode) 'amount_from': amount.toString(),
        if (isFixedRateMode) 'amount_to': amount.toString(),
        'payment': isFixedRateMode ? 'True' : 'False',
        'min_kycrating': 'C',
        'markup': markup,
      };

      final response = await proxyGet(newRatePath, params);
      final responseBody = await utf8.decodeStream(response);
      final responseJSON = json.decode(responseBody) as Map<String, dynamic>;
      final fromAmount = double.parse(responseJSON['amount_from'].toString());
      final toAmount = double.parse(responseJSON['amount_to'].toString());
      final rateId = responseJSON['trade_id'] as String? ?? '';

      var quotes = responseJSON['quotes']['quotes'] as List;
      _provider = quotes.map((quote) => quote['provider']).toList();

      if (rateId.isNotEmpty) _lastUsedRateId = rateId;

      return isReceiveAmount ? (amount / fromAmount) : (toAmount / amount);
    } catch (e) {
      print(e.toString());
      return 0.0;
    }
  }

  @override
  Future<Trade> createTrade({required TradeRequest request, required bool isFixedRateMode}) async {
    final params = {
      'api_key': apiKey,
      'ticker_from': _normalizeCurrency(request.fromCurrency),
      'ticker_to': _normalizeCurrency(request.toCurrency),
      'network_from': _networkFor(request.fromCurrency),
      'network_to': _networkFor(request.toCurrency),
      'payment': isFixedRateMode ? 'True' : 'False',
      'min_kycrating': 'C',
      'markup': markup,
      if (!isFixedRateMode) 'amount_from': request.fromAmount,
      if (isFixedRateMode) 'amount_to': request.toAmount,
      'address': request.toAddress,
      'refund': request.refundAddress
    };

    if (isFixedRateMode) {
      await fetchRate(
        from: request.fromCurrency,
        to: request.toCurrency,
        amount: double.tryParse(request.toAmount) ?? 0,
        isFixedRateMode: true,
        isReceiveAmount: true,
      );
      params['id'] = _lastUsedRateId;
    }

    String firstAvailableProvider = '';

    for (var provider in _provider) {
      if (providerStates.containsKey(provider) && providerStates[provider] == true) {
        firstAvailableProvider = provider as String;
        break;
      }
    }

    if (firstAvailableProvider.isEmpty) {
      throw Exception('No available provider is enabled');
    }

    params['provider'] = firstAvailableProvider;

    final response = await proxyGet(createTradePath, params);
    final responseBody = await utf8.decodeStream(response);

    if (response.statusCode == 400) {
      final responseJSON = json.decode(responseBody) as Map<String, dynamic>;
      final error = responseJSON['error'] as String;
      final message = responseJSON['message'] as String;
      throw Exception('${error}\n$message');
    }

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(responseBody) as Map<String, dynamic>;
    final id = responseJSON['trade_id'] as String;
    final inputAddress = responseJSON['address_provider'] as String;
    final refundAddress = responseJSON['refund_address'] as String;
    final status = responseJSON['status'] as String;
    final payoutAddress = responseJSON['address_user'] as String;
    final date = responseJSON['date'] as String;
    final password = responseJSON['password'] as String;
    final providerId = responseJSON['id_provider'] as String;
    final providerName = responseJSON['provider'] as String;

    return Trade(
        id: id,
        from: request.fromCurrency,
        to: request.toCurrency,
        provider: description,
        inputAddress: inputAddress,
        refundAddress: refundAddress,
        state: TradeState.deserialize(raw: status),
        password: password,
        providerId: providerId,
        providerName: providerName,
        createdAt: DateTime.tryParse(date)?.toLocal(),
        amount: responseJSON['amount_from']?.toString() ?? request.fromAmount,
        payoutAddress: payoutAddress);
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final response = await proxyGet(tradePath, {'api_key': apiKey, 'id': id});
    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');
    final String responseBody = await utf8.decodeStream(response);

    final responseListJson = json.decode(responseBody) as List;
    final responseJSON = responseListJson.first;
    final tradeId = responseJSON['trade_id'] as String;
    final payoutAddress = responseJSON['address_user'] as String;
    final refundAddress = responseJSON['refund_address'] as String;
    final inputAddress = responseJSON['address_provider'] as String;
    final fromAmount = responseJSON['amount_from']?.toString() ?? '0';
    final password = responseJSON['password'] as String;
    final providerId = responseJSON['id_provider'] as String;
    final providerName = responseJSON['provider'] as String;

    return Trade(
      id: tradeId,
      from: CryptoCurrency.fromString(responseJSON['ticker_from'] as String),
      to: CryptoCurrency.fromString(responseJSON['ticker_to'] as String),
      provider: description,
      inputAddress: inputAddress,
      refundAddress: refundAddress,
      createdAt: DateTime.parse(responseJSON['date'] as String),
      amount: fromAmount,
      state: TradeState.deserialize(raw: responseJSON['status'] as String),
      payoutAddress: payoutAddress,
      password: password,
      providerId: providerId,
      providerName: providerName,
    );
  }

  String _networkFor(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.eth:
        return 'ERC20';
      case CryptoCurrency.maticpoly:
        return 'Mainnet';
      case CryptoCurrency.usdcpoly:
      case CryptoCurrency.usdtPoly:
      case CryptoCurrency.usdcEPoly:
        return 'MATIC';
      case CryptoCurrency.zec:
        return 'Mainnet';
      default:
        return currency.tag != null ? _normalizeTag(currency.tag!) : 'Mainnet';
    }
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    switch (currency) {
      case CryptoCurrency.zec:
        return 'zec';
      case CryptoCurrency.usdcEPoly:
        return 'usdce';
      default:
        return currency.title.toLowerCase();
    }
  }

  String _normalizeTag(String tag) {
    switch (tag) {
      case 'ETH':
        return 'ERC20';
      case 'TRX':
        return 'TRC20';
      case 'LN':
        return 'Lightning';
      default:
        return tag.toLowerCase();
    }
  }

  Future<HttpClientResponse> proxyGet(String path, Map<String, String> queryParams) async {
    ProxyWrapper proxy = await getIt.get<ProxyWrapper>();
    Uri onionUri = Uri.http(onionApiAuthority, path, queryParams);
    Uri clearnetUri = Uri.http(clearNetAuthority, path, queryParams);
    return await proxy.get(
      onionUri: onionUri,
      clearnetUri: clearnetUri,
    );
  }
}
