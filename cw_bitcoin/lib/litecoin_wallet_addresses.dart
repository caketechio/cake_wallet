import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_mweb/cw_mweb.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';

part 'litecoin_wallet_addresses.g.dart';

class LitecoinWalletAddresses = LitecoinWalletAddressesBase with _$LitecoinWalletAddresses;

abstract class LitecoinWalletAddressesBase extends ElectrumWalletAddresses with Store {
  LitecoinWalletAddressesBase(
    WalletInfo walletInfo, {
    required super.network,
    required super.isHardwareWallet,
    required this.mwebHd,
    required this.mwebEnabled,
    required super.hdWallets,
    super.initialAddresses,
    super.initialMwebAddresses,
    super.initialRegularAddressIndex,
    super.initialChangeAddressIndex,
  }) : super(walletInfo) {
    for (int i = 0; i < mwebAddresses.length; i++) {
      mwebAddrs.add(mwebAddresses[i].address);
    }
    print("initialized with ${mwebAddrs.length} mweb addresses");
  }

  final Bip32Slip10Secp256k1? mwebHd;
  bool mwebEnabled;
  int mwebTopUpIndex = 1000;
  List<String> mwebAddrs = [];
  bool generating = false;

  List<int> get scanSecret => mwebHd!.childKey(Bip32KeyIndex(0x80000000)).privateKey.privKey.raw;
  List<int> get spendPubkey =>
      mwebHd!.childKey(Bip32KeyIndex(0x80000001)).publicKey.pubKey.compressed;

  @override
  Future<void> init() async {
    if (!super.isHardwareWallet) await initMwebAddresses();
    await super.init();
  }

  @computed
  @override
  List<BitcoinAddressRecord> get allAddresses {
    return List.from(super.allAddresses)..addAll(mwebAddresses);
  }

  Future<void> ensureMwebAddressUpToIndexExists(int index) async {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return null;
    }

    Uint8List scan = Uint8List.fromList(scanSecret);
    Uint8List spend = Uint8List.fromList(spendPubkey);

    if (index < mwebAddresses.length && index < mwebAddrs.length) {
      return;
    }

    while (generating) {
      print("generating.....");
      // this function was called multiple times in multiple places:
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print("Generating MWEB addresses up to index $index");
    generating = true;
    try {
      while (mwebAddrs.length <= (index + 1)) {
        final addresses =
            await CwMweb.addresses(scan, spend, mwebAddrs.length, mwebAddrs.length + 50);
        print("generated up to index ${mwebAddrs.length}");
        // sleep for a bit to avoid making the main thread unresponsive:
        await Future.delayed(Duration(milliseconds: 200));
        mwebAddrs.addAll(addresses!);
      }
    } catch (_) {}
    generating = false;
    print("Done generating MWEB addresses len: ${mwebAddrs.length}");

    // ensure mweb addresses are up to date:
    // This is the Case if the Litecoin Wallet is a hardware Wallet
    if (mwebHd == null) return;

    if (mwebAddresses.length < mwebAddrs.length) {
      List<BitcoinAddressRecord> addressRecords = mwebAddrs
          .asMap()
          .entries
          .map(
            (e) => BitcoinAddressRecord(
              e.value,
              index: e.key,
              type: SegwitAddresType.mweb,
              network: network,
              derivationInfo: BitcoinAddressUtils.getDerivationFromType(SegwitAddresType.p2wpkh),
              derivationType: CWBitcoinDerivationType.bip39,
            ),
          )
          .toList();
      addMwebAddresses(addressRecords);
      print("set ${addressRecords.length} mweb addresses");
    }
  }

  Future<void> initMwebAddresses() async {
    if (mwebAddrs.length < 1000) {
      await ensureMwebAddressUpToIndexExists(20);
      return;
    }

    @override
    BitcoinBaseAddress generateAddress({
      required CWBitcoinDerivationType derivationType,
      required bool isChange,
      required int index,
      required BitcoinAddressType addressType,
      required BitcoinDerivationInfo derivationInfo,
    }) {
      if (addressType == SegwitAddresType.mweb) {
        return MwebAddress.fromAddress(address: mwebAddrs[0], network: network);
      }

      return P2wpkhAddress.fromDerivation(
        bip32: bip32,
        derivationInfo: derivationInfo,
        isChange: isChange,
        index: index,
      );
    }
  }

  @override
  Future<String> getAddressAsync({
    required CWBitcoinDerivationType derivationType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) async {
    if (addressType == SegwitAddresType.mweb) {
      await ensureMwebAddressUpToIndexExists(index);
    }

    return getAddress(
      derivationType: derivationType,
      isChange: isChange,
      index: index,
      addressType: addressType,
      derivationInfo: derivationInfo,
    );
  }

  @action
  @override
  Future<BitcoinAddressRecord> getChangeAddress(
      {List<BitcoinUnspent>? inputs, List<BitcoinOutput>? outputs, bool isPegIn = false}) async {
    // use regular change address on peg in, otherwise use mweb for change address:

    if (!mwebEnabled || isPegIn) {
      return super.getChangeAddress();
    }

    if (inputs != null && outputs != null) {
      // check if this is a PEGIN:
      bool outputsToMweb = false;
      bool comesFromMweb = false;

      for (var i = 0; i < outputs.length; i++) {
        // TODO: probably not the best way to tell if this is an mweb address
        // (but it doesn't contain the "mweb" text at this stage)
        if (outputs[i].address.toAddress(network).length > 110) {
          outputsToMweb = true;
        }
      }

      inputs.forEach((element) {
        if (!element.isSending || element.isFrozen) {
          return;
        }
        if (element.address.contains("mweb")) {
          comesFromMweb = true;
        }
      });

      bool isPegIn = !comesFromMweb && outputsToMweb;

      if (isPegIn && mwebEnabled) {
        return super.getChangeAddress();
      }

      // use regular change address if it's not an mweb tx:
      if (!comesFromMweb && !outputsToMweb) {
        return super.getChangeAddress();
      }
    }

    if (mwebEnabled) {
      await ensureMwebAddressUpToIndexExists(1);
      return BitcoinAddressRecord(
        mwebAddrs[0],
        index: 0,
        type: SegwitAddresType.mweb,
        network: network,
        derivationInfo: BitcoinAddressUtils.getDerivationFromType(SegwitAddresType.p2wpkh),
        derivationType: CWBitcoinDerivationType.bip39,
      );
    }

    return super.getChangeAddress();
  }
}
