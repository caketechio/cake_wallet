import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cake_wallet/core/wallet_connect/chain_service/eth/evm_chain_id.dart';
import 'package:cake_wallet/core/wallet_connect/chain_service/eth/evm_chain_service.dart';
import 'package:cake_wallet/core/wallet_connect/wallet_connect_key_service.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/core/wallet_connect/models/auth_request_model.dart';
import 'package:cake_wallet/core/wallet_connect/models/chain_key_model.dart';
import 'package:cake_wallet/core/wallet_connect/models/session_request_model.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/connection_request_widget.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/message_display_widget.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/web3_request_modal.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:on_chain/solana/solana.dart' hide Store;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

import 'chain_service/solana/solana_chain_id.dart';
import 'chain_service/solana/solana_chain_service.dart';
import 'wc_bottom_sheet_service.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

part 'web3wallet_service.g.dart';

class Web3WalletService = Web3WalletServiceBase with _$Web3WalletService;

abstract class Web3WalletServiceBase with Store {
  final AppStore appStore;
  final SharedPreferences sharedPreferences;
  final BottomSheetService _bottomSheetHandler;
  final WalletConnectKeyService walletKeyService;

  late Web3Wallet _web3Wallet;

  @observable
  bool isInitialized;

  /// The list of requests from the dapp
  /// Potential types include, but aren't limited to:
  /// [SessionProposalEvent], [AuthRequest]
  @observable
  ObservableList<PairingInfo> pairings;

  @observable
  ObservableList<SessionData> sessions;

  @observable
  ObservableList<StoredCacao> auth;

  Web3WalletServiceBase(
      this._bottomSheetHandler, this.walletKeyService, this.appStore, this.sharedPreferences)
      : pairings = ObservableList<PairingInfo>(),
        sessions = ObservableList<SessionData>(),
        auth = ObservableList<StoredCacao>(),
        isInitialized = false;

  @action
  void create() {
    // Create the web3wallet client
    _web3Wallet = Web3Wallet(
      core: Core(projectId: secrets.walletConnectProjectId),
      metadata: const PairingMetadata(
        name: 'Cake Wallet',
        description: 'Cake Wallet',
        url: 'https://cakewallet.com',
        icons: ['https://cakewallet.com/assets/image/cake_logo.png'],
      ),
    );

    // Setup our accounts
    List<ChainKeyModel> chainKeys = walletKeyService.getKeys(appStore.wallet!);
    for (final chainKey in chainKeys) {
      for (final chainId in chainKey.chains) {
        _web3Wallet.registerAccount(
          chainId: chainId,
          accountAddress: chainKey.publicKey,
        );
      }
    }

    // Setup our listeners
    log('Created instance of web3wallet');
    _web3Wallet.core.pairing.onPairingInvalid.subscribe(_onPairingInvalid);
    _web3Wallet.core.pairing.onPairingCreate.subscribe(_onPairingCreate);
    _web3Wallet.core.pairing.onPairingDelete.subscribe(_onPairingDelete);
    _web3Wallet.core.pairing.onPairingExpire.subscribe(_onPairingDelete);
    _web3Wallet.pairings.onSync.subscribe(_onPairingsSync);
    _web3Wallet.onSessionProposal.subscribe(_onSessionProposal);
    _web3Wallet.onSessionProposalError.subscribe(_onSessionProposalError);
    _web3Wallet.onSessionConnect.subscribe(_onSessionConnect);
    _web3Wallet.onAuthRequest.subscribe(_onAuthRequest);
  }

