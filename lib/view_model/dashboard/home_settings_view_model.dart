import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/entities/erc20_token_info_explorers.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/erc20_token_info_moralis.dart';
import 'package:cake_wallet/entities/sort_balance_types.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/zano/zano.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:http/http.dart' as http;
import 'package:cake_wallet/.secrets.g.dart' as secrets;

part 'home_settings_view_model.g.dart';

class HomeSettingsViewModel = HomeSettingsViewModelBase with _$HomeSettingsViewModel;

abstract class HomeSettingsViewModelBase with Store {
  HomeSettingsViewModelBase(this._settingsStore, this._balanceViewModel)
      : tokens = ObservableSet<CryptoCurrency>(),
        isAddingToken = false,
        isDeletingToken = false,
        isValidatingContractAddress = false {
    _updateTokensList();
  }

  final SettingsStore _settingsStore;
  final BalanceViewModel _balanceViewModel;

  final ObservableSet<CryptoCurrency> tokens;

  WalletType get walletType => _balanceViewModel.wallet.type;

  @observable
  bool isAddingToken;

  @observable
  bool isDeletingToken;

  @observable
  bool isValidatingContractAddress;

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

  @action
  Future<void> addToken({
    required String contractAddress,
    required CryptoCurrency token,
  }) async {
    try {
      isAddingToken = true;
      if (_balanceViewModel.wallet.type == WalletType.ethereum) {
        final erc20token = Erc20Token(
          name: token.name,
          symbol: token.title,
          decimal: token.decimals,
          contractAddress: contractAddress,
          iconPath: token.iconPath,
        );

        await ethereum!.addErc20Token(_balanceViewModel.wallet, erc20token);
      }

      if (_balanceViewModel.wallet.type == WalletType.polygon) {
        final polygonToken = Erc20Token(
          name: token.name,
          symbol: token.title,
          decimal: token.decimals,
          contractAddress: contractAddress,
          iconPath: token.iconPath,
        );
        await polygon!.addErc20Token(_balanceViewModel.wallet, polygonToken);
      }

      if (_balanceViewModel.wallet.type == WalletType.solana) {
        await solana!.addSPLToken(
          _balanceViewModel.wallet,
          token,
          contractAddress,
        );
      }

      if (_balanceViewModel.wallet.type == WalletType.tron) {
        await tron!.addTronToken(_balanceViewModel.wallet, token, contractAddress);
      }

      if (_balanceViewModel.wallet.type == WalletType.zano) {
        await zano!.addZanoAssetById(_balanceViewModel.wallet, contractAddress);
      }
      
      _updateTokensList();
      _updateFiatPrices(token);
    } finally {
      isAddingToken = false;
    }
  }

  @action
  Future<void> deleteToken(CryptoCurrency token) async {
    try {
      isDeletingToken = true;
      if (_balanceViewModel.wallet.type == WalletType.ethereum) {
        await ethereum!.deleteErc20Token(_balanceViewModel.wallet, token as Erc20Token);
      }

      if (_balanceViewModel.wallet.type == WalletType.polygon) {
        await polygon!.deleteErc20Token(_balanceViewModel.wallet, token as Erc20Token);
      }

      if (_balanceViewModel.wallet.type == WalletType.solana) {
        await solana!.deleteSPLToken(_balanceViewModel.wallet, token);
      }

      if (_balanceViewModel.wallet.type == WalletType.tron) {
        await tron!.deleteTronToken(_balanceViewModel.wallet, token);
      }
      if (_balanceViewModel.wallet.type == WalletType.zano) {
        await zano!.deleteZanoAsset(_balanceViewModel.wallet, token);
      }
      _updateTokensList();
    } finally {
      isDeletingToken = false;
    }
  }

