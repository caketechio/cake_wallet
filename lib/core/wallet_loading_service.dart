import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/generate_wallet_password.dart';
import 'package:cake_wallet/core/key_service.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletLoadingService {
  WalletLoadingService(
    this.sharedPreferences,
    this.keyService,
    this.walletServiceFactory,
    this.torViewModel,
  );

  final SharedPreferences sharedPreferences;
  final KeyService keyService;
  final WalletService Function(WalletType type) walletServiceFactory;
  final TorViewModel torViewModel;

  Future<void> renameWallet(WalletType type, String name, String newName) async {
    final walletService = walletServiceFactory.call(type);
    final password = await keyService.getWalletPassword(walletName: name);

    // Save the current wallet's password to the new wallet name's key
    await keyService.saveWalletPassword(walletName: newName, password: password);
    // Delete previous wallet name from keyService to keep only new wallet's name
    // otherwise keeps duplicate (old and new names)
    await keyService.deleteWalletPassword(walletName: name);

    await walletService.rename(name, password, newName);

    // set shared preferences flag based on previous wallet name
    if (type == WalletType.monero) {
      final oldNameKey = PreferencesKey.moneroWalletUpdateV1Key(name);
      final isPasswordUpdated = sharedPreferences.getBool(oldNameKey) ?? false;
      final newNameKey = PreferencesKey.moneroWalletUpdateV1Key(newName);
      await sharedPreferences.setBool(newNameKey, isPasswordUpdated);
    }
  }

  Future<WalletBase> load(WalletType type, String name) async {
    final walletService = walletServiceFactory.call(type);
    final password = await keyService.getWalletPassword(walletName: name);
    final wallet = await walletService.openWallet(name, password);

    if (type == WalletType.monero) {
      await updateMoneroWalletPassword(wallet);
    }

    TorConnectionMode mode = TorConnectionMode.deserialize(
      raw: sharedPreferences.getInt(PreferencesKey.currentTorConnectionModeKey) ?? 0,
    );

    if ([WalletType.bitcoin, WalletType.litecoin, WalletType.bitcoinCash].contains(type)) {
      bitcoin!.setTorOnly(wallet, mode == TorConnectionMode.torOnly);
    }

    final status = torViewModel.torConnectionStatus;
    if (status == TorConnectionStatus.connected || status == TorConnectionStatus.connecting) {
      // disconnect from node until tor is started:
      await torViewModel.disconnectFromNode();
    }

    return wallet;
  }

  Future<void> updateMoneroWalletPassword(WalletBase wallet) async {
    final key = PreferencesKey.moneroWalletUpdateV1Key(wallet.name);
    var isPasswordUpdated = sharedPreferences.getBool(key) ?? false;

    if (isPasswordUpdated) {
      return;
    }

    final password = generateWalletPassword();
    // Save new generated password with backup key for case where
    // wallet will change password, but it will fail to update in secure storage
    final bakWalletName = '#__${wallet.name}_bak__#';
    await keyService.saveWalletPassword(walletName: bakWalletName, password: password);
    await wallet.changePassword(password);
    await keyService.saveWalletPassword(walletName: wallet.name, password: password);
    isPasswordUpdated = true;
    await sharedPreferences.setBool(key, isPasswordUpdated);
  }
}
