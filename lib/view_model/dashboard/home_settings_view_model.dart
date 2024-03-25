import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/sort_balance_types.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'home_settings_view_model.g.dart';

class HomeSettingsViewModel = HomeSettingsViewModelBase with _$HomeSettingsViewModel;

abstract class HomeSettingsViewModelBase with Store {
  HomeSettingsViewModelBase(this._settingsStore, this._balanceViewModel)
      : tokens = ObservableSet<CryptoCurrency>() {
    _updateTokensList();
  }

  final SettingsStore _settingsStore;
  final BalanceViewModel _balanceViewModel;

  final ObservableSet<CryptoCurrency> tokens;

  @observable
  String searchText = '';

  @computed
  SortBalanceBy get sortBalanceBy => _settingsStore.sortBalanceBy;

  @action
  void setSortBalanceBy(SortBalanceBy value) {
    _settingsStore.sortBalanceBy = value;
    _updateTokensList();
  }

  @computed
  bool get pinNativeToken => _settingsStore.pinNativeTokenAtTop;

  @action
  void setPinNativeToken(bool value) => _settingsStore.pinNativeTokenAtTop = value;

  Future<void> addToken(CryptoCurrency token) async {
    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      await ethereum!.addErc20Token(_balanceViewModel.wallet, token);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      await polygon!.addErc20Token(_balanceViewModel.wallet, token);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      await solana!.addSPLToken(_balanceViewModel.wallet, token);
    }

    _updateTokensList();
    _updateFiatPrices(token);
  }

  Future<void> deleteToken(CryptoCurrency token) async {
    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      await ethereum!.deleteErc20Token(_balanceViewModel.wallet, token as Erc20Token);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      await polygon!.deleteErc20Token(_balanceViewModel.wallet, token as Erc20Token);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      await solana!.deleteSPLToken(_balanceViewModel.wallet, token);
    }

    _updateTokensList();
  }

  Future<CryptoCurrency?> getToken(String contractAddress) async {
    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      return await ethereum!.getErc20Token(_balanceViewModel.wallet, contractAddress);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      return await polygon!.getErc20Token(_balanceViewModel.wallet, contractAddress);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      return await solana!.getSPLToken(_balanceViewModel.wallet, contractAddress);
    }

    return null;
  }

  CryptoCurrency get nativeToken => _balanceViewModel.wallet.currency;

  void _updateFiatPrices(CryptoCurrency token) async {
    try {
      _balanceViewModel.fiatConvertationStore.prices[token] =
          await FiatConversionService.fetchPrice(
        crypto: token,
        fiat: _settingsStore.fiatCurrency,
      );
    } catch (_) {}
  }

  void changeTokenAvailability(CryptoCurrency token, bool value) async {
    token.enabled = value;

    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      ethereum!.addErc20Token(_balanceViewModel.wallet, token as Erc20Token);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      polygon!.addErc20Token(_balanceViewModel.wallet, token as Erc20Token);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      solana!.addSPLToken(_balanceViewModel.wallet, token);
    }

    _refreshTokensList();
  }

  @action
  void _updateTokensList() {
    int _sortFunc(CryptoCurrency e1, CryptoCurrency e2) {
      int index1 = _balanceViewModel.formattedBalances.indexWhere((element) => element.asset == e1);
      int index2 = _balanceViewModel.formattedBalances.indexWhere((element) => element.asset == e2);

      if (e1.enabled && !e2.enabled) {
        return -1;
      } else if (e2.enabled && !e1.enabled) {
        return 1;
      } else if (!e1.enabled && !e2.enabled) {
        // if both are disabled then sort alphabetically
        return e1.name.compareTo(e2.name);
      }

      return index1.compareTo(index2);
    }

    tokens.clear();

    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      tokens.addAll(ethereum!
          .getERC20Currencies(_balanceViewModel.wallet)
          .where((element) => _matchesSearchText(element))
          .toList()
        ..sort(_sortFunc));
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      tokens.addAll(polygon!
          .getERC20Currencies(_balanceViewModel.wallet)
          .where((element) => _matchesSearchText(element))
          .toList()
        ..sort(_sortFunc));
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      tokens.addAll(solana!
          .getSPLTokenCurrencies(_balanceViewModel.wallet)
          .where((element) => _matchesSearchText(element))
          .toList()
        ..sort(_sortFunc));
    }
  }

  @action
  void _refreshTokensList() {
    final _tokens = Set.of(tokens);
    tokens.clear();
    tokens.addAll(_tokens);
  }

  @action
  void changeSearchText(String text) {
    searchText = text;
    _updateTokensList();
  }

  bool _matchesSearchText(CryptoCurrency asset) {
    final address = getTokenAddressBasedOnWallet(asset);

    // The homes settings would only be displayed for either of Ethereum, Polygon or Solana Wallets.
    if (address == null) return false;

    return searchText.isEmpty ||
        asset.fullName!.toLowerCase().contains(searchText.toLowerCase()) ||
        asset.title.toLowerCase().contains(searchText.toLowerCase()) ||
        address == searchText;
  }

  String? getTokenAddressBasedOnWallet(CryptoCurrency asset) {
    if (_balanceViewModel.wallet.type == WalletType.solana) {
      return solana!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      return ethereum!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      return polygon!.getTokenAddress(asset);
    }

    // We return null if it's neither Polygin, Ethereum or Solana wallet (which is actually impossible because we only display home settings for either of these three wallets).
    return null;
  }
}
