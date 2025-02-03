import 'dart:convert';
import 'dart:developer';

import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/message_display_widget.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:http/http.dart' as http;
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

import 'package:cake_wallet/entities/wallet_nft_response.dart';
import 'package:cake_wallet/store/app_store.dart';

part 'nft_view_model.g.dart';

class NFTViewModel = NFTViewModelBase with _$NFTViewModel;

abstract class NFTViewModelBase with Store {
  NFTViewModelBase(this.appStore, this.bottomSheetService)
      : isLoading = false,
        isImportNFTLoading = false,
        nftAssetByWalletModels = ObservableList() {
    getNFTAssetByWallet();

    reaction((_) => appStore.wallet, (_) => getNFTAssetByWallet());
  }

  final AppStore appStore;
  final BottomSheetService bottomSheetService;

  @observable
  bool isLoading;

  @observable
  bool isImportNFTLoading;

  ObservableList<NFTAssetModel> nftAssetByWalletModels;

  @action
  Future<void> getNFTAssetByWallet() async {
    if (!isEVMCompatibleChain(appStore.wallet!.type)) return;

    final walletAddress = appStore.wallet!.walletInfo.address;
    log('Fetching wallet NFTs for $walletAddress');

    final chainName = getChainNameBasedOnWalletType(appStore.wallet!.type);
    // the [chain] refers to the chain network that the nft is on
    // the [format] refers to the number format type of the responses
    // the [normalizedMetadata] field is a boolean that determines if
    // the response would include a json string of the NFT Metadata that can be decoded
    // and used within the wallet
    // the [excludeSpam] field is a boolean that determines if spam nfts be excluded from the response.
    final uri = Uri.https(
      'deep-index.moralis.io',
      '/api/v2.2/$walletAddress/nft',
      {
        "chain": chainName,
        "format": "decimal",
        "media_items": "false",
        "exclude_spam": "true",
        "normalizeMetadata": "true",
      },
    );

    try {
      isLoading = true;

      final response = await ProxyWrapper().get(
        clearnetUri: uri,
        headers: {
          "Accept": "application/json",
          "X-API-Key": secrets.moralisApiKey,
        },
      );
      final responseString = await response.transform(utf8.decoder).join();

      final decodedResponse = jsonDecode(responseString) as Map<String, dynamic>;

      final result = WalletNFTsResponseModel.fromJson(decodedResponse).result ?? [];

      nftAssetByWalletModels.clear();

      nftAssetByWalletModels.addAll(result);

      isLoading = false;
    } catch (e) {
      isLoading = false;
      log(e.toString());
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: e.toString(),
        ),
      );
    }
  }

  @action
  Future<void> importNFT(String tokenAddress, String tokenId) async {
    final chainName = getChainNameBasedOnWalletType(appStore.wallet!.type);
    // the [chain] refers to the chain network that the nft is on
    // the [format] refers to the number format type of the responses
    // the [normalizedMetadata] field is a boolean that determines if
    // the response would include a json string of the NFT Metadata that can be decoded
    // and used within the wallet
    final uri = Uri.https(
      'deep-index.moralis.io',
      '/api/v2.2/nft/$tokenAddress/$tokenId',
      {
        "chain": chainName,
        "format": "decimal",
        "media_items": "false",
        "normalizeMetadata": "true",
      },
    );

    try {
      isImportNFTLoading = true;

      final response = await ProxyWrapper().get(
        clearnetUri: uri,
        headers: {
          "Accept": "application/json",
          "X-API-Key": secrets.moralisApiKey,
        },
      );
      final responseString = await response.transform(utf8.decoder).join();
      final decodedResponse = jsonDecode(responseString) as Map<String, dynamic>;

      final nftAsset = NFTAssetModel.fromJson(decodedResponse);

      nftAssetByWalletModels.add(nftAsset);

      isImportNFTLoading = false;
    } catch (e) {
      isImportNFTLoading = false;
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: e.toString(),
        ),
      );
    }
  }
}
