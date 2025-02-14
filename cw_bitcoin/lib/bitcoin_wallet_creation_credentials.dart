import 'package:cw_core/hardware/hardware_account_data.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';

class BitcoinNewWalletCredentials extends WalletCredentials {
  BitcoinNewWalletCredentials({
    required super.name,
    super.walletInfo,
    super.password,
    super.passphrase,
    this.mnemonic,
    super.parentAddress,
  });

  final String? mnemonic;
}

class BitcoinRestoreWalletFromSeedCredentials extends WalletCredentials {
  BitcoinRestoreWalletFromSeedCredentials({
    required super.name,
    required super.password,
    required this.mnemonic,
    required super.derivations,
    super.walletInfo,
    super.passphrase,
  });

  final String mnemonic;
}

class BitcoinRestoreWalletFromWIFCredentials extends WalletCredentials {
  BitcoinRestoreWalletFromWIFCredentials({
    required String name,
    required String password,
    required this.wif,
    WalletInfo? walletInfo,
  }) : super(name: name, password: password, walletInfo: walletInfo);

  final String wif;
}

class BitcoinRestoreWalletFromHardware extends WalletCredentials {
  BitcoinRestoreWalletFromHardware({
    required String name,
    required this.hwAccountData,
    WalletInfo? walletInfo,
  }) : super(name: name, walletInfo: walletInfo);

  final HardwareAccountData hwAccountData;
}
