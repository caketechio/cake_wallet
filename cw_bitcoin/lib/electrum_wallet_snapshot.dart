import 'dart:convert';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/electrum_balance.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';

class ElectrumWallletSnapshot {
  ElectrumWallletSnapshot({
    required this.name,
    required this.type,
    required this.password,
    required this.mnemonic,
    required this.addresses,
    required this.balance,
    required this.regularAddressIndex,
    required this.changeAddressIndex,
  });

  final String name;
  final String password;
  final WalletType type;

  String mnemonic;
  List<BitcoinAddressRecord> addresses;
  ElectrumBalance balance;
  int regularAddressIndex;
  int changeAddressIndex;

  static Future<ElectrumWallletSnapshot> load(EncryptionFileUtils encryptionFileUtils, String name,
      WalletType type, String password, bool isFlatpak) async {
    final path = await pathForWallet(name: name, type: type, isFlatpak: isFlatpak);
    final jsonSource = await encryptionFileUtils.read(path: path, password: password);
    final data = json.decode(jsonSource) as Map;
    final addressesTmp = data['addresses'] as List? ?? <Object>[];
    final mnemonic = data['mnemonic'] as String;
    final addresses = addressesTmp
        .whereType<String>()
        .map((addr) => BitcoinAddressRecord.fromJSON(addr))
        .toList();
    final balance = ElectrumBalance.fromJSON(data['balance'] as String) ??
        ElectrumBalance(confirmed: 0, unconfirmed: 0, frozen: 0);
    var regularAddressIndex = 0;
    var changeAddressIndex = 0;

    try {
      regularAddressIndex = int.parse(data['account_index'] as String? ?? '0');
      changeAddressIndex = int.parse(data['change_address_index'] as String? ?? '0');
    } catch (_) {}

    return ElectrumWallletSnapshot(
      name: name,
      type: type,
      password: password,
      mnemonic: mnemonic,
      addresses: addresses,
      balance: balance,
      regularAddressIndex: regularAddressIndex,
      changeAddressIndex: changeAddressIndex,
    );
  }
}