  @action
  Future<void> init() async {
    // Await the initialization of the web3wallet
    log('Intializing web3wallet');
    if (!isInitialized) {
      try {
        await _web3Wallet.init();
        log('Initialized');
        isInitialized = true;
      } catch (e) {
        log('Experimentallllll: $e');
        isInitialized = false;
      }
    }

    _refreshPairings();

    final newSessions = _web3Wallet.sessions.getAll();
    sessions.addAll(newSessions);

    final newAuthRequests = _web3Wallet.completeRequests.getAll();
    auth.addAll(newAuthRequests);

    if (isEVMCompatibleChain(appStore.wallet!.type)) {
      for (final cId in EVMChainId.values) {
        EvmChainServiceImpl(
          reference: cId,
          appStore: appStore,
          wcKeyService: walletKeyService,
          bottomSheetService: _bottomSheetHandler,
          wallet: _web3Wallet,
        );
      }
    }

    if (appStore.wallet!.type == WalletType.solana) {
      for (final cId in SolanaChainId.values) {
        final node = appStore.settingsStore.getCurrentNode(appStore.wallet!.type);

        String formattedUrl;
        String protocolUsed = node.isSSL ? "https" : "http";

        if (node.uriRaw == 'rpc.ankr.com') {
          String ankrApiKey = secrets.ankrApiKey;

          formattedUrl = '$protocolUsed://${node.uriRaw}/$ankrApiKey';
        } else if (node.uriRaw == 'solana-mainnet.core.chainstack.com') {
          String chainStackApiKey = secrets.chainStackApiKey;

          formattedUrl = '$protocolUsed://${node.uriRaw}/$chainStackApiKey';
        } else {
          formattedUrl = '$protocolUsed://${node.uriRaw}';
        }

        SolanaChainServiceImpl(
          reference: cId,
          formattedRPCUrl: formattedUrl,
          wcKeyService: walletKeyService,
          bottomSheetService: _bottomSheetHandler,
          wallet: _web3Wallet,
          ownerPrivateKey: SolanaPrivateKey.fromSeedHex(solana!.getPrivateKey(appStore.wallet!)),
        );
      }
    }
  }

  @action
  FutureOr<void> onDispose() {
    log('web3wallet dispose');
    _web3Wallet.core.pairing.onPairingInvalid.unsubscribe(_onPairingInvalid);
    _web3Wallet.pairings.onSync.unsubscribe(_onPairingsSync);
    _web3Wallet.onSessionProposal.unsubscribe(_onSessionProposal);
    _web3Wallet.onSessionProposalError.unsubscribe(_onSessionProposalError);
    _web3Wallet.onSessionConnect.unsubscribe(_onSessionConnect);
    _web3Wallet.onAuthRequest.unsubscribe(_onAuthRequest);
    _web3Wallet.core.pairing.onPairingDelete.unsubscribe(_onPairingDelete);
    _web3Wallet.core.pairing.onPairingExpire.unsubscribe(_onPairingDelete);
    isInitialized = false;
  }

  Web3Wallet getWeb3Wallet() {
    return _web3Wallet;
  }

  void _onPairingsSync(StoreSyncEvent? args) {
    if (args != null) {
      _refreshPairings();
    }
  }

  void _onPairingDelete(PairingEvent? event) {
    _refreshPairings();
  }

  Future<void> _onSessionProposalError(SessionProposalErrorEvent? args) async {
    log(args.toString());
  }

  void _onSessionProposal(SessionProposalEvent? args) async {
    if (args != null) {
      final chaindIdNamespace = getChainNameSpaceAndIdBasedOnWalletType(appStore.wallet!.type);
      final Widget modalWidget = Web3RequestModal(
        child: ConnectionRequestWidget(
          chaindIdNamespace: chaindIdNamespace,
          wallet: _web3Wallet,
          sessionProposal: SessionRequestModel(request: args.params),
        ),
      );
      // show the bottom sheet
      final bool? isApproved = await _bottomSheetHandler.queueBottomSheet(
        widget: modalWidget,
      ) as bool?;

      if (isApproved != null && isApproved) {
        _web3Wallet.approveSession(
          id: args.id,
          namespaces: args.params.generatedNamespaces!,
        );
      } else {
        _web3Wallet.rejectSession(
          id: args.id,
          reason: Errors.getSdkError(
            Errors.USER_REJECTED,
          ),
        );
      }
    }
  }

  @action
  void _onPairingInvalid(PairingInvalidEvent? args) {
    log('Pairing Invalid Event: $args');
    _bottomSheetHandler.queueBottomSheet(
      isModalDismissible: true,
      widget: BottomSheetMessageDisplayWidget(message: '${S.current.pairingInvalidEvent}: $args'),
    );
  }

