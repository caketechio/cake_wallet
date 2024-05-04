import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/nano/nano.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cw_core/nano_account_info_response.dart';
import 'package:cake_wallet/bitcoin_cash/bitcoin_cash.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cake_wallet/core/generate_wallet_password.dart';
import 'package:cake_wallet/core/wallet_creation_service.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cake_wallet/view_model/wallet_creation_vm.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/view_model/restore/restore_mode.dart';

part 'wallet_restore_view_model.g.dart';

class WalletRestoreViewModel = WalletRestoreViewModelBase with _$WalletRestoreViewModel;

abstract class WalletRestoreViewModelBase extends WalletCreationVM with Store {
  WalletRestoreViewModelBase(AppStore appStore, WalletCreationService walletCreationService,
      Box<WalletInfo> walletInfoSource,
      {required WalletType type})
      : hasSeedLanguageSelector = type == WalletType.monero || type == WalletType.haven,
        hasBlockchainHeightLanguageSelector = type == WalletType.monero || type == WalletType.haven,
        hasRestoreFromPrivateKey = type == WalletType.ethereum ||
            type == WalletType.polygon ||
            type == WalletType.nano ||
            type == WalletType.banano ||
            type == WalletType.solana ||
            type == WalletType.tron,
        isButtonEnabled = false,
        mode = WalletRestoreMode.seed,
        super(appStore, walletInfoSource, walletCreationService, type: type, isRecovery: true) {
    switch (type) {
      case WalletType.monero:
      case WalletType.haven:
      case WalletType.ethereum:
      case WalletType.polygon:
        availableModes = WalletRestoreMode.values;
        break;
      case WalletType.nano:
      case WalletType.banano:
      case WalletType.solana:
      case WalletType.tron:
        availableModes = [WalletRestoreMode.seed, WalletRestoreMode.keys];
        break;
      default:
        availableModes = [WalletRestoreMode.seed];
        break;
    }
    isButtonEnabled = !hasSeedLanguageSelector && !hasBlockchainHeightLanguageSelector;
    walletCreationService.changeWalletType(type: type);
  }

  static const moneroSeedMnemonicLength = 25;
  static const electrumSeedMnemonicLength = 24;
  static const electrumShortSeedMnemonicLength = 12;

  late List<WalletRestoreMode> availableModes;
  final bool hasSeedLanguageSelector;
  final bool hasBlockchainHeightLanguageSelector;
  final bool hasRestoreFromPrivateKey;

  bool get hasPassphrase => [WalletType.bitcoin, WalletType.litecoin].contains(type);

  @observable
  WalletRestoreMode mode;

  @observable
  bool isButtonEnabled;

  @override
  WalletCredentials getCredentials(dynamic options) {
    final password = generateWalletPassword();
    String? passphrase = options['passphrase'] as String?;
    final height = options['height'] as int? ?? 0;
    name = options['name'] as String;
    DerivationInfo? derivationInfo = options["derivationInfo"] as DerivationInfo?;

    if (mode == WalletRestoreMode.seed) {
      final seed = options['seed'] as String;
      switch (type) {
        case WalletType.monero:
          return monero!.createMoneroRestoreWalletFromSeedCredentials(
              name: name, height: height, mnemonic: seed, password: password);
        case WalletType.bitcoin:
        case WalletType.litecoin:
          return bitcoin!.createBitcoinRestoreWalletFromSeedCredentials(
            name: name,
            mnemonic: seed,
            password: password,
            passphrase: passphrase,
            derivationType: derivationInfo!.derivationType!,
            derivationPath: derivationInfo.derivationPath!,
          );
        case WalletType.haven:
          return haven!.createHavenRestoreWalletFromSeedCredentials(
              name: name, height: height, mnemonic: seed, password: password);
        case WalletType.ethereum:
          return ethereum!.createEthereumRestoreWalletFromSeedCredentials(
              name: name, mnemonic: seed, password: password);
        case WalletType.bitcoinCash:
          return bitcoinCash!.createBitcoinCashRestoreWalletFromSeedCredentials(
              name: name, mnemonic: seed, password: password);
        case WalletType.nano:
          return nano!.createNanoRestoreWalletFromSeedCredentials(
            name: name,
            mnemonic: seed,
            password: password,
            derivationType: derivationInfo!.derivationType!,
          );
        case WalletType.polygon:
          return polygon!.createPolygonRestoreWalletFromSeedCredentials(
            name: name,
            mnemonic: seed,
            password: password,
          );
        case WalletType.solana:
          return solana!.createSolanaRestoreWalletFromSeedCredentials(
            name: name,
            mnemonic: seed,
            password: password,
          );
        case WalletType.tron:
          return tron!.createTronRestoreWalletFromSeedCredentials(
            name: name,
            mnemonic: seed,
            password: password,
          );
        default:
          break;
      }
    }

    if (mode == WalletRestoreMode.keys) {
      final viewKey = options['viewKey'] as String?;
      final spendKey = options['spendKey'] as String?;
      final address = options['address'] as String?;

      switch (type) {
        case WalletType.monero:
          return monero!.createMoneroRestoreWalletFromKeysCredentials(
            name: name,
            height: height,
            spendKey: spendKey!,
            viewKey: viewKey!,
            address: address!,
            password: password,
            language: 'English',
          );

        case WalletType.haven:
          return haven!.createHavenRestoreWalletFromKeysCredentials(
            name: name,
            height: height,
            spendKey: spendKey!,
            viewKey: viewKey!,
            address: address!,
            password: password,
            language: 'English',
          );

        case WalletType.ethereum:
          return ethereum!.createEthereumRestoreWalletFromPrivateKey(
            name: name,
            privateKey: options['private_key'] as String,
            password: password,
          );

        case WalletType.nano:
          return nano!.createNanoRestoreWalletFromKeysCredentials(
              name: name,
              password: password,
              seedKey: options['private_key'] as String,
              derivationType: options["derivationType"] as DerivationType);
        case WalletType.polygon:
          return polygon!.createPolygonRestoreWalletFromPrivateKey(
            name: name,
            password: password,
            privateKey: options['private_key'] as String,
          );
        case WalletType.solana:
          return solana!.createSolanaRestoreWalletFromPrivateKey(
            name: name,
            password: password,
            privateKey: options['private_key'] as String,
          );
        case WalletType.tron:
          return tron!.createTronRestoreWalletFromPrivateKey(
            name: name,
            password: password,
            privateKey: options['private_key'] as String,
          );
        default:
          break;
      }
    }

    throw Exception('Unexpected type: ${type.toString()}');
  }

