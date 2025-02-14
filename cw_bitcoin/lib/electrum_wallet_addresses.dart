import 'package:collection/collection.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_bitcoin/seedbyte_types.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:mobx/mobx.dart';

part 'electrum_wallet_addresses.g.dart';

class ElectrumWalletAddresses = ElectrumWalletAddressesBase with _$ElectrumWalletAddresses;

abstract class ElectrumWalletAddressesBase extends WalletAddresses with Store {
  ElectrumWalletAddressesBase(
    WalletInfo walletInfo, {
    required this.hdWallets,
    required this.network,
    required this.isHardwareWallet,
    List<BitcoinAddressRecord>? initialAddresses,
    Map<String, int>? initialRegularAddressIndex,
    Map<String, int>? initialChangeAddressIndex,
    BitcoinAddressType? initialAddressPageType,
  })  : _allAddresses = ObservableList.of(initialAddresses ?? []),
        currentReceiveAddressIndexByType = initialRegularAddressIndex ?? {},
        currentChangeAddressIndexByType = initialChangeAddressIndex ?? {},
        addressPageType = initialAddressPageType ??
            (walletInfo.addressPageType != null
                ? BitcoinAddressType.fromValue(walletInfo.addressPageType!)
                : SegwitAddressType.p2wpkh),
        super(walletInfo);

  static const defaultReceiveAddressesCount = 22;
  static const defaultChangeAddressesCount = 17;
  static const gap = 20;

  final walletAddressTypes = <BitcoinAddressType>[];

  final ObservableList<BitcoinAddressRecord> _allAddresses;
  @observable
  Map<BitcoinAddressType, List<BaseBitcoinAddressRecord>> receiveAddressesByType = {};
  @observable
  Map<BitcoinAddressType, List<BaseBitcoinAddressRecord>> changeAddressesByType = {};

  final BasedUtxoNetwork network;

  final Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets;
  Bip32Slip10Secp256k1 get hdWallet =>
      hdWallets[SeedBytesType.bip39] ?? hdWallets[SeedBytesType.electrum]!;
  bool get seedTypeIsElectrum =>
      hdWallets[SeedBytesType.bip39] == null && hdWallets[SeedBytesType.electrum] != null;

  final bool isHardwareWallet;

  @observable
  BitcoinAddressType addressPageType;

  @computed
  List<BitcoinAddressRecord> get allChangeAddresses =>
      _allAddresses.where((addr) => addr.isChange).toList();

  @computed
  List<BaseBitcoinAddressRecord> get selectedReceiveAddresses =>
      receiveAddressesByType[addressPageType] ?? [];

  @computed
  List<BaseBitcoinAddressRecord> get selectedChangeAddresses =>
      changeAddressesByType[changeAddressType] ?? [];

  List<BaseBitcoinAddressRecord> getAddressesByType(
    BitcoinAddressType type, [
    bool isChange = false,
  ]) =>
      (isChange ? changeAddressesByType[type] : receiveAddressesByType[type]) ?? [];

  @computed
  List<BitcoinAddressRecord> get allAddresses => _allAddresses.toList();

  @computed
  Set<String> get allScriptHashes =>
      _allAddresses.map((addressRecord) => addressRecord.scriptHash).toSet();

  BitcoinAddressRecord getFromAddresses(String address) {
    return _allAddresses.firstWhere((element) => element.address == address);
  }

  // TODO: toggle to switch
  @observable
  BitcoinAddressType changeAddressType = SegwitAddressType.p2wpkh;

  @observable
  BitcoinAddressRecord? activeAddress;

  // TODO: map by type
  @observable
  int activeAddressIndex = 0;

  @override
  @action
  void resetActiveChangeAddress() {
    if (isEnabledAutoGenerateSubaddress) {
      try {
        activeAddress = _allAddresses.firstWhere(
          (addressRecord) =>
              addressRecord.type == addressPageType &&
              addressRecord.index == activeAddressIndex &&
              getIsReceive(addressRecord),
        );

        return;
      } catch (_) {}

      try {
        activeAddress = _allAddresses.firstWhere(
          (addressRecord) => addressRecord.type == addressPageType && getIsReceive(addressRecord),
        );
        return;
      } catch (_) {}
    }

    try {
      activeAddress = _allAddresses.firstWhere(
        (addressRecord) =>
            addressRecord.type == addressPageType &&
            addressRecord.index == activeAddressIndex &&
            !addressRecord.isChange &&
            !addressRecord.isHidden,
      );
    } catch (_) {}
  }