  @action
  Future<void> pairWithUri(Uri uri) async {
    try {
      log('Pairing with URI: $uri');
      await _web3Wallet.pair(uri: uri);
    } on WalletConnectError catch (e) {
      _bottomSheetHandler.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(message: e.message),
      );
    } catch (e) {
      _bottomSheetHandler.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(message: e.toString()),
      );
    }
  }

  @action
  void _refreshPairings() {
    printV('Refreshing pairings');
    pairings.clear();

    final allPairings = _web3Wallet.pairings.getAll();

    final keyForWallet = getKeyForStoringTopicsForWallet();

    if (keyForWallet.isEmpty) return;

    final currentTopicsForWallet = getPairingTopicsForWallet(keyForWallet);

    final filteredPairings =
        allPairings.where((pairing) => currentTopicsForWallet.contains(pairing.topic)).toList();

    pairings.addAll(filteredPairings);
  }

  void _onPairingCreate(PairingEvent? args) {
    log('Pairing Create Event: $args');
  }

  @action
  Future<void> _onSessionConnect(SessionConnect? args) async {
    if (args != null) {
      log('Session Connected $args');

      await savePairingTopicToLocalStorage(args.session.pairingTopic);

      sessions.add(args.session);

      _refreshPairings();
    }
  }

  @action
  Future<void> _onAuthRequest(AuthRequest? args) async {
    if (args != null) {
      final chaindIdNamespace = getChainNameSpaceAndIdBasedOnWalletType(appStore.wallet!.type);
      List<ChainKeyModel> chainKeys = walletKeyService.getKeysForChain(appStore.wallet!);
      // Create the message to be signed
      final String iss = 'did:pkh:$chaindIdNamespace:${chainKeys.first.publicKey}';
      final Widget modalWidget = Web3RequestModal(
        child: ConnectionRequestWidget(
          chaindIdNamespace: chaindIdNamespace,
          wallet: _web3Wallet,
          authRequest: AuthRequestModel(iss: iss, request: args),
        ),
      );
      final bool? isAuthenticated = await _bottomSheetHandler.queueBottomSheet(
        widget: modalWidget,
      ) as bool?;

      if (isAuthenticated != null && isAuthenticated) {
        final String message = _web3Wallet.formatAuthMessage(
          iss: iss,
          cacaoPayload: CacaoRequestPayload.fromPayloadParams(
            args.payloadParams,
          ),
        );

        final String sig = EthSigUtil.signPersonalMessage(
          message: Uint8List.fromList(message.codeUnits),
          privateKey: chainKeys.first.privateKey,
        );

        await _web3Wallet.respondAuthRequest(
          id: args.id,
          iss: iss,
          signature: CacaoSignature(
            t: CacaoSignature.EIP191,
            s: sig,
          ),
        );
      } else {
        await _web3Wallet.respondAuthRequest(
          id: args.id,
          iss: iss,
          error: Errors.getSdkError(
            Errors.USER_REJECTED_AUTH,
          ),
        );
      }
    }
  }

  @action
  Future<void> disconnectSession(String topic) async {
    final session = sessions.firstWhere((element) => element.pairingTopic == topic);

    await _web3Wallet.core.pairing.disconnect(topic: topic);
    await _web3Wallet.disconnectSession(
        topic: session.topic, reason: Errors.getSdkError(Errors.USER_DISCONNECTED));
  }

  @action
  List<SessionData> getSessionsForPairingInfo(PairingInfo pairing) {
    return sessions.where((element) => element.pairingTopic == pairing.topic).toList();
  }

  String getKeyForStoringTopicsForWallet() {
    List<ChainKeyModel> chainKeys = walletKeyService.getKeysForChain(appStore.wallet!);

    if (chainKeys.isEmpty) {
      return '';
    }

    final keyForPairingTopic =
        PreferencesKey.walletConnectPairingTopicsListForWallet(chainKeys.first.publicKey);

    return keyForPairingTopic;
  }

  List<String> getPairingTopicsForWallet(String key) {
    // Get the JSON-encoded string from shared preferences
    final jsonString = sharedPreferences.getString(key);

    // If the string is null, return an empty list
    if (jsonString == null) {
      return [];
    }

    // Decode the JSON string to a list of strings
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;

    // Cast each item to a string
    return jsonList.map((item) => item as String).toList();
  }

  Future<void> savePairingTopicToLocalStorage(String pairingTopic) async {
    // Get key specific to the current wallet
    final key = getKeyForStoringTopicsForWallet();

    if (key.isEmpty) return;

    // Get all pairing topics attached to this key
    final pairingTopicsForWallet = getPairingTopicsForWallet(key);

    printV(pairingTopicsForWallet);

    bool isPairingTopicAlreadySaved = pairingTopicsForWallet.contains(pairingTopic);
    printV('Is Pairing Topic Saved: $isPairingTopicAlreadySaved');

    if (!isPairingTopicAlreadySaved) {
      // Update the list with the most recent pairing topic
      pairingTopicsForWallet.add(pairingTopic);

      // Convert the list of updated pairing topics to a JSON-encoded string
      final jsonString = jsonEncode(pairingTopicsForWallet);

      // Save the encoded string to shared preferences
      await sharedPreferences.setString(key, jsonString);
    }
  }
}
