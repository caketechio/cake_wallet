import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/bitcoin_unspent.dart';
import 'package:cw_bitcoin/seedbyte_types.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_mweb/cw_mweb.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';

part 'litecoin_wallet_addresses.g.dart';

class LitecoinWalletAddresses = LitecoinWalletAddressesBase with _$LitecoinWalletAddresses;

abstract class LitecoinWalletAddressesBase extends ElectrumWalletAddresses with Store {
  LitecoinWalletAddressesBase(
    WalletInfo walletInfo, {
    required super.hdWallets,
    required super.network,
    required super.isHardwareWallet,
    required this.mwebEnabled,
    super.initialAddresses,
    List<LitecoinMWEBAddressRecord>? initialMwebAddresses,
  })  : mwebAddresses =
            ObservableList<LitecoinMWEBAddressRecord>.of((initialMwebAddresses ?? []).toSet()),
        super(walletInfo) {
    mwebHd = hdWallet.derivePath("m/1000'") as Bip32Slip10Secp256k1;

    for (int i = 0; i < mwebAddresses.length; i++) {
      mwebAddrs.add(mwebAddresses[i].address);
    }
    printV("initialized with ${mwebAddrs.length} mweb addresses");
  }

  @override
  final walletAddressTypes = LITECOIN_ADDRESS_TYPES;

  static const LITECOIN_ADDRESS_TYPES = [SegwitAddressType.p2wpkh];

  final ObservableList<LitecoinMWEBAddressRecord> mwebAddresses;

  late final Bip32Slip10Secp256k1? mwebHd;
  bool mwebEnabled;
  int mwebTopUpIndex = 1000;
  List<String> mwebAddrs = [];
  bool generating = false;

  @observable
  int mwebIndex = 0;

  @observable
  LitecoinMWEBAddressRecord? activeMwebAddress;

  List<int> get scanSecret => mwebHd!.childKey(Bip32KeyIndex(0x80000000)).privateKey.privKey.raw;
  List<int> get spendPubkey =>
      mwebHd!.childKey(Bip32KeyIndex(0x80000001)).publicKey.pubKey.compressed;

  @override
  Future<void> init() async {
    if (!super.isHardwareWallet) await initMwebAddresses();

    for (final seedBytesType in hdWallets.keys) {
      await generateInitialAddresses(
        addressType: SegwitAddressType.p2wpkh,
        seedBytesType: seedBytesType,
        bitcoinDerivationInfo: seedBytesType.isElectrum
            ? BitcoinDerivationInfos.ELECTRUM
            : BitcoinDerivationInfos.LITECOIN,
      );

      if ((Platform.isAndroid || Platform.isIOS) && !isHardwareWallet) {
        await generateInitialMWEBAddresses(
          addressType: SegwitAddressType.mweb,
          seedBytesType: seedBytesType,
        );
      }
    }

    await super.init();
  }

  @action
  Future<void> generateInitialMWEBAddresses({
    required BitcoinAddressType addressType,
    required SeedBytesType seedBytesType,
  }) async {
    final existingAddresses = mwebAddresses
        .where((addr) => addr.type == addressType && addr.seedBytesType == seedBytesType)
        .toList();

    if (existingAddresses.length < ElectrumWalletAddressesBase.defaultReceiveAddressesCount) {
      await discoverNewMWEBAddresses(
        seedBytesType: seedBytesType,
        isChange: false,
      );
    }
  }

  @action
  Future<List<LitecoinMWEBAddressRecord>> discoverNewMWEBAddresses({
    required SeedBytesType seedBytesType,
    required bool isChange,
  }) async {
    final count = isChange
        ? ElectrumWalletAddressesBase.defaultChangeAddressesCount
        : ElectrumWalletAddressesBase.defaultReceiveAddressesCount;

    final startIndex = this.mwebAddresses.length;

    final mwebAddresses = <LitecoinMWEBAddressRecord>[];

    for (var i = startIndex; i < count + startIndex; i++) {
      final address = LitecoinMWEBAddressRecord(
        (await generateMWEBAddress(index: i)).toAddress(network),
        index: i,
        seedBytesType: seedBytesType,
      );
      mwebAddresses.add(address);
    }

    addMwebAddresses(mwebAddresses);
    return mwebAddresses;
  }