  @override
  @computed
  String get address {
    if (activeAddress != null) {
      return activeAddress!.address;
    }

    String? receiveAddress = "";

    if (isEnabledAutoGenerateSubaddress && selectedReceiveAddresses.isEmpty) {
      receiveAddress =
          selectedReceiveAddresses.firstWhereOrNull((addr) => !getIsUsed(addr))?.address;
    } else {
      receiveAddress = selectedReceiveAddresses.first.address;
    }

    return receiveAddress ?? '';
  }

  @observable
  bool isEnabledAutoGenerateSubaddress = true;

  @override
  set address(String addr) {
    try {
      final addressRecord = _allAddresses.firstWhere(
        (addressRecord) => addressRecord.address == addr,
      );

      activeAddress = addressRecord;

      if (getIsReceive(addressRecord)) {
        activeAddressIndex = addressRecord.index;
      }
    } catch (e) {
      printV("ElectrumWalletAddressBase: set address ($addr): $e");
    }
  }

  @override
  String get primaryAddress => _allAddresses.first.address;

  Map<String, int> currentReceiveAddressIndexByType;

  int get currentReceiveAddressIndex =>
      currentReceiveAddressIndexByType[addressPageType.toString()] ?? 0;

  void set currentReceiveAddressIndex(int index) =>
      currentReceiveAddressIndexByType[addressPageType.toString()] = index;

  Map<String, int> currentChangeAddressIndexByType;

  int get currentChangeAddressIndex =>
      currentChangeAddressIndexByType[addressPageType.toString()] ?? 0;

  void set currentChangeAddressIndex(int index) =>
      currentChangeAddressIndexByType[addressPageType.toString()] = index;

  SeedBytesType getHDWalletType() {
    if (hdWallets.containsKey(SeedBytesType.bip39)) {
      return SeedBytesType.bip39;
    } else if (hdWallets.containsKey(SeedBytesType.electrum)) {
      return SeedBytesType.electrum;
    } else {
      return hdWallets.keys.first;
    }
  }

  @override
  Future<void> init() async {
    updateAddressesByType();
    updateHiddenAddresses();
    await updateAddressesInBox();
  }

  Future<BaseBitcoinAddressRecord> getChangeAddress() async {
    final address = selectedChangeAddresses.firstWhere(
      (addr) => addr.isChange && !getIsUsed(addr) && addr.type == changeAddressType,
    );
    return address;
  }

  BaseBitcoinAddressRecord generateNewAddress({String label = ''}) {
    final newAddressIndex = selectedReceiveAddresses.fold(
      0,
      (int acc, addressRecord) => addressRecord.isChange == false ? acc + 1 : acc,
    );

    final derivationInfo = BitcoinAddressUtils.getDerivationFromType(addressPageType);
    final address = BitcoinAddressRecord(
      getAddress(
        derivationType: getHDWalletType(),
        isChange: false,
        index: newAddressIndex,
        addressType: addressPageType,
        derivationInfo: derivationInfo,
      ),
      index: newAddressIndex,
      isChange: false,
      name: label,
      type: addressPageType,
      network: network,
      derivationInfo: BitcoinAddressUtils.getDerivationFromType(addressPageType),
      seedBytesType: getHDWalletType(),
    );
    return address;
  }

