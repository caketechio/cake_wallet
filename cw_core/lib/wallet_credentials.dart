import 'package:cw_core/wallet_info.dart';

abstract class WalletCredentials {
  WalletCredentials({
    required this.name,
    this.height,
    this.seedPhraseLength,
    this.walletInfo,
    this.password,
    this.passphrase,
    this.derivationInfo,
    this.derivations,
    this.hardwareWalletType,
    this.parentAddress,
  }) {
    if (this.walletInfo != null && derivationInfo != null) {
      this.walletInfo!.derivationInfo = derivationInfo;
    }
  }

  final String name;
  final int? height;
  String? parentAddress;
  int? seedPhraseLength;
  String? password;
  String? passphrase;
  WalletInfo? walletInfo;
  DerivationInfo? derivationInfo;
  List<DerivationInfo>? derivations;
  HardwareWalletType? hardwareWalletType;
}
