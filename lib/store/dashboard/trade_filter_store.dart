import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:mobx/mobx.dart';

part 'trade_filter_store.g.dart';

class TradeFilterStore = TradeFilterStoreBase with _$TradeFilterStore;

abstract class TradeFilterStoreBase with Store {
  TradeFilterStoreBase()
      : displayXMRTO = true,
        displayChangeNow = true,
        displaySideShift = true,
        displayMorphToken = true,
        displaySimpleSwap = true,
        displayTrocador = true,
        displayExolix = true,
        displayChainflip = true,
        displayThorChain = true,
        displayLetsExchange = true,
        displayStealthEx = true;

  @observable
  bool displayXMRTO;

  @observable
  bool displayChangeNow;

  @observable
  bool displaySideShift;

  @observable
  bool displayMorphToken;

  @observable
  bool displaySimpleSwap;

  @observable
  bool displayTrocador;

  @observable
  bool displayExolix;

  @observable
  bool displayChainflip;
  
  @observable
  bool displayThorChain;

  @observable
  bool displayLetsExchange;

  @observable
  bool displayStealthEx;

  @computed
  bool get displayAllTrades =>
      displayChangeNow &&
      displaySideShift &&
      displaySimpleSwap &&
      displayTrocador &&
      displayExolix && 
      displayChainflip &&
      displayThorChain &&
      displayLetsExchange &&
      displayStealthEx;

  @action
  void toggleDisplayExchange(ExchangeProviderDescription provider) {
    switch (provider) {
      case ExchangeProviderDescription.changeNow:
        displayChangeNow = !displayChangeNow;
        break;
      case ExchangeProviderDescription.sideShift:
        displaySideShift = !displaySideShift;
        break;
      case ExchangeProviderDescription.simpleSwap:
        displaySimpleSwap = !displaySimpleSwap;
        break;
      case ExchangeProviderDescription.xmrto:
        displayXMRTO = !displayXMRTO;
        break;
      case ExchangeProviderDescription.morphToken:
        displayMorphToken = !displayMorphToken;
        break;
      case ExchangeProviderDescription.trocador:
        displayTrocador = !displayTrocador;
        break;
      case ExchangeProviderDescription.exolix:
        displayExolix = !displayExolix;
        break;
      case ExchangeProviderDescription.chainflip:
        displayChainflip = !displayChainflip;
        break;
      case ExchangeProviderDescription.thorChain:
        displayThorChain = !displayThorChain;
        break;
      case ExchangeProviderDescription.letsExchange:
        displayLetsExchange = !displayLetsExchange;
        break;
      case ExchangeProviderDescription.stealthEx:
        displayStealthEx = !displayStealthEx;
        break;
      case ExchangeProviderDescription.all:
        if (displayAllTrades) {
          displayChangeNow = false;
          displaySideShift = false;
          displayXMRTO = false;
          displayMorphToken = false;
          displaySimpleSwap = false;
          displayTrocador = false;
          displayExolix = false;
          displayChainflip = false;
          displayThorChain = false;
          displayLetsExchange = false;
          displayStealthEx = false;
        } else {
          displayChangeNow = true;
          displaySideShift = true;
          displayXMRTO = true;
          displayMorphToken = true;
          displaySimpleSwap = true;
          displayTrocador = true;
          displayExolix = true;
          displayChainflip = true;
          displayThorChain = true;
          displayLetsExchange = true;
          displayStealthEx = true;
        }
        break;
    }
  }

  List<TradeListItem> filtered({required List<TradeListItem> trades, required WalletBase wallet}) {
    final _trades = trades
        .where((item) => item.trade.walletId == wallet.id && isTradeInAccount(item, wallet))
        .toList();
    final needToFilter = !displayAllTrades;

    return needToFilter
        ? _trades
            .where((item) =>
                (displayXMRTO && item.trade.provider == ExchangeProviderDescription.xmrto) ||
                (displaySideShift &&
                    item.trade.provider == ExchangeProviderDescription.sideShift) ||
                (displayChangeNow &&
                    item.trade.provider == ExchangeProviderDescription.changeNow) ||
                (displayMorphToken &&
                    item.trade.provider == ExchangeProviderDescription.morphToken) ||
                (displaySimpleSwap &&
                    item.trade.provider == ExchangeProviderDescription.simpleSwap) ||
                (displayTrocador && item.trade.provider == ExchangeProviderDescription.trocador) ||
                (displayExolix && item.trade.provider == ExchangeProviderDescription.exolix) ||
                (displayChainflip &&
                    item.trade.provider == ExchangeProviderDescription.chainflip) ||
                (displayThorChain &&
                    item.trade.provider == ExchangeProviderDescription.thorChain) ||
                (displayLetsExchange &&
                    item.trade.provider == ExchangeProviderDescription.letsExchange) ||
                (displayStealthEx && item.trade.provider == ExchangeProviderDescription.stealthEx))
            .toList()
        : _trades;
  }

  bool isTradeInAccount(TradeListItem item, WalletBase wallet) =>
      item.trade.fromWalletAddress == null
          ? true
          : wallet.walletAddresses.containsAddress(item.trade.fromWalletAddress!);
}
