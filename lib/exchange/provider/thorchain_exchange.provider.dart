import 'dart:convert';

import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/exchange/utils/currency_pairs_utils.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class ThorChainExchangeProvider extends ExchangeProvider {
  ThorChainExchangeProvider({required this.tradesStore, required this.settingsStore})
      : super(pairList: supportedPairs(_notSupported));

  static final List<CryptoCurrency> _notSupported = [
    ...(CryptoCurrency.all
        .where((element) => ![
              CryptoCurrency.btc,
              CryptoCurrency.eth,
              CryptoCurrency.ltc,
              CryptoCurrency.bch,
              CryptoCurrency.aave,
              CryptoCurrency.dai,
              CryptoCurrency.gusd,
              CryptoCurrency.usdc,
              CryptoCurrency.usdterc20,
              CryptoCurrency.wbtc,
            ].contains(element))
        .toList())
  ];

  static final isRefundAddressSupported = [CryptoCurrency.eth];

  static const _baseNodeURL = 'thornode.ninerealms.com';
  static const _baseURL = 'midgard.ninerealms.com';
  static const _quotePath = '/thorchain/quote/swap';
  static const _txInfoPath = '/thorchain/tx/status/';
  static const _affiliateName = 'cakewallet';
  static const _affiliateBps = '175';
  static const _nameLookUpPath = 'v2/thorname/lookup/';

  final Box<Trade> tradesStore;
  final SettingsStore settingsStore;

  @override
  String get title => 'THORChain';

  @override
  bool get isAvailable => true;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsFixedRate => false;

  @override
  ExchangeProviderDescription get description => ExchangeProviderDescription.thorChain;

  @override
  Future<bool> checkIsAvailable() async => true;

  @override
  Future<double> fetchRate(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required double amount,
      required bool isFixedRateMode,
      required bool isReceiveAmount}) async {
    try {
      if (amount == 0) return 0.0;

      final params = {
        'from_asset': _normalizeCurrency(from),
        'to_asset': _normalizeCurrency(to),
        'amount': _doubleToThorChainString(amount),
        'affiliate': _affiliateName,
        'affiliate_bps': _affiliateBps
      };

      final responseJSON = await _getSwapQuote(params);

      final expectedAmountOut = responseJSON['expected_amount_out'] as String? ?? '0.0';

      return _thorChainAmountToDouble(expectedAmountOut) / amount;
    } catch (e) {
      print(e.toString());
      return 0.0;
    }
  }

  @override
  Future<Limits> fetchLimits(
      {required CryptoCurrency from,
      required CryptoCurrency to,
      required bool isFixedRateMode}) async {
    final amount = from == CryptoCurrency.usdterc20 || from == CryptoCurrency.usdc ? 200.00 : 10.00;
    final params = {
      'from_asset': _normalizeCurrency(from),
      'to_asset': _normalizeCurrency(to),
      'amount': _doubleToThorChainString(amount),
      'affiliate': _affiliateName,
      'affiliate_bps': _affiliateBps
    };

    final responseJSON = await _getSwapQuote(params);
    final minAmountIn = responseJSON['recommended_min_amount_in'] as String? ?? '0.0';
    final dustThreshold = responseJSON['dust_threshold'] as String? ?? '0.0';

    if (double.parse(minAmountIn) < double.parse(dustThreshold)) {
      throw Exception('ThorChain: Min amount in is less than dust threshold');
    }

    return Limits(min: _thorChainAmountToDouble(minAmountIn));
  }

  @override
  Future<Trade> createTrade({
    required TradeRequest request,
    required bool isFixedRateMode,
    required bool isSendAll,
  }) async {
    String formattedToAddress = request.toAddress.startsWith('bitcoincash:')
        ? request.toAddress.replaceFirst('bitcoincash:', '')
        : request.toAddress;

    final formattedFromAmount = double.parse(request.fromAmount);

    final params = {
      'from_asset': _normalizeCurrency(request.fromCurrency),
      'to_asset': _normalizeCurrency(request.toCurrency),
      'amount': _doubleToThorChainString(formattedFromAmount),
      'destination': formattedToAddress,
      'affiliate': _affiliateName,
      'affiliate_bps': _affiliateBps,
      'refund_address':
          isRefundAddressSupported.contains(request.fromCurrency) ? request.refundAddress : '',
    };

    final responseJSON = await _getSwapQuote(params);

    final inputAddress = responseJSON['inbound_address'] as String?;
    final memo = responseJSON['memo'] as String?;
    final router = responseJSON['router'] as String?;
    final directAmountOutResponse = responseJSON['expected_amount_out'] as String?;

    String? receiveAmount;
    if (directAmountOutResponse != null) {
      receiveAmount = _thorChainAmountToDouble(directAmountOutResponse).toString();
    }

    return Trade(
      id: '',
      from: request.fromCurrency,
      to: request.toCurrency,
      provider: description,
      inputAddress: inputAddress,
      createdAt: DateTime.now(),
      amount: request.fromAmount,
      receiveAmount: receiveAmount ?? request.toAmount,
      state: TradeState.notFound,
      payoutAddress: request.toAddress,
      memo: memo,
      isSendAll: isSendAll,
      router: router,
    );
  }

  @override
  Future<Trade> findTradeById({required String id}) async {
    if (id.isEmpty) throw Exception('Trade id is empty');
    final formattedId = id.startsWith('0x') ? id.substring(2) : id;
    final uri = Uri.https(_baseNodeURL, '$_txInfoPath$formattedId');
    final response = await http.get(uri);

    if (response.statusCode == 404) {
      throw Exception('Trade not found for id: $formattedId');
    } else if (response.statusCode != 200) {
      throw Exception('Unexpected HTTP status: ${response.statusCode}');
    }

    final responseJSON = json.decode(response.body);
    final Map<String, dynamic> stagesJson = responseJSON['stages'] as Map<String, dynamic>;

    final inboundObservedStarted = stagesJson['inbound_observed']?['started'] as bool? ?? true;
    if (!inboundObservedStarted) {
      throw Exception('Trade has not started for id: $formattedId');
    }

    final currentState = _updateStateBasedOnStages(stagesJson) ?? TradeState.notFound;

    final tx = responseJSON['tx'];
    final String fromAddress = tx['from_address'] as String? ?? '';
    final String toAddress = tx['to_address'] as String? ?? '';
    final List<dynamic> coins = tx['coins'] as List<dynamic>;
    final String? memo = tx['memo'] as String?;

    final parts = memo?.split(':') ?? [];

    final String toChain = parts.length > 1 ? parts[1].split('.')[0] : '';
    final String toAsset = parts.length > 1 && parts[1].split('.').length > 1
        ? parts[1].split('.')[1].split('-')[0]
        : '';

    final formattedToChain = CryptoCurrency.fromString(toChain);
    final toAssetWithChain = CryptoCurrency.fromString(toAsset, walletCurrency: formattedToChain);

    final plannedOutTxs = responseJSON['planned_out_txs'] as List<dynamic>?;
    final isRefund = plannedOutTxs?.any((tx) => tx['refund'] == true) ?? false;

    return Trade(
      id: id,
      from: CryptoCurrency.fromString(tx['chain'] as String? ?? ''),
      to: toAssetWithChain,
      provider: description,
      inputAddress: fromAddress,
      payoutAddress: toAddress,
      amount: coins.first['amount'] as String? ?? '0.0',
      state: currentState,
      memo: memo,
      isRefund: isRefund,
    );
  }

  static Future<Map<String, String>?>? lookupAddressByName(String name) async {
    final uri = Uri.https(_baseURL, '$_nameLookUpPath$name');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return null;
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final entries = body['entries'] as List<dynamic>?;

    if (entries == null || entries.isEmpty) {
      return null;
    }

    Map<String, String> chainToAddressMap = {};

    for (final entry in entries) {
      final chain = entry['chain'] as String;
      final address = entry['address'] as String;
      chainToAddressMap[chain] = address;
    }

    return chainToAddressMap;
  }

  Future<Map<String, dynamic>> _getSwapQuote(Map<String, String> params) async {

    // Remove 'affiliate_bps' if the fiat value is less than $100
    if (await isSwapUnder100$(params: params) && params['affiliate_bps'] != null) {
      params.remove('affiliate_bps');
    }

    Uri uri = Uri.https(_baseNodeURL, _quotePath, params);

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Unexpected HTTP status: ${response.statusCode}');
    }

    if (response.body.contains('error')) {
      throw Exception('Unexpected response: ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  String _normalizeCurrency(CryptoCurrency currency) {
    final networkTitle = currency.tag == 'ETH' ? 'ETH' : currency.title;
    return '$networkTitle.${currency.title}';
  }

  String _doubleToThorChainString(double amount) => (amount * 1e8).toInt().toString();

  double _thorChainAmountToDouble(String amount) => double.parse(amount) / 1e8;

  TradeState? _updateStateBasedOnStages(Map<String, dynamic> stages) {
    TradeState? currentState;

    if (stages['inbound_observed']['completed'] as bool? ?? false) {
      currentState = TradeState.confirmation;
    }
    if (stages['inbound_confirmation_counted']['completed'] as bool? ?? false) {
      currentState = TradeState.confirmed;
    }
    if (stages['inbound_finalised']['completed'] as bool? ?? false) {
      currentState = TradeState.processing;
    }
    if (stages['swap_finalised']['completed'] as bool? ?? false) {
      currentState = TradeState.traded;
    }
    if (stages['outbound_signed']['completed'] as bool? ?? false) {
      currentState = TradeState.success;
    }

    return currentState;
  }

  Future<bool> isSwapUnder100$({required Map<String, String> params}) async {
    if (params['from_asset'] != null && params['amount'] != null) {
      final String formattedAsset = params['from_asset']!.split('.')[1];
      final CryptoCurrency selectedCryptoCurrency = CryptoCurrency.fromString(formattedAsset);

      final double price = await FiatConversionService.fetchPrice(
        crypto: selectedCryptoCurrency,
        fiat: FiatCurrency.usd,
        torOnly: settingsStore.fiatApiMode == FiatApiMode.torOnly,
      );

      final double fiatValue = price * _thorChainAmountToDouble(params['amount']!);

      return fiatValue < 100;
    }
    return false;
  }
}
