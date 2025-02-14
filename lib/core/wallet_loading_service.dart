import 'dart:async';

import 'package:cake_wallet/core/generate_wallet_password.dart';
import 'package:cake_wallet/core/key_service.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/reactions/on_authentication_state_change.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletLoadingService {
  WalletLoadingService(
    this.sharedPreferences,
    this.keyService,
    this.walletServiceFactory,
  );

  final SharedPreferences sharedPreferences;
  final KeyService keyService;
  final WalletService Function(WalletType type) walletServiceFactory;

  Future<void> renameWallet(WalletType type, String name, String newName,
      {String? password}) async {
    final walletService = walletServiceFactory.call(type);
    final walletPassword = password ?? (await keyService.getWalletPassword(walletName: name));

    // Save the current wallet's password to the new wallet name's key
    await keyService.saveWalletPassword(walletName: newName, password: walletPassword);
    // Delete previous wallet name from keyService to keep only new wallet's name
    // otherwise keeps duplicate (old and new names)
    await keyService.deleteWalletPassword(walletName: name);

    await walletService.rename(name, walletPassword, newName);

    // set shared preferences flag based on previous wallet name
    if (type == WalletType.monero) {
      final oldNameKey = PreferencesKey.moneroWalletUpdateV1Key(name);
      final isPasswordUpdated = sharedPreferences.getBool(oldNameKey) ?? false;
      final newNameKey = PreferencesKey.moneroWalletUpdateV1Key(newName);
      await sharedPreferences.setBool(newNameKey, isPasswordUpdated);
    }
  }

  Future<WalletBase> load(WalletType type, String name, {String? password}) async {
    try {
      final walletService = walletServiceFactory.call(type);
      final walletPassword = password ?? (await keyService.getWalletPassword(walletName: name));
      final wallet = await walletService.openWallet(name, walletPassword);

      if (type == WalletType.monero) {
        await updateMoneroWalletPassword(wallet);
      }

      return wallet;
    } catch (error, stack) {
      await ExceptionHandler.resetLastPopupDate();
      await ExceptionHandler.onError(FlutterErrorDetails(exception: error, stack: stack));

      // try fetching the seeds of the corrupted wallet to show it to the user
      String corruptedWalletsSeeds = "Corrupted wallets seeds (if retrievable, empty otherwise):";
      try {
        corruptedWalletsSeeds += await _getCorruptedWalletSeeds(name, type);
      } catch (e) {
        corruptedWalletsSeeds += "\nFailed to fetch $name seeds: $e";
      }

      // try opening another wallet that is not corrupted to give user access to the app
      final walletInfoSource = await CakeHive.openBox<WalletInfo>(WalletInfo.boxName);
      WalletBase? wallet;
      for (var walletInfo in walletInfoSource.values) {
        try {
          final walletService = walletServiceFactory.call(walletInfo.type);
          final walletPassword = await keyService.getWalletPassword(walletName: walletInfo.name);
          wallet = await walletService.openWallet(walletInfo.name, walletPassword);

          if (walletInfo.type == WalletType.monero) {
            await updateMoneroWalletPassword(wallet);
          }

          await sharedPreferences.setString(PreferencesKey.currentWalletName, wallet.name);
          await sharedPreferences.setInt(
              PreferencesKey.currentWalletType, serializeToInt(wallet.type));

          // if found a wallet that is not corrupted, then still display the seeds of the corrupted ones
          authenticatedErrorStreamController.add(corruptedWalletsSeeds);
        } catch (e) {
          printV(e);
          // save seeds and show corrupted wallets' seeds to the user
          try {
            final seeds = await _getCorruptedWalletSeeds(walletInfo.name, walletInfo.type);
            if (!corruptedWalletsSeeds.contains(seeds)) {
              corruptedWalletsSeeds += seeds;
            }
          } catch (e) {
            corruptedWalletsSeeds += "\nFailed to fetch $name seeds: $e";
          }
        }
      }

      // if all user's wallets are corrupted throw exception
      final msg = error.toString() + "\n" + corruptedWalletsSeeds;
      if (navigatorKey.currentContext != null) {
        await showPopUp<void>(
            context: navigatorKey.currentContext!,
            builder: (BuildContext context) {
              return AlertWithTwoActions(
                alertTitle: "Corrupted seeds",
                alertContent: S.of(context).corrupted_seed_notice,
                leftButtonText: S.of(context).cancel,
                rightButtonText: S.of(context).show_seed,
                actionLeftButton: () => Navigator.of(context).pop(),
                actionRightButton: () => showSeedsPopup(context, msg),
              );
            });
      } else {
        throw msg;
      }
      if (wallet == null) {
        throw Exception("Wallet is null");
      }
      return wallet;
    }
  }

  Future<void> showSeedsPopup(BuildContext context, String message) async {
    Navigator.of(context).pop();
    await showPopUp<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertWithTwoActions(
            alertTitle: "Corrupted seeds",
            alertContent: message,
            leftButtonText: S.of(context).copy,
            rightButtonText: S.of(context).ok,
            actionLeftButton: () async {
              await Clipboard.setData(ClipboardData(text: message));
            },
            actionRightButton: () async {
              Navigator.of(context).pop();
            },
          );
        });
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

  Future<String> _getCorruptedWalletSeeds(String name, WalletType type) async {
    final walletService = walletServiceFactory.call(type);
    final password = await keyService.getWalletPassword(walletName: name);

    return "\n\n$type ($name): ${await walletService.getSeeds(name, password, type)}";
  }

  bool requireHardwareWalletConnection(WalletType type, String name) {
    final walletService = walletServiceFactory.call(type);
    return walletService.requireHardwareWalletConnection(name);
  }
}
