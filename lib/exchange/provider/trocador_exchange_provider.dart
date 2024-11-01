import 'dart:convert';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:http/http.dart';

class TrocadorExchangeProvider extends ExchangeProvider {
  TrocadorExchangeProvider({this.useTorOnly = false, this.providerStates = const {}})
      : _lastUsedRateId = '',
        _provider = [],
        super(pairList: supportedPairs(_notSupported));

  bool useTorOnly;
  Map<String, bool> providerStates;

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
  static const providersListPath = '/api/exchanges';

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

    final uri = await _getUri(coinPath, params);
    final response = await get(uri);

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(response.body) as List<dynamic>;

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

      final uri = await _getUri(newRatePath, params);
      final response = await get(uri);
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final fromAmount = double.parse(responseJSON['amount_from'].toString());
      final toAmount = double.parse(responseJSON['amount_to'].toString());
      final rateId = responseJSON['trade_id'] as String? ?? '';

      var quotes = responseJSON['quotes']['quotes'] as List;
      _provider = quotes
          .where((quote) =>
              providerStates.containsKey(quote['provider']) &&
              providerStates[quote['provider']] == true)
          .map((quote) => quote['provider'])
          .toList();

      if (_provider.isEmpty) {
        throw Exception('No enabled providers found for the selected trade.');
      }

      if (rateId.isNotEmpty) _lastUsedRateId = rateId;

      return isReceiveAmount ? (amount / fromAmount) : (toAmount / amount);
    } catch (e) {
      print(e.toString());
      return 0.0;
    }
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
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

    if (_provider.isEmpty) {
      throw Exception('No available provider is enabled');
    }

    params['provider'] = _provider.first as String;

    final uri = await _getUri(createTradePath, params);
    final response = await get(uri);

    if (response.statusCode == 400) {
      final responseJSON = json.decode(response.body) as Map<String, dynamic>;
      final error = responseJSON['error'] as String;
      final message = responseJSON['message'] as String;
      throw Exception('${error}\n$message');
    }

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final id = responseJSON['trade_id'] as String;
    final inputAddress = responseJSON['address_provider'] as String;
    final refundAddress = responseJSON['refund_address'] as String;
    final status = responseJSON['status'] as String;
    final payoutAddress = responseJSON['address_user'] as String;
    final date = responseJSON['date'] as String;
    final password = responseJSON['password'] as String;
    final providerId = responseJSON['id_provider'] as String;
    final providerName = responseJSON['provider'] as String;
    final amount = responseJSON['amount_from']?.toString();
    final receiveAmount = responseJSON['amount_to']?.toString();

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
      amount: amount ?? request.fromAmount,
      receiveAmount: receiveAmount ?? request.toAmount,
      payoutAddress: payoutAddress,
      isSendAll: isSendAll,
    );
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    final uri = await _getUri(tradePath, {'api_key': apiKey, 'id': id});
    return get(uri).then((response) {
      if (response.statusCode != 200)
        throw Exception('Unexpected http status: ${response.statusCode}');

      final responseListJson = json.decode(response.body) as List;
      final responseJSON = responseListJson.first;
      final id = responseJSON['trade_id'] as String;
      final payoutAddress = responseJSON['address_user'] as String;
      final refundAddress = responseJSON['refund_address'] as String;
      final inputAddress = responseJSON['address_provider'] as String;
      final fromAmount = responseJSON['amount_from']?.toString() ?? '0';
      final password = responseJSON['password'] as String;
      final providerId = responseJSON['id_provider'] as String;
      final providerName = responseJSON['provider'] as String;

      return Trade(
        id: id,
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
    });
  }

  Future<List<TrocadorPartners>> fetchProviders() async {
    final uri = await _getUri(providersListPath, {'api_key': apiKey});
    final response = await get(uri);

    if (response.statusCode != 200)
      throw Exception('Unexpected http status: ${response.statusCode}');

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;

    final providersJsonList = responseJSON['list'] as List<dynamic>;
    final filteredProvidersList = providersJsonList
        .map((providerJson) => TrocadorPartners.fromJson(providerJson as Map<String, dynamic>))
        .where((provider) => provider.rating != 'D')
        .toList();
    filteredProvidersList.sort((a, b) => a.rating.compareTo(b.rating));
    return filteredProvidersList;
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

  Future<Uri> _getUri(String path, Map<String, String> queryParams) async {
    final uri = Uri.http(onionApiAuthority, path, queryParams);

    if (useTorOnly) return uri;

    try {
      await get(uri);

      return uri;
    } catch (e) {
      return Uri.https(clearNetAuthority, path, queryParams);
    }
  }
}

class TrocadorPartners {
  final String name;
  final String rating;
  final double? insurance;
  final bool? enabledMarkup;
  final double? eta;

  TrocadorPartners({
    required this.name,
    required this.rating,
    required this.insurance,
    required this.enabledMarkup,
    required this.eta,
  });

  factory TrocadorPartners.fromJson(Map<String, dynamic> json) {
    return TrocadorPartners(
      name: json['name'] as String? ?? '',
      rating: json['rating'] as String? ?? 'N/A',
      insurance: json['insurance'] as double?,
      enabledMarkup: json['enabledmarkup'] as bool?,
      eta: json['eta'] as double?,
    );
  }
}