  @override
  @action
  Future<List<BitcoinAddressRecord>> discoverNewAddresses({
    required SeedBytesType seedBytesType,
    required bool isChange,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) async {
    if (addressType == SegwitAddressType.mweb) {
      final count = isChange
          ? ElectrumWalletAddressesBase.defaultChangeAddressesCount
          : ElectrumWalletAddressesBase.defaultReceiveAddressesCount;

      final startIndex = this.mwebAddresses.length;

      final mwebAddresses = <LitecoinMWEBAddressRecord>[];

      for (var i = startIndex; i < count + startIndex; i++) {
        final address = LitecoinMWEBAddressRecord(
          await getAddressAsync(
            derivationType: seedBytesType,
            isChange: isChange,
            index: i,
            addressType: addressType,
            derivationInfo: derivationInfo,
          ),
          index: i,
        );
        mwebAddresses.add(address);
      }

      addMwebAddresses(mwebAddresses);
      // TODO:
      return [];
    }

    return super.discoverNewAddresses(
      seedBytesType: seedBytesType,
      isChange: isChange,
      addressType: addressType,
      derivationInfo: derivationInfo,
    );
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
      printV("generating.....");
      // this function was called multiple times in multiple places:
      await Future.delayed(const Duration(milliseconds: 100));
    }

    printV("Generating MWEB addresses up to index $index");
    generating = true;
    try {
      while (mwebAddrs.length <= (index + 1)) {
        final addresses =
            await CwMweb.addresses(scan, spend, mwebAddrs.length, mwebAddrs.length + 50);
        printV("generated up to index ${mwebAddrs.length}");
        // sleep for a bit to avoid making the main thread unresponsive:
        await Future.delayed(Duration(milliseconds: 200));
        mwebAddrs.addAll(addresses!);
      }
    } catch (_) {}
    generating = false;
    printV("Done generating MWEB addresses len: ${mwebAddrs.length}");

    // ensure mweb addresses are up to date:
    // This is the Case if the Litecoin Wallet is a hardware Wallet
    if (mwebHd == null) return;

    if (mwebAddresses.length < mwebAddrs.length) {
      List<LitecoinMWEBAddressRecord> addressRecords = mwebAddrs
          .asMap()
          .entries
          .map(
            (e) => LitecoinMWEBAddressRecord(e.value, index: e.key),
          )
          .toList();
      addMwebAddresses(addressRecords);
      printV("set ${addressRecords.length} mweb addresses");
    }
  }

  Future<void> initMwebAddresses() async {
    if (mwebAddrs.length < 1000) {
      await ensureMwebAddressUpToIndexExists(20);
      return;
    }
  }

  Future<BitcoinBaseAddress> generateMWEBAddress({required int index}) async {
    await ensureMwebAddressUpToIndexExists(index);
    return MwebAddress.fromAddress(address: mwebAddrs[index]);
  }

