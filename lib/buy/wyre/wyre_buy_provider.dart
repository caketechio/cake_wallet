import 'dart:convert';
import 'package:cake_wallet/buy/buy_exception.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:http/http.dart';
import 'package:cake_wallet/buy/buy_amount.dart';
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_provider_description.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

class WyreBuyProvider extends BuyProvider {
  WyreBuyProvider({required WalletBase wallet, bool isTestEnvironment = false})
      : baseApiUrl = isTestEnvironment ? _baseTestApiUrl : _baseProductApiUrl,
        super(wallet: wallet, isTestEnvironment: isTestEnvironment, ledgerVM: null);

  static const _baseTestApiUrl = 'https://api.testwyre.com';
  static const _baseProductApiUrl = 'https://api.sendwyre.com';
  static const _trackTestUrl = 'https://dash.testwyre.com/track/';
  static const _trackProductUrl = 'https://dash.sendwyre.com/track/';
  static const _ordersSuffix = '/v3/orders';
  static const _reserveSuffix = '/reserve';
  static const _quoteSuffix = '/quote/partner';
  static const _timeStampSuffix = '?timestamp=';
  static const _transferSuffix = '/v2/transfer/';
  static const _trackSuffix = '/track';
  static const _countryCode = 'US';
  static const _secretKey = secrets.wyreSecretKey;
  static const _accountId = secrets.wyreAccountId;

  @override
  String get title => 'Wyre';

  @override
  String get providerDescription => '';

  @override
  String get lightIcon => 'assets/images/robinhood_light.png';

  @override
  String get darkIcon => 'assets/images/robinhood_dark.png';

  @override
  bool get isAggregator => false;

  String get trackUrl => isTestEnvironment ? _trackTestUrl : _trackProductUrl;

  String baseApiUrl;

  Future<String> requestUrl(String amount, String sourceCurrency) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final url = baseApiUrl + _ordersSuffix + _reserveSuffix + _timeStampSuffix + timestamp;
    final uri = Uri.parse(url);
    final body = {
      'amount': amount,
      'sourceCurrency': sourceCurrency,
      'destCurrency': walletTypeToCryptoCurrency(wallet.type).title,
      'dest': walletTypeToString(wallet.type).toLowerCase() + ':' + wallet.walletAddresses.address,
      'referrerAccountId': _accountId,
      'lockFields': ['amount', 'sourceCurrency', 'destCurrency', 'dest']
    };
    final response = await post(uri,
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
          'cache-control': 'no-cache'
        },
        body: json.encode(body));

    if (response.statusCode != 200) {
      throw BuyException(title: providerDescription, content: 'Url $url is not found!');
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final urlFromResponse = responseJSON['url'] as String;
    return urlFromResponse;
  }

  Future<BuyAmount> calculateAmount(String amount, String sourceCurrency) async {
    final quoteUrl = _baseProductApiUrl + _ordersSuffix + _quoteSuffix;
    final body = {
      'amount': amount,
      'sourceCurrency': sourceCurrency,
      'destCurrency': walletTypeToCryptoCurrency(wallet.type).title,
      'dest': walletTypeToString(wallet.type).toLowerCase() + ':' + wallet.walletAddresses.address,
      'accountId': _accountId,
      'country': _countryCode
    };
    final uri = Uri.parse(quoteUrl);
    final response = await post(uri,
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
          'cache-control': 'no-cache'
        },
        body: json.encode(body));

    if (response.statusCode != 200) {
      throw BuyException(title: providerDescription, content: 'Quote is not found!');
    }

    final responseJSON = json.decode(response.body) as Map<String, dynamic>;
    final sourceAmount = responseJSON['sourceAmount'] as double;
    final destAmount = responseJSON['destAmount'] as double;
    final achAmount = responseJSON['sourceAmountWithoutFees'] as double;

    return BuyAmount(
        sourceAmount: sourceAmount, destAmount: destAmount, achSourceAmount: achAmount);
  }

  Future<Order> findOrderById(String id) async {
    final orderUrl = baseApiUrl + _ordersSuffix + '/$id';
    final orderUri = Uri.parse(orderUrl);
    final orderResponse = await ProxyWrapper().get(clearnetUri: orderUri);
    final responseString = await orderResponse.transform(utf8.decoder).join();
    if (orderResponse.statusCode != 200) {
      throw BuyException(title: providerDescription, content: 'Order $id is not found!');
    }

    final orderResponseJSON = json.decode(responseString) as Map<String, dynamic>;
    final transferId = orderResponseJSON['transferId'] as String;
    final from = orderResponseJSON['sourceCurrency'] as String;
    final to = orderResponseJSON['destCurrency'] as String;
    final status = orderResponseJSON['status'] as String;
    final state = TradeState.deserialize(raw: status.toLowerCase());
    final createdAtRaw = orderResponseJSON['createdAt'] as int;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw).toLocal();

    final transferUrl = baseApiUrl + _transferSuffix + transferId + _trackSuffix;
    final transferUri = Uri.parse(transferUrl);
    final transferResponse = await ProxyWrapper().get(clearnetUri: transferUri);
    final transferResponseString = await transferResponse.transform(utf8.decoder).join();
    if (transferResponse.statusCode != 200) {
      throw BuyException(title: providerDescription, content: 'Transfer $transferId is not found!');
    }

    final transferResponseJSON = json.decode(transferResponseString) as Map<String, dynamic>;
    final amount = transferResponseJSON['destAmount'] as double;

    return Order(
        id: id,
        provider: BuyProviderDescription.wyre,
        transferId: transferId,
        from: from,
        to: to,
        state: state,
        createdAt: createdAt,
        amount: amount.toString(),
        receiveAddress: wallet.walletAddresses.address,
        walletId: wallet.id);
  }
}