  Future<List<DerivationInfo>> getDerivationInfo(dynamic credentials) async {
    var list = <DerivationInfo>[];
    var walletType = credentials["walletType"] as WalletType;
    var appStore = getIt.get<AppStore>();
    var node = appStore.settingsStore.getCurrentNode(walletType);

    switch (walletType) {
      case WalletType.bitcoin:
      case WalletType.litecoin:
        String? mnemonic = credentials['seed'] as String?;
        String? passphrase = credentials['passphrase'] as String?;
        return bitcoin!.getDerivationsFromMnemonic(
          mnemonic: mnemonic!,
          node: node,
          passphrase: passphrase,
        );
      case WalletType.nano:
        String? mnemonic = credentials['seed'] as String?;
        String? seedKey = credentials['private_key'] as String?;
        return nanoUtil!.getDerivationsFromMnemonic(
          mnemonic: mnemonic,
          seedKey: seedKey,
          node: node,
        );
      default:
        break;
    }
    return list;
  }

  Future<DerivationInfo?> getFinalDerivationInfo(BuildContext context, dynamic credentials) async {
    state = IsExecutingState();
    try {
      DerivationInfo? dInfo;

      // get info about the different derivations:
      List<DerivationInfo> derivations = await getDerivationInfo(credentials);

      int derivationsWithHistory = 0;
      int derivationWithHistoryIndex = 0;
      for (int i = 0; i < derivations.length; i++) {
        if (derivations[i].transactionsCount > 0) {
          derivationsWithHistory++;
          derivationWithHistoryIndex = i;
        }
      }

      if (derivationsWithHistory > 1) {
        dInfo = await Navigator.of(context).pushNamed(
          Routes.restoreWalletChooseDerivation,
          arguments: derivations,
        ) as DerivationInfo?;
      } else if (derivationsWithHistory == 1) {
        dInfo = derivations[derivationWithHistoryIndex];
      }

      // get the default derivation for this wallet type:
      if (dInfo == null) {
        // we only return 1 derivation if we're pretty sure we know which one to use:
        if (derivations.length == 1) {
          dInfo = derivations.first;
        } else {
          // if we have multiple possible derivations, and none have histories
          // we just default to the most common one:
          dInfo = getCommonRestoreDerivation();
        }
      }

      if (dInfo == null) {
        dInfo = getDefaultDerivation();
      }
      return dInfo;
    } catch (e) {
      state = FailureState(e.toString());
      rethrow;
    }
  }

  @override
  Future<WalletBase> process(WalletCredentials credentials) async {
    if (mode == WalletRestoreMode.keys) {
      return walletCreationService.restoreFromKeys(credentials, isTestnet: useTestnet);
    }
    return walletCreationService.restoreFromSeed(credentials, isTestnet: useTestnet);
  }
}
