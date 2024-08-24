import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/wallet_creation_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/background_tasks.dart';
import 'package:cake_wallet/view_model/restore/restore_wallet.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/entities/generate_name.dart';
import 'package:polyseed/polyseed.dart';

part 'wallet_creation_vm.g.dart';

class WalletCreationVM = WalletCreationVMBase with _$WalletCreationVM;

abstract class WalletCreationVMBase with Store {
  WalletCreationVMBase(this._appStore, this._walletInfoSource, this.walletCreationService,
      {required this.type, required this.isRecovery})
      : state = InitialExecutionState(),
        name = '';

  @observable
  bool _useTestnet = false;

  @computed
  bool get useTestnet => _useTestnet;

  @observable
  String name;

  @observable
  ExecutionState state;

  @observable
  String? walletPassword;

  @observable
  String? repeatedWalletPassword;

  bool get hasWalletPassword => SettingsStoreBase.walletPasswordDirectInput;

  WalletType type;
  final bool isRecovery;
  final WalletCreationService walletCreationService;
  final Box<WalletInfo> _walletInfoSource;
  final AppStore _appStore;

  bool isPolyseed(String seed) =>
      (type == WalletType.monero || type == WalletType.wownero) &&
      (Polyseed.isValidSeed(seed) || (seed.split(" ").length == 14));

  bool nameExists(String name) => walletCreationService.exists(name);

  bool typeExists(WalletType type) => walletCreationService.typeExists(type);

  Future<void> create({dynamic options, RestoredWallet? restoreWallet}) async {
    final type = restoreWallet?.type ?? this.type;
    try {
      state = IsExecutingState();
      if (name.isEmpty) {
        name = await generateName();
      }

      if (hasWalletPassword && (walletPassword?.isEmpty ?? true)) {
        throw Exception(S.current.wallet_password_is_empty);
      }

      if (hasWalletPassword && walletPassword != repeatedWalletPassword) {
        throw Exception(S.current.repeated_password_is_incorrect);
      }

      walletCreationService.checkIfExists(name);
      final dirPath = await pathForWalletDir(name: name, type: type);
      final path = await pathForWallet(name: name, type: type);
      final credentials = restoreWallet != null
          ? getCredentialsFromRestoredWallet(options, restoreWallet)
          : getCredentials(options);

      final walletInfo = WalletInfo.external(
        id: WalletBase.idFor(name, type),
        name: name,
        type: type,
        isRecovery: isRecovery,
        restoreHeight: credentials.height ?? 0,
        date: DateTime.now(),
        path: path,
        dirPath: dirPath,
        address: '',
        showIntroCakePayCard: (!walletCreationService.typeExists(type)) && type != WalletType.haven,
        derivationInfo: credentials.derivationInfo ?? getDefaultDerivation(),
        hardwareWalletType: credentials.hardwareWalletType,
      );

      credentials.walletInfo = walletInfo;
      final wallet = restoreWallet != null
          ? await processFromRestoredWallet(credentials, restoreWallet)
          : await process(credentials);
      walletInfo.address = wallet.walletAddresses.address;
      await _walletInfoSource.add(walletInfo);
      await _appStore.changeCurrentWallet(wallet);
      getIt.get<BackgroundTasks>().registerSyncTask();
      _appStore.authenticationStore.allowed();
      state = ExecutedSuccessfullyState();
    } catch (e, s) {
      state = FailureState(e.toString());
    }
  }

  DerivationInfo? getDefaultDerivation() {
    switch (this.type) {
      case WalletType.nano:
        return DerivationInfo(derivationType: DerivationType.nano);
      case WalletType.bitcoin:
      case WalletType.lightning:
        return bitcoin!.getElectrumDerivations()[DerivationType.bip39]!.first;
      case WalletType.litecoin:
        return bitcoin!.getElectrumDerivations()[DerivationType.electrum]!.first;
      default:
        return null;
    }
  }

  DerivationInfo? getCommonRestoreDerivation() {
    switch (this.type) {
      case WalletType.nano:
        return DerivationInfo(derivationType: DerivationType.nano);
      case WalletType.bitcoin:
      case WalletType.lightning:
        return DerivationInfo(
          derivationType: DerivationType.bip39,
          derivationPath: "m/84'/0'/0'/0",
          description: "Standard BIP84 native segwit",
          scriptType: "p2wpkh",
        );
      case WalletType.litecoin:
        return DerivationInfo(
          derivationType: DerivationType.bip39,
          derivationPath: "m/84'/2'/0'/0",
          description: "Standard BIP84 native segwit (litecoin)",
          scriptType: "p2wpkh",
        );
      default:
        return null;
    }
  }

  WalletCredentials getCredentials(dynamic options) => throw UnimplementedError();

  Future<WalletBase> process(WalletCredentials credentials) => throw UnimplementedError();

  WalletCredentials getCredentialsFromRestoredWallet(
          dynamic options, RestoredWallet restoreWallet) =>
      throw UnimplementedError();

  Future<WalletBase> processFromRestoredWallet(
          WalletCredentials credentials, RestoredWallet restoreWallet) =>
      throw UnimplementedError();

  @action
  void toggleUseTestnet(bool? value) {
    _useTestnet = value ?? !_useTestnet;
  }
}
