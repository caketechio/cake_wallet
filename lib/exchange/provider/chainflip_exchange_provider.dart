import 'dart:convert';
import 'dart:math';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class ChainflipExchangeProvider extends ExchangeProvider {
  ChainflipExchangeProvider({required this.tradesStore})
      : super(pairList: supportedPairs(_notSupported));

  static final List<CryptoCurrency> _notSupported = [
    ...(CryptoCurrency.all
        .where((element) => ![
              CryptoCurrency.btc,
              CryptoCurrency.eth,
              CryptoCurrency.usdc,
              CryptoCurrency.usdterc20,
              CryptoCurrency.flip,
              CryptoCurrency.sol,
              CryptoCurrency.usdcsol,
              // TODO: Add CryptoCurrency.etharb
              // TODO: Add CryptoCurrency.usdcarb
              // TODO: Add CryptoCurrency.dot
            ].contains(element))
        .toList())
  ];

  static const _baseURL = 'chainflip-broker.io';
  static const _assetsPath = '/assets';
  static const _quotePath = '/quote-native';
  static const _swapPath = '/swap';
  static const _txInfoPath = '/status-by-deposit-channel';
  static const _affiliateBps = secrets.chainflipAffiliateFee;
  static const _affiliateKey = secrets.chainflipApiKey;

  final Box<Trade> tradesStore;

  @override
  String get title => 'Chainflip';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => false;

  @override
  ExchangeProviderDescription get description =>
      ExchangeProviderDescription.chainflip;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final assetId = _normalizeCurrency(from);

    final assetsResponse = await _getAssets();
    final assets = assetsResponse['assets'] as List<dynamic>;

    final minAmount = assets.firstWhere(
            (asset) => asset['id'] == assetId,
            orElse: () => null)?['minimalAmountNative'] ?? '0';

    return Limits(min: _amountFromNative(minAmount.toString(), from));
  }

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    // TODO: It seems this rate is getting cached, and re-used for different amounts, can we not do this?

    try {
      if (amount == 0) return 0.0;

      final quoteParams = {
        'apiKey': _affiliateKey,
        'sourceAsset': _normalizeCurrency(from),
        'destinationAsset': _normalizeCurrency(to),
        'amount': _amountToNative(amount, from),
        'commissionBps': _affiliateBps
      };

      final quoteResponse = await _getSwapQuote(quoteParams);

      final expectedAmountOut =
          quoteResponse['egressAmountNative'] as String? ?? '0';

      return _amountFromNative(expectedAmountOut, to) / amount;
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
    try {
      final maxSlippage = 2;

      final quoteParams = {
        'apiKey': _affiliateKey,
        'sourceAsset': _normalizeCurrency(request.fromCurrency),
        'destinationAsset': _normalizeCurrency(request.toCurrency),
        'amount': _amountToNative(double.parse(request.fromAmount), request.fromCurrency),
        'commissionBps': _affiliateBps
      };

      final quoteResponse = await _getSwapQuote(quoteParams);
      final estimatedPrice = quoteResponse['estimatedPrice'] as double;
      final minimumPrice = estimatedPrice * (100 - maxSlippage) / 100;

      final swapParams = {
        'apiKey': _affiliateKey,
        'sourceAsset': _normalizeCurrency(request.fromCurrency),
        'destinationAsset': _normalizeCurrency(request.toCurrency),
        'destinationAddress': request.toAddress,
        'commissionBps': _affiliateBps,
        'minimumPrice': minimumPrice.toString(),
        'refundAddress': request.refundAddress,
        'boostFee': '6',
        'retryDurationInBlocks': '150'
      };

      final swapResponse = await _openDepositChannel(swapParams);

      final id = '${swapResponse['issuedBlock']}-${swapResponse['network'].toString().toUpperCase()}-${swapResponse['channelId']}';

      return Trade(
          id: id,
          from: request.fromCurrency,
          to: request.toCurrency,
          provider: description,
          inputAddress: swapResponse['address'].toString(),
          createdAt: DateTime.now(),
          amount: request.fromAmount,
          receiveAmount: request.toAmount,
          state: TradeState.waiting,
          payoutAddress: request.toAddress,
          isSendAll: isSendAll);
    } catch (e) {
      printV(e.toString());
      rethrow;
    }
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    try {
      final channelParts = id.split('-');

      final statusParams = {
        'apiKey': _affiliateKey,
        'issuedBlock': channelParts[0],
        'network': channelParts[1],
        'channelId': channelParts[2]
      };

      final statusResponse = await _getStatus(statusParams);

      if (statusResponse == null)
        throw Exception('Trade not found for id: $id');

      final status = statusResponse['status'];
      final currentState = _determineState(status['state'].toString());

      final depositAmount = status['deposit']?['amount']?.toString() ?? '0.0';
      final receiveAmount = status['swapEgress']?['amount']?.toString() ?? '0.0';
      final refundAmount = status['refundEgress']?['amount']?.toString() ?? '0.0';
      final isRefund = status['refundEgress'] != null;
      final amount = isRefund ? refundAmount : receiveAmount;
      
      final newTrade = Trade(
          id: id,
          from: _toCurrency(status['sourceAsset'].toString()),
          to: _toCurrency(status['destinationAsset'].toString()),
          provider: description,
          amount: depositAmount,
          receiveAmount: amount,
          state: currentState,
          payoutAddress: status['destinationAddress'].toString(),
          outputTransaction: status['swapEgress']?['transactionReference']?.toString(),
          isRefund: isRefund);

      // Find trade and update receiveAmount with the real value received
      final storedTrade = _getStoredTrade(id);
      
      if (storedTrade != null) {
        storedTrade.$2.receiveAmount = newTrade.receiveAmount;
        storedTrade.$2.outputTransaction = newTrade.outputTransaction;
        tradesStore.put(storedTrade.$1, storedTrade.$2);
      }

      return newTrade;
    } catch (e) {
      printV(e.toString());
      rethrow;
    }
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    final network = switch (currency.tag) {
      'ETH' => 'eth',
      'SOL' => 'sol',
      _ => currency.title.toLowerCase()
    };

    return '${currency.title.toLowerCase()}.$network';
  }

  CryptoCurrency? _toCurrency(String name) {
    final currency = switch (name) {
      'btc.btc' => CryptoCurrency.btc,
      'eth.eth' => CryptoCurrency.eth,
      'usdc.eth' => CryptoCurrency.usdc,
      'usdt.eth' => CryptoCurrency.usdterc20,
      'flip.eth' => CryptoCurrency.flip,
      'sol.sol' => CryptoCurrency.sol,
      'usdc.sol' => CryptoCurrency.usdcsol,
      _ => null
    };

    return currency;
  }

  (dynamic, Trade)? _getStoredTrade(String id) {
    for (var i = tradesStore.length -1; i >= 0; i--) {
      Trade? t = tradesStore.getAt(i);
      
      if (t != null && t.id == id)
        return (i, t);
    }
    
    return null;
  }

  String _amountToNative(double amount, CryptoCurrency currency) =>
      (amount * pow(10, currency.decimals)).toInt().toString();

  double _amountFromNative(String amount, CryptoCurrency currency) =>
      double.parse(amount) / pow(10, currency.decimals);

  Future<Map<String, dynamic>> _getAssets() async =>
      _getRequest(_assetsPath, {});

  Future<Map<String, dynamic>> _getSwapQuote(Map<String, String> params) async =>
      _getRequest(_quotePath, params);

  Future<Map<String, dynamic>> _openDepositChannel(Map<String, String> params) async =>
      _getRequest(_swapPath, params);

  Future<Map<String, dynamic>> _getRequest(String path, Map<String, String> params) async {
    final uri = Uri.https(_baseURL, path, params);

    final response = await http.get(uri);

    if ((response.statusCode != 200) || (response.body.contains('error'))) {
      throw Exception('Unexpected response: ${response.statusCode} / ${uri.toString()} / ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _getStatus(Map<String, String> params) async {
    final uri = Uri.https(_baseURL, _txInfoPath, params);

    final response = await http.get(uri);

    if (response.statusCode == 404) return null;

    if ((response.statusCode != 200) || (response.body.contains('error'))) {
      throw Exception('Unexpected response: ${response.statusCode} / ${uri.toString()} / ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  TradeState _determineState(String state) {
    final swapState = switch (state) {
      'waiting' => TradeState.waiting,
      'receiving' => TradeState.processing,
      'swapping' => TradeState.processing,
      'sending' => TradeState.processing,
      'sent' => TradeState.processing,
      'completed' => TradeState.success,
      'failed' => TradeState.failed,
      _ => TradeState.notFound
    };

    return swapState;
  }
}