  @override
  BitcoinBaseAddress generateAddress({
    required SeedBytesType seedBytesType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) {
    if (addressType == SegwitAddressType.mweb) {
      return MwebAddress.fromAddress(address: mwebAddrs[isChange ? index + 1 : 0]);
    }

    return P2wpkhAddress.fromDerivation(
      bip32: hdWallets[seedBytesType]!,
      derivationInfo: derivationInfo,
      isChange: isChange,
      index: index,
    );
  }

  @override
  Future<String> getAddressAsync({
    required SeedBytesType derivationType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) async {
    if (addressType == SegwitAddressType.mweb) {
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
  Future<BaseBitcoinAddressRecord> getChangeAddress({
    List<BitcoinUnspent>? inputs,
    List<BitcoinOutput>? outputs,
    bool isPegIn = false,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) async {
    // use regular change address on peg in, otherwise use mweb for change address:

    if (!mwebEnabled || coinTypeToSpendFrom == UnspentCoinType.nonMweb) {
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
      bool isNonMweb = !comesFromMweb && !outputsToMweb;

      // use regular change address if it's not an mweb tx or if it's a peg in:
      if (isPegIn || isNonMweb) {
        return super.getChangeAddress();
      }
    }

    if (mwebEnabled) {
      await ensureMwebAddressUpToIndexExists(1);
      updateAddressesByType();
      return LitecoinMWEBAddressRecord(mwebAddrs[0], index: 0, network: network);
    }

    return super.getChangeAddress();
  }

  @override
  @computed
  String get address {
    if (addressPageType == SegwitAddressType.mweb) {
      if (activeMwebAddress != null) {
        return activeMwebAddress!.address;
      }

      return mwebAddresses[0].address;
    }

    return super.address;
  }

  @override
  set address(String addr) {
    if (addressPageType == SegwitAddressType.mweb) {
      final selected =
          mwebAddresses.firstWhereOrNull((addressRecord) => addressRecord.address == addr) ??
              mwebAddresses[0];

      activeMwebAddress = selected;

      if (!selected.isChange) {
        mwebIndex = selected.index;
      }

      return;
    }

    super.address = addr;
  }

  @override
  @computed
  String get addressForExchange {
    // don't use mweb addresses for exchange refund address:
    final addresses = allAddresses.firstWhere(
      (element) => element.type == SegwitAddressType.p2wpkh && getIsUsed(element),
    );
    return addresses.address;
  }

  @override
  Future<void> updateAddressesInBox() async {
    super.updateAddressesInBox();

    final lastP2wpkh =
        allAddresses.where((addressRecord) => isUnusedReceiveAddress(addressRecord)).toList().last;
    if (lastP2wpkh.address != address) {
      addressesMap[lastP2wpkh.address] = 'P2WPKH';
    } else {
      addressesMap[address] = 'Active - P2WPKH';
    }

    final lastMweb = mwebAddresses.firstWhere(
      (addressRecord) => isUnusedReceiveAddress(addressRecord),
    );
    if (lastMweb.address != address) {
      addressesMap[lastMweb.address] = 'MWEB';
    } else {
      addressesMap[address] = 'Active - MWEB';
    }

    await saveAddressesInBox();
  }

  @override
  @action
  void updateAddress(String address, String label) {
    BaseBitcoinAddressRecord? foundAddress;
    allAddresses.forEach((addressRecord) {
      if (addressRecord.address == address) {
        foundAddress = addressRecord;
      }
    });
    mwebAddresses.forEach((addressRecord) {
      if (addressRecord.address == address) {
        foundAddress = addressRecord;
      }
    });

    if (foundAddress != null) {
      foundAddress!.setNewName(label);

      if (foundAddress is BitcoinAddressRecord) {
        final index = allAddresses.indexOf(foundAddress! as BitcoinAddressRecord);
        allAddresses.remove(foundAddress);
        allAddresses.insert(index, foundAddress as BitcoinAddressRecord);
      }
    }
  }

  @action
  void addMwebAddresses(Iterable<LitecoinMWEBAddressRecord> addresses) {
    final newMwebAddresses = <LitecoinMWEBAddressRecord>[];
    for (final address in addresses) {
      if (mwebAddresses.any((existing) => existing.address == address.address)) {
        continue;
      }
      newMwebAddresses.add(address);
    }

    this.mwebAddresses.addAll(newMwebAddresses);
    updateAddressesByType();
  }

  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['mwebAddresses'] = mwebAddresses.map((address) => address.toJSON()).toList();
    // json['mwebAddressIndex'] =
    return json;
  }

  static Map<String, dynamic> fromSnapshot(Map<dynamic, dynamic> data) {
    final electrumSnapshot = ElectrumWalletAddressesBase.fromSnapshot(data);

    final mwebAddresses = data['mweb_addresses'] as List? ??
        <Object>[].map((e) => LitecoinMWEBAddressRecord.fromJSON(e as String)).toList();

    // var mwebAddressIndex = 0;

    // try {
    //   mwebAddressIndex = int.parse(data['silent_address_index'] as String? ?? '0');
    // } catch (_) {}

    return {
      'allAddresses': electrumSnapshot["addresses"],
      'addressPageType': data['address_page_type'] as String?,
      'receiveAddressIndexByType': electrumSnapshot["receiveAddressIndexByType"],
      'changeAddressIndexByType': electrumSnapshot["changeAddressIndexByType"],
      'mwebAddresses': mwebAddresses,
    };
  }

  static LitecoinWalletAddressesBase fromJson(
    Map<String, dynamic> json,
    WalletInfo walletInfo, {
    required Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets,
    required BasedUtxoNetwork network,
    required bool isHardwareWallet,
    List<BitcoinAddressRecord>? initialAddresses,
    List<LitecoinMWEBAddressRecord>? initialMwebAddresses,
  }) {
    initialAddresses ??= (json['allAddresses'] as List)
        .map((record) => BitcoinAddressRecord.fromJSON(record as String))
        .toList();

    initialMwebAddresses ??= (json['mwebAddresses'] as List)
        .map(
          (address) => LitecoinMWEBAddressRecord.fromJSON(address as String),
        )
        .toList();

    return LitecoinWalletAddresses(
      walletInfo,
      hdWallets: hdWallets,
      network: network,
      isHardwareWallet: isHardwareWallet,
      initialAddresses: initialAddresses,
      initialMwebAddresses: initialMwebAddresses,
      mwebEnabled: true, // TODO
    );
  }

  @override
  @action
  void updateAddressesByType() {
    receiveAddressesByType[SegwitAddressType.mweb] = mwebAddresses.toList();
    super.updateAddressesByType();
  }

  @override
  bool getShouldHideAddress(Bip32Path path) {
    if (seedTypeIsElectrum) {
      return path.toString() != BitcoinDerivationInfos.ELECTRUM.derivationPath.toString();
    }

    return path.toString() != BitcoinDerivationInfos.LITECOIN.derivationPath.toString();
  }
}