  Future<bool> checkIfERC20TokenContractAddressIsAPotentialScamAddress(
    String contractAddress,
  ) async {
    try {
      isValidatingContractAddress = true;

      if (!isEVMCompatibleChain(_balanceViewModel.wallet.type)) {
        return false;
      }

      bool isEthereum = _balanceViewModel.wallet.type == WalletType.ethereum;

      bool isPotentialScamViaMoralis = await _isPotentialScamTokenViaMoralis(
        contractAddress,
        isEthereum ? 'eth' : 'polygon',
      );

      bool isPotentialScamViaExplorers = await _isPotentialScamTokenViaExplorers(
        contractAddress,
        isEthereum: isEthereum,
      );

      bool isUnverifiedContract = await _isContractUnverified(
        contractAddress,
        isEthereum: isEthereum,
      );

      final showWarningForContractAddress =
          isPotentialScamViaMoralis || isUnverifiedContract || isPotentialScamViaExplorers;

      return showWarningForContractAddress;
    } finally {
      isValidatingContractAddress = false;
    }
  }

  Future<bool> _isPotentialScamTokenViaMoralis(
    String contractAddress,
    String chainName,
  ) async {
    final uri = Uri.https(
      'deep-index.moralis.io',
      '/api/v2.2/erc20/metadata',
      {
        "chain": chainName,
        "addresses": contractAddress,
      },
    );

    try {
      final response = await ProxyWrapper().get(
        clearnetUri: uri,
        headers: {
          "Accept": "application/json",
          "X-API-Key": secrets.moralisApiKey,
        },
      );
      final responseString = await response.transform(utf8.decoder).join();
      final decodedResponse = jsonDecode(responseString);

      final tokenInfo = Erc20TokenInfoMoralis.fromJson(decodedResponse[0] as Map<String, dynamic>);

      // Based on analysis using Moralis internal metrics
      if (tokenInfo.possibleSpam == true) {
        return true;
      }

      // Tokens whose contract have not been verified are potentially risky tokens.
      if (tokenInfo.verifiedContract == false) {
        return true;
      }

      // Tokens with a security score less than 40 are potentially risky, requiring caution when dealing with them.
      if (tokenInfo.securityScore == null || tokenInfo.securityScore! < 40) {
        return true;
      }

      // Absence of a website URL for an ERC-20 token can be a potential red flag. A legitimate ERC-20 projects should have a well-maintained website that provides information about the token, its purpose, team, and roadmap.
      if (tokenInfo.links?.website == null || tokenInfo.links!.website!.isEmpty) {
        return true;
      }

      // Having a Fully Diluted Valiuation of 0 is a significant red flag that could signify:
      // - An abandoned/unlaunched project
      // - Incorrect/missing token data
      // - Suspicious manipulation of token data
      if (tokenInfo.fullyDilutedValuation == '0') {
        return true;
      }

      // I mean, a logo is the most basic of all the potential causes, but why does your fully functional project not have a logo?
      if (tokenInfo.logo == null) {
        return true;
      }

      return false;
    } catch (e) {
      printV('Error while checking scam via moralis: ${e.toString()}');
      return true;
    }
  }

  Future<bool> _isPotentialScamTokenViaExplorers(
    String contractAddress, {
    required bool isEthereum,
  }) async {
    final uri = Uri.https(
      isEthereum ? "api.etherscan.io" : "api.polygonscan.com",
      "/api",
      {
        "module": "token",
        "action": "tokeninfo",
        "contractaddress": contractAddress,
        "apikey": isEthereum ? secrets.etherScanApiKey : secrets.polygonScanApiKey,
      },
    );

    try {
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();
      final decodedResponse = jsonDecode(responseString) as Map<String, dynamic>;

      if (decodedResponse['status'] != '1') {
        log('${responseString}\n');
        log('${decodedResponse['result']}\n');
        return true;
      }

      final tokenInfo =
          Erc20TokenInfoExplorers.fromJson(decodedResponse['result'][0] as Map<String, dynamic>);

      // A token without a website is a potential red flag
      if (tokenInfo.website?.isEmpty == true) {
        return true;
      }

      return false;
    } catch (e) {
      printV('Error while checking scam via explorers: ${e.toString()}');
      return true;
    }
  }

