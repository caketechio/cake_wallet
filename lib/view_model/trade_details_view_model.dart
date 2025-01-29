import 'dart:async';

import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/exchange/provider/chainflip_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/changenow_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/exolix_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/letsexchange_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/quantex_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/sideshift_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/simpleswap_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/stealth_ex_exchange_provider.dart';
import 'package:cake_wallet/exchange/provider/thorchain_exchange.provider.dart';
import 'package:cake_wallet/exchange/provider/trocador_exchange_provider.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/trade_details/track_trade_list_item.dart';
import 'package:cake_wallet/src/screens/trade_details/trade_details_list_card.dart';
import 'package:cake_wallet/src/screens/trade_details/trade_details_status_item.dart';
import 'package:cake_wallet/src/screens/trade_details/trade_provider_unsupported_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/date_formatter.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:collection/collection.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:url_launcher/url_launcher.dart';

part 'trade_details_view_model.g.dart';

class TradeDetailsViewModel = TradeDetailsViewModelBase with _$TradeDetailsViewModel;

abstract class TradeDetailsViewModelBase with Store {
  TradeDetailsViewModelBase({
    required Trade tradeForDetails,
    required this.trades,
    required this.settingsStore,
  })  : items = ObservableList<StandartListItem>(),
        trade = trades.values.firstWhereOrNull((element) => element.id == tradeForDetails.id) ??
            tradeForDetails {
    switch (trade.provider) {
      case ExchangeProviderDescription.changeNow:
        _provider = ChangeNowExchangeProvider(settingsStore: settingsStore);
        break;
      case ExchangeProviderDescription.sideShift:
        _provider = SideShiftExchangeProvider();
        break;
      case ExchangeProviderDescription.simpleSwap:
        _provider = SimpleSwapExchangeProvider();
        break;
      case ExchangeProviderDescription.trocador:
        _provider = TrocadorExchangeProvider();
        break;
      case ExchangeProviderDescription.exolix:
        _provider = ExolixExchangeProvider();
        break;
      case ExchangeProviderDescription.thorChain:
        _provider = ThorChainExchangeProvider(tradesStore: trades);
        break;
      case ExchangeProviderDescription.quantex:
        _provider = QuantexExchangeProvider();
      case ExchangeProviderDescription.letsExchange:
        _provider = LetsExchangeExchangeProvider();
        break;
      case ExchangeProviderDescription.stealthEx:
        _provider = StealthExExchangeProvider();
        break;
      case ExchangeProviderDescription.chainflip:
        _provider = ChainflipExchangeProvider(tradesStore: trades);
        break;
    }

    _updateItems();

    if (_provider != null) {
      _updateTrade();
      timer = Timer.periodic(Duration(seconds: 20), (_) async => _updateTrade());
    }
  }

  static String? getTrackUrl(ExchangeProviderDescription provider, Trade trade) {
    switch (provider) {
      case ExchangeProviderDescription.changeNow:
        return 'https://changenow.io/exchange/txs/${trade.id}';
      case ExchangeProviderDescription.sideShift:
        return 'https://sideshift.ai/orders/${trade.id}';
      case ExchangeProviderDescription.simpleSwap:
        return 'https://simpleswap.io/exchange?id=${trade.id}';
      case ExchangeProviderDescription.trocador:
        return 'https://trocador.app/en/checkout/${trade.id}';
      case ExchangeProviderDescription.exolix:
        return 'https://exolix.com/transaction/${trade.id}';
      case ExchangeProviderDescription.thorChain:
        return 'https://track.ninerealms.com/${trade.id}';
      case ExchangeProviderDescription.quantex:
        return 'https://myquantex.com/send/${trade.id}';
      case ExchangeProviderDescription.letsExchange:
        return 'https://letsexchange.io/?transactionId=${trade.id}';
      case ExchangeProviderDescription.stealthEx:
        return 'https://stealthex.io/exchange/?id=${trade.id}';
      case ExchangeProviderDescription.chainflip:
        return 'https://scan.chainflip.io/channels/${trade.id}';
    }
    return null;
  }

  final Box<Trade> trades;

  @observable
  Trade trade;

  @observable
  ObservableList<StandartListItem> items;

  ExchangeProvider? _provider;

  Timer? timer;

  final SettingsStore settingsStore;

  @action
  Future<void> _updateTrade() async {
    try {
      final updatedTrade = await _provider!.findTradeById(id: trade.id);

      if (updatedTrade.createdAt == null && trade.createdAt != null)
        updatedTrade.createdAt = trade.createdAt;

      Trade? foundElement = trades.values.firstWhereOrNull((element) => element.id == trade.id);
      if (foundElement != null) {
        final editedTrade = trades.get(foundElement.key);
        editedTrade?.stateRaw = updatedTrade.stateRaw;
        editedTrade?.save();
      }

      trade = updatedTrade;

      _updateItems();
    } catch (e) {
      printV(e.toString());
    }
  }

  void _updateItems() {
    final dateFormat = DateFormatter.withCurrentLocal(reverse: true);

    items.clear();

    if (_provider == null)
      items.add(TradeProviderUnsupportedItem(
          error: S.current.exchange_provider_unsupported(trade.provider.title)));

    items.add(
        DetailsListStatusItem(title: S.current.trade_details_state, value: trade.state.toString()));

    items.add(TradeDetailsListCardItem.tradeDetails(
      id: trade.id,
      extraId: trade.extraId,
      createdAt: trade.createdAt != null ? dateFormat.format(trade.createdAt!) : '',
      from: trade.from,
      to: trade.to,
      onTap: (BuildContext context) {
        Clipboard.setData(ClipboardData(text: '${trade.id}'));
        showBar<void>(context, S.of(context).copied_to_clipboard);
      },
    ));

    items.add(StandartListItem(
        title: S.current.trade_details_provider, value: trade.provider.toString()));

    final trackUrl = TradeDetailsViewModelBase.getTrackUrl(trade.provider, trade);
    if (trackUrl != null) {
      items.add(TrackTradeListItem(
          title: S.current.track, value: trackUrl, onTap: () => _launchUrl(trackUrl)));
    }

    if (trade.isRefund == true) {
      items.add(StandartListItem(
          title: 'Refund', value: trade.refundAddress ?? ''));
    }

    if (trade.provider == ExchangeProviderDescription.trocador) {
      items.add(StandartListItem(
          title: '${trade.providerName} ${S.current.id.toUpperCase()}',
          value: trade.providerId ?? ''));

      if (trade.password != null && trade.password!.isNotEmpty) {
        items.add(StandartListItem(
            title: '${trade.providerName} ${S.current.password}', value: trade.password ?? ''));
      }
    }
  }

  void _launchUrl(String url) {
    final uri = Uri.parse(url);
    try {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {}
  }
}
