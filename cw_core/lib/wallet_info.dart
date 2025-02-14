import 'dart:async';

import 'package:cw_core/address_info.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hive/hive.dart';

part 'wallet_info.g.dart';

@HiveType(typeId: DERIVATION_TYPE_TYPE_ID)
enum DerivationType {
  @HiveField(0)
  unknown,
  @HiveField(1)
  def, // default is a reserved word
  @HiveField(2)
  nano,
  @HiveField(3)
  bip39,
  @HiveField(4)
  electrum,
}

@HiveType(typeId: HARDWARE_WALLET_TYPE_TYPE_ID)
enum HardwareWalletType {
  @HiveField(0)
  ledger,
  @HiveField(1)
  keystone,
}

@HiveType(typeId: DerivationInfo.typeId)
class DerivationInfo extends HiveObject {
  DerivationInfo({
    this.derivationType,
    this.derivationPath,
    this.balance = "",
    this.address = "",
    this.transactionsCount = 0,
    this.scriptType,
    this.description,
  });

  static const typeId = DERIVATION_INFO_TYPE_ID;

  @HiveField(0, defaultValue: '')
  String address;

  @HiveField(1, defaultValue: '')
  String balance;

  @HiveField(2, defaultValue: 0)
  int transactionsCount;

  @HiveField(3)
  DerivationType? derivationType;

  @HiveField(4)
  String? derivationPath;

  @HiveField(5)
  final String? scriptType;

  @HiveField(6)
  final String? description;
}

@HiveType(typeId: WalletInfo.typeId)
class WalletInfo extends HiveObject {
  WalletInfo(
    this.id,
    this.name,
    this.type,
    this.isRecovery,
    this.restoreHeight,
    this.timestamp,
    this.dirPath,
    this.path,
    this.address,
    this.yatEid,
    this.yatLastUsedAddressRaw,
    this.showIntroCakePayCard,
    this.derivationInfo,
    this.hardwareWalletType,
    this.parentAddress,
  ) : _yatLastUsedAddressController = StreamController<String>.broadcast();

  factory WalletInfo.external({
    required String id,
    required String name,
    required WalletType type,
    required bool isRecovery,
    required int restoreHeight,
    required DateTime date,
    required String dirPath,
    required String path,
    required String address,
    bool? showIntroCakePayCard,
    String yatEid = '',
    String yatLastUsedAddressRaw = '',
    DerivationInfo? derivationInfo,
    HardwareWalletType? hardwareWalletType,
    String? parentAddress,
  }) {
    return WalletInfo(
      id,
      name,
      type,
      isRecovery,
      restoreHeight,
      date.millisecondsSinceEpoch,
      dirPath,
      path,
      address,
      yatEid,
      yatLastUsedAddressRaw,
      showIntroCakePayCard,
      derivationInfo,
      hardwareWalletType,
      parentAddress,
    );
  }

  static const typeId = WALLET_INFO_TYPE_ID;
  static const boxName = 'WalletInfo';

  @HiveField(0, defaultValue: '')
  String id;

  @HiveField(1, defaultValue: '')
  String name;

  @HiveField(2)
  WalletType type;

  @HiveField(3, defaultValue: false)
  bool isRecovery;

  @HiveField(4, defaultValue: 0)
  int restoreHeight;

  @HiveField(5, defaultValue: 0)
  int timestamp;

  @HiveField(6, defaultValue: '')
  String dirPath;

  @HiveField(7, defaultValue: '')
  String path;

  @HiveField(8, defaultValue: '')
  String address;

  @HiveField(10)
  Map<String, String>? addresses;

  @HiveField(11)
  String? yatEid;

  @HiveField(12)
  String? yatLastUsedAddressRaw;

  @HiveField(13)
  bool? showIntroCakePayCard;

  @HiveField(14)
  Map<int, List<AddressInfo>>? addressInfos;

  @HiveField(15)
  List<String>? usedAddresses;

  @deprecated
  @HiveField(16)
  DerivationType? derivationType; // no longer used

  @deprecated
  @HiveField(17)
  String? derivationPath; // no longer used

  @HiveField(18)
  String? addressPageType;

  @HiveField(19)
  String? network;

  @HiveField(20)
  DerivationInfo? derivationInfo;

  @HiveField(21)
  HardwareWalletType? hardwareWalletType;

  @HiveField(22)
  String? parentAddress;
  
  @HiveField(23)
  List<String>? hiddenAddresses;

  @HiveField(24)
  List<String>? manualAddresses;

  


  String get yatLastUsedAddress => yatLastUsedAddressRaw ?? '';

  set yatLastUsedAddress(String address) {
    yatLastUsedAddressRaw = address;
    _yatLastUsedAddressController.add(address);
  }

  String get yatEmojiId => yatEid ?? '';

  bool get isShowIntroCakePayCard {
    if (showIntroCakePayCard == null) {
      return type != WalletType.haven;
    }
    return showIntroCakePayCard!;
  }

  bool get isHardwareWallet => hardwareWalletType != null;

  bool get isConnectableHardwareWallet => isLedger;

  bool get isLedger => hardwareWalletType == HardwareWalletType.ledger;

  bool get isKeystone => hardwareWalletType == HardwareWalletType.keystone;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(timestamp);

  Stream<String> get yatLastUsedAddressStream => _yatLastUsedAddressController.stream;

  StreamController<String> _yatLastUsedAddressController;

  Future<void> updateRestoreHeight(int height) async {
    restoreHeight = height;
    await save();
  }
}
