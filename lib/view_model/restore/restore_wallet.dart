import 'dart:convert';

import 'package:cake_wallet/view_model/restore/restore_mode.dart';
import 'package:cw_core/wallet_type.dart';

class RestoredWallet {
  RestoredWallet(
      {required this.restoreMode,
      required this.type,
      required this.address,
      this.txId,
      this.spendKey,
      this.viewKey,
      this.mnemonicSeed,
      this.passphrase,
      this.txAmount,
      this.txDescription,
      this.recipientName,
      this.height,
      this.privateKey,
      this.source});

  final WalletRestoreMode restoreMode;
  final WalletType type;
  final String? address;
  final String? txId;
  final String? spendKey;
  final String? viewKey;
  final String? mnemonicSeed;
  final String? passphrase;
  final String? txAmount;
  final String? txDescription;
  final String? recipientName;
  final int? height;
  final String? privateKey;
  final String? source;

  factory RestoredWallet.fromKey(Map<String, dynamic> json) {
    try {
    final codeParsed = jsonDecode(json['raw_qr'].toString());
      if (codeParsed["version"] == 0) {
        json['address'] = codeParsed["primaryAddress"];
        json['view_key'] = codeParsed["privateViewKey"];
        json['height'] = codeParsed["restoreHeight"].toString();
        json['source'] = codeParsed["source"] ?? '';
      }
    } catch (e) {
      // fine, we don't care, it is only for monero anyway
    }
    final height = json['height'] as String?;
    return RestoredWallet(
      restoreMode: json['mode'] as WalletRestoreMode,
      type: json['type'] as WalletType,
      address: json['address'] as String?,
      spendKey: json['spend_key'] as String?,
      viewKey: json['view_key'] as String?,
      height: height != null ? int.tryParse(height)??0 : 0,
      privateKey: json['private_key'] as String?,
      source: json['source'] as String?,
    );
  }

  factory RestoredWallet.fromSeed(Map<String, dynamic> json) {
    final height = json['height'] as String?;
    final mnemonic_seed = json['mnemonic_seed'] as String?;
    final seed = json['seed'] as String? ?? json['hexSeed'] as String?;
    final passphrase = json['passphrase'] as String?;
    return RestoredWallet(
      restoreMode: json['mode'] as WalletRestoreMode,
      type: json['type'] as WalletType,
      address: json['address'] as String?,
      mnemonicSeed: mnemonic_seed ?? seed,
      passphrase: passphrase,
      height: height != null ? int.parse(height) : 0,
    );
  }

  factory RestoredWallet.fromTxIds(Map<String, dynamic> json) {
    return RestoredWallet(
      restoreMode: json['mode'] as WalletRestoreMode,
      type: json['type'] as WalletType,
      address: json['address'] as String?,
      txId: json['tx_payment_id'] as String,
      txAmount: json['tx_amount'] as String,
      txDescription: json['tx_description'] as String?,
      recipientName: json['recipient_name'] as String?,
    );
  }
}