  BitcoinBaseAddress generateAddress({
    required SeedBytesType seedBytesType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) {
    final hdWallet = hdWallets[seedBytesType]!;

    switch (addressType) {
      case P2pkhAddressType.p2pkh:
        return P2pkhAddress.fromDerivation(
          bip32: hdWallet,
          derivationInfo: derivationInfo,
          isChange: isChange,
          index: index,
        );
      case SegwitAddressType.p2tr:
        return P2trAddress.fromDerivation(
          bip32: hdWallet,
          derivationInfo: derivationInfo,
          isChange: isChange,
          index: index,
        );
      case SegwitAddressType.p2wsh:
        return P2wshAddress.fromDerivation(
          bip32: hdWallet,
          derivationInfo: derivationInfo,
          isChange: isChange,
          index: index,
        );
      case P2shAddressType.p2wpkhInP2sh:
        return P2shAddress.fromDerivation(
          bip32: hdWallet,
          derivationInfo: derivationInfo,
          isChange: isChange,
          index: index,
          type: P2shAddressType.p2wpkhInP2sh,
        );
      case SegwitAddressType.p2wpkh:
        return P2wpkhAddress.fromDerivation(
          bip32: hdWallet,
          derivationInfo: derivationInfo,
          isChange: isChange,
          index: index,
        );
      default:
        throw ArgumentError('Invalid address type');
    }
  }

  String getAddress({
    required SeedBytesType derivationType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) {
    return generateAddress(
      seedBytesType: derivationType,
      isChange: isChange,
      index: index,
      addressType: addressType,
      derivationInfo: derivationInfo,
    ).toAddress(network);
  }

  Future<String> getAddressAsync({
    required SeedBytesType derivationType,
    required bool isChange,
    required int index,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) async =>
      getAddress(
        derivationType: derivationType,
        isChange: isChange,
        index: index,
        addressType: addressType,
        derivationInfo: derivationInfo,
      );

  @override
  @action
  Future<void> updateAddressesInBox() async {
    addressesMap.clear();
    addressesMap[address] = 'Active - ' + addressPageType.toString() + ': $address';

    allAddressesMap.clear();
    _allAddresses.forEach((addressRecord) {
      allAddressesMap[addressRecord.address] = addressRecord.name;
    });

    await saveAddressesInBox();
  }

  @action
  void updateAddress(String address, String label) {
    BaseBitcoinAddressRecord? foundAddress;
    _allAddresses.forEach((addressRecord) {
      if (addressRecord.address == address) {
        foundAddress = addressRecord;
      }
    });

    if (foundAddress != null) {
      foundAddress!.setNewName(label);
    }
  }

  @action
  void updateAddressesByType() {
    walletAddressTypes.forEach((type) {
      receiveAddressesByType[type] =
          _allAddresses.where((addr) => _isAddressByType(addr, type) && !addr.isChange).toList();
      changeAddressesByType[type] =
          _allAddresses.where((addr) => _isAddressByType(addr, type) && addr.isChange).toList();
    });
  }

  @action
  Future<List<BitcoinAddressRecord>> discoverNewAddresses({
    required SeedBytesType seedBytesType,
    required bool isChange,
    required BitcoinAddressType addressType,
    required BitcoinDerivationInfo derivationInfo,
  }) async {
    final count = isChange
        ? ElectrumWalletAddressesBase.defaultChangeAddressesCount
        : ElectrumWalletAddressesBase.defaultReceiveAddressesCount;

    final startIndex =
        ((isChange ? changeAddressesByType[addressType] : receiveAddressesByType[addressType]) ??
                [])
            .where(
              (addr) =>
                  (addr as BitcoinAddressRecord).seedBytesType == seedBytesType &&
                  addr.derivationInfo.derivationPath.toString() ==
                      derivationInfo.derivationPath.toString(),
            )
            .length;

    final newAddresses = <BitcoinAddressRecord>[];

    final isHidden = getShouldHideAddress(derivationInfo.derivationPath);

    for (var i = startIndex; i < count + startIndex; i++) {
      final address = BitcoinAddressRecord(
        await getAddressAsync(
          derivationType: seedBytesType,
          isChange: isChange,
          index: i,
          addressType: addressType,
          derivationInfo: derivationInfo,
        ),
        index: i,
        isChange: isChange,
        isHidden: isHidden || isChange,
        type: addressType,
        network: network,
        derivationInfo: derivationInfo,
        seedBytesType: seedBytesType,
      );

      if (!allAddresses.any((addr) => addr.address == address.address)) {
        newAddresses.add(address);
      }
    }

    addAddresses(newAddresses);
    updateAddressesByType();
    updateHiddenAddresses();

    return newAddresses;
  }

  @action
  Future<void> generateInitialAddresses({
    required BitcoinAddressType addressType,
    required SeedBytesType seedBytesType,
    BitcoinDerivationInfo? bitcoinDerivationInfo,
  }) async {
    bitcoinDerivationInfo ??= BitcoinAddressUtils.getDerivationFromType(
      addressType,
      isElectrum: seedBytesType.isElectrum,
    );

    final existingAddresses = _allAddresses
        .where(
          (addr) =>
              addr.type == addressType &&
              addr.seedBytesType == seedBytesType &&
              addr.derivationInfo == bitcoinDerivationInfo,
        )
        .toList();

    if (existingAddresses.where((addr) => !addr.isChange).length < defaultReceiveAddressesCount) {
      await discoverNewAddresses(
        seedBytesType: seedBytesType,
        isChange: false,
        addressType: addressType,
        derivationInfo: bitcoinDerivationInfo,
      );
    }

    if (existingAddresses.where((addr) => addr.isChange).length < defaultChangeAddressesCount) {
      await discoverNewAddresses(
        seedBytesType: seedBytesType,
        isChange: true,
        addressType: addressType,
        derivationInfo: bitcoinDerivationInfo,
      );
    }
  }

  @action
  void updateAddresses(Iterable<BitcoinAddressRecord> newAddresses) {
    final replacedAddresses = newAddresses.toList();
    for (final address in newAddresses) {
      final index = _allAddresses.indexWhere((element) => element.address == address.address);
      if (index >= 0) {
        _allAddresses.replaceRange(index, index + 1, [address]);
        replacedAddresses.remove(address);
      }
    }

    if (replacedAddresses.isNotEmpty) {
      _allAddresses.addAll(replacedAddresses);
    } else {
      updateAddressesByType();
    }
  }

  @action
  void addAddresses(Iterable<BitcoinAddressRecord> addresses) {
    this._allAddresses.addAll(addresses);

    updateHiddenAddresses();
    updateAddressesByType();
  }

  @action
  void updateHiddenAddresses() {
    hiddenAddresses.clear();
    hiddenAddresses.addAll(_allAddresses
        .where((addressRecord) => !getIsReceive(addressRecord))
        .map((addressRecord) => addressRecord.address));
  }

  @action
  Future<void> setAddressType(BitcoinAddressType type) async {
    addressPageType = type;
    updateAddressesByType();
    walletInfo.addressPageType = addressPageType.toString();
    await walletInfo.save();
  }

  bool _isAddressByType(BitcoinAddressRecord addr, BitcoinAddressType type) => addr.type == type;

  bool isUnusedReceiveAddress(BaseBitcoinAddressRecord addr) {
    return !addr.isChange && !getIsUsed(addr);
  }

  Map<String, dynamic> toJson() => {
        'allAddresses': _allAddresses.map((address) => address.toJSON()).toList(),
        'addressPageType': addressPageType.toString(),
        // 'receiveAddressIndexByType': receiveAddressIndexByType,
        // 'changeAddressIndexByType': changeAddressIndexByType,
      };

  static Map<String, dynamic> fromSnapshot(Map<dynamic, dynamic> data) {
    final addressesTmp = data['addresses'] as List? ?? <Object>[];
    final addresses = addressesTmp
        .whereType<String>()
        .map((addr) => BitcoinAddressRecord.fromJSON(addr))
        .toList();

    var receiveAddressIndexByType = {SegwitAddressType.p2wpkh.toString(): 0};
    var changeAddressIndexByType = {SegwitAddressType.p2wpkh.toString(): 0};

    try {
      receiveAddressIndexByType = {
        SegwitAddressType.p2wpkh.toString(): int.parse(data['account_index'] as String? ?? '0')
      };
      changeAddressIndexByType = {
        SegwitAddressType.p2wpkh.toString():
            int.parse(data['change_address_index'] as String? ?? '0')
      };
    } catch (_) {
      try {
        receiveAddressIndexByType = data["account_index"] as Map<String, int>? ?? {};
        changeAddressIndexByType = data["change_address_index"] as Map<String, int>? ?? {};
      } catch (_) {}
    }

    return {
      'allAddresses': addresses,
      'addressPageType': data['address_page_type'] as String?,
      'receiveAddressIndexByType': receiveAddressIndexByType,
      'changeAddressIndexByType': changeAddressIndexByType,
    };
  }

  static ElectrumWalletAddressesBase fromJson(
    Map<String, dynamic> json,
    WalletInfo walletInfo, {
    required Map<SeedBytesType, Bip32Slip10Secp256k1> hdWallets,
    required BasedUtxoNetwork network,
    required bool isHardwareWallet,
    List<BitcoinAddressRecord>? initialAddresses,
    List<BitcoinSilentPaymentAddressRecord>? initialSilentAddresses,
    List<BitcoinReceivedSPAddressRecord>? initialReceivedSPAddresses,
  }) {
    initialAddresses ??= (json['allAddresses'] as List)
        .map((record) => BitcoinAddressRecord.fromJSON(record as String))
        .toList();

    return ElectrumWalletAddresses(
      walletInfo,
      hdWallets: hdWallets,
      network: network,
      isHardwareWallet: isHardwareWallet,
      initialAddresses: initialAddresses,
    );
  }

  bool getIsUsed(BaseBitcoinAddressRecord addr) {
    return addr.isUsed || addr.txCount != 0 || addr.balance != 0;
  }

  bool getIsReceive(BaseBitcoinAddressRecord addr) {
    return !getIsUsed(addr) && !addr.isChange && !addr.isHidden;
  }

  Future<List<BitcoinAddressRecord>> updateAddressesByGapAfterUse(
    List<BitcoinAddressRecord> addresses,
  ) async {
    final newAddresses = <BitcoinAddressRecord>[];
    final discoveredAddresses =
        <SeedBytesType, Map<BitcoinAddressType, Map<BitcoinDerivationType, List<bool>>>>{};

    final usedAddresses =
        addresses.isNotEmpty ? addresses : _allAddresses.where(getIsUsed).toList();

    for (final usedAddress in usedAddresses) {
      final isChange = usedAddress.isChange;

      final alreadyDiscoveredSeedType = discoveredAddresses[usedAddress.seedBytesType!];
      final alreadyDiscoveredAddressType = alreadyDiscoveredSeedType?[usedAddress.type];
      final alreadyDiscoveredDerivationType =
          alreadyDiscoveredAddressType?[usedAddress.derivationInfo.derivationType];
      final isAlreadyDiscovered = alreadyDiscoveredDerivationType?.contains(isChange) ?? false;

      if (isAlreadyDiscovered) {
        continue;
      }

      final matchingAddressList = allAddresses.where(
        (addr) =>
            addr.seedBytesType! == usedAddress.seedBytesType! &&
            addr.type == usedAddress.type &&
            addr.derivationInfo.derivationType == usedAddress.derivationInfo.derivationType &&
            addr.isChange == isChange,
      );
      final totalMatchingAddresses = matchingAddressList.length;

      final matchingGapLimit =
          (isChange ? defaultChangeAddressesCount : defaultReceiveAddressesCount);
      final isAddressUsedAboveGap = usedAddress.index >= totalMatchingAddresses - matchingGapLimit;

      if (isAddressUsedAboveGap) {
        discoveredAddresses.putIfAbsent(usedAddress.seedBytesType!, () => {});
        discoveredAddresses[usedAddress.seedBytesType!]!.putIfAbsent(usedAddress.type, () => {});
        discoveredAddresses[usedAddress.seedBytesType!]![usedAddress.type]!
            .putIfAbsent(usedAddress.derivationInfo.derivationType, () => []);
        discoveredAddresses[usedAddress.seedBytesType!]![usedAddress.type]![
                usedAddress.derivationInfo.derivationType]!
            .add(isChange);

        final theseAddresses = await discoverNewAddresses(
          isChange: isChange,
          seedBytesType: usedAddress.seedBytesType!,
          addressType: usedAddress.type,
          derivationInfo: usedAddress.derivationInfo,
        );
        newAddresses.addAll(theseAddresses);

        final newMatchingAddressList = allAddresses.where(
          (addr) =>
              addr.seedBytesType == usedAddress.seedBytesType! &&
              addr.type == usedAddress.type &&
              addr.derivationInfo.derivationType == usedAddress.derivationInfo.derivationType &&
              addr.isChange == isChange,
        );
        printV(
            "discovered ${theseAddresses.length} new ${isChange ? "change" : "receive"} addresses");
        printV(
            "Of type ${usedAddress.type} and derivation type ${usedAddress.seedBytesType!}, new total: ${newMatchingAddressList.length}");
      }
    }

    updateAddressesByType();
    updateHiddenAddresses();

    return newAddresses;
  }

  bool getShouldHideAddress(Bip32Path path) {
    if (seedTypeIsElectrum) {
      return path.toString() != BitcoinDerivationInfos.ELECTRUM.derivationPath.toString();
    }

    return path.toString() != BitcoinDerivationInfos.BIP84.derivationPath.toString();
  }
}