  Future<bool> _isContractUnverified(
    String contractAddress, {
    required bool isEthereum,
  }) async {
    final uri = Uri.https(
      isEthereum ? "api.etherscan.io" : "api.polygonscan.com",
      "/api",
      {
        "module": "contract",
        "action": "getsourcecode",
        "address": contractAddress,
        "apikey": isEthereum ? secrets.etherScanApiKey : secrets.polygonScanApiKey,
      },
    );

    try {
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();

      final decodedResponse = jsonDecode(responseString) as Map<String, dynamic>;

      if (decodedResponse['status'] == '0') {
        printV('${responseString}\n');
        printV('${decodedResponse['result']}\n');
        return true;
      }

      if (decodedResponse['status'] == '1' &&
          decodedResponse['result'][0]['ABI'] == 'Contract source code not verified') {
        printV('Call is valid but contract is not verified');
        return true; // Contract is not verified
      } else {
        printV('Call is valid and contract is verified');
        return false; // Contract is verified
      }
    } catch (e) {
      printV('Error while checking contract verification: ${e.toString()}');
      return true;
    }
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

    if (_balanceViewModel.wallet.type == WalletType.tron) {
      return await tron!.getTronToken(_balanceViewModel.wallet, contractAddress);
    }

    if (_balanceViewModel.wallet.type == WalletType.zano) {
      return await zano!.getZanoAsset(_balanceViewModel.wallet, contractAddress);
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
              torOnly: _settingsStore.fiatApiMode == FiatApiMode.torOnly);
    } catch (_) {}
  }

  void changeTokenAvailability(CryptoCurrency token, bool value) async {
    token.enabled = value;

    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      ethereum!.addErc20Token(_balanceViewModel.wallet, token as Erc20Token);
      if (!value) ethereum!.removeTokenTransactionsInHistory(_balanceViewModel.wallet, token);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      polygon!.addErc20Token(_balanceViewModel.wallet, token as Erc20Token);
      if (!value) polygon!.removeTokenTransactionsInHistory(_balanceViewModel.wallet, token);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      final address = solana!.getTokenAddress(token);
      solana!.addSPLToken(_balanceViewModel.wallet, token, address);
    }

    if (_balanceViewModel.wallet.type == WalletType.tron) {
      final address = tron!.getTokenAddress(token);
      tron!.addTronToken(_balanceViewModel.wallet, token, address);
    }

    if (_balanceViewModel.wallet.type == WalletType.zano) {
      await zano!.changeZanoAssetAvailability(_balanceViewModel.wallet, token);
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

    if (_balanceViewModel.wallet.type == WalletType.tron) {
      tokens.addAll(tron!
          .getTronTokenCurrencies(_balanceViewModel.wallet)
          .where((element) => _matchesSearchText(element))
          .toList()
        ..sort(_sortFunc));
    }

    if (_balanceViewModel.wallet.type == WalletType.zano) {
      tokens.addAll(zano!.getZanoAssets(_balanceViewModel.wallet)
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

    // The homes settings would only be displayed for either of Tron, Ethereum, Polygon or Solana Wallets.
    if (address == null) return false;

    return searchText.isEmpty ||
        asset.fullName!.toLowerCase().contains(searchText.toLowerCase()) ||
        asset.title.toLowerCase().contains(searchText.toLowerCase()) ||
        address == searchText;
  }

  String? getTokenAddressBasedOnWallet(CryptoCurrency asset) {
    if (_balanceViewModel.wallet.type == WalletType.tron) {
      return tron!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.solana) {
      return solana!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.ethereum) {
      return ethereum!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.polygon) {
      return polygon!.getTokenAddress(asset);
    }

    if (_balanceViewModel.wallet.type == WalletType.zano) {
      return zano!.getZanoAssetAddress(asset);
    }

    // We return null if it's neither Tron, Polygon, Ethereum or Solana wallet (which is actually impossible because we only display home settings for either of these three wallets).
    return null;
  }
}
