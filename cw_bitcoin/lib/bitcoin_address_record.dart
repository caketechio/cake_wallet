import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/seedbyte_types.dart';
import 'package:cw_core/wallet_info.dart';

abstract class BaseBitcoinAddressRecord {
  BaseBitcoinAddressRecord(
    this.address, {
    required this.index,
    bool isChange = false,
    int txCount = 0,
    int balance = 0,
    String name = '',
    bool isUsed = false,
    required this.type,
    this.seedBytesType,
    bool? isHidden,
  })  : _txCount = txCount,
        _balance = balance,
        _name = name,
        _isUsed = isUsed,
        isHidden = isHidden ?? isChange,
        _isChange = isChange;

  @override
  bool operator ==(Object o) => o is BaseBitcoinAddressRecord && address == o.address;

  final String address;
  bool isHidden;

  final bool _isChange;

  bool get isChange => _isChange;
  final int index;
  int _txCount;
  int _balance;
  String _name;
  bool _isUsed;

  int get txCount => _txCount;

  String get name => _name;

  int get balance => _balance;

  set txCount(int value) => _txCount = value;

  set balance(int value) => _balance = value;

  bool get isUsed => _isUsed;

  void setAsUsed() {
    _isUsed = true;
    isHidden = true;
  }

  void setNewName(String label) => _name = label;

  int get hashCode => address.hashCode;

  BitcoinAddressType type;

  final SeedBytesType? seedBytesType;

  String get derivationPath => '';

  String toJSON() => json.encode({
        'address': address,
        'index': index,
        'isHidden': isHidden,
        'isChange': isChange,
        'isUsed': isUsed,
        'txCount': txCount,
        'name': name,
        'balance': balance,
        'type': type.toString(),
        'runtimeType': runtimeType.toString(),
        'seedBytesType': seedBytesType?.value,
        'derivationPath': derivationPath,
      });

  static BaseBitcoinAddressRecord fromJSON(
    String jsonSource, [
    DerivationInfo? derivationInfo,
    BasedUtxoNetwork? network,
  ]) {
    final decoded = json.decode(jsonSource) as Map;

    if (decoded['runtimeType'] == 'BitcoinAddressRecord') {
      return BitcoinAddressRecord.fromJSON(jsonSource, derivationInfo, network);
    } else if (decoded['runtimeType'] == 'BitcoinSilentPaymentAddressRecord') {
      return BitcoinSilentPaymentAddressRecord.fromJSON(jsonSource);
    } else if (decoded['runtimeType'] == 'BitcoinReceivedSPAddressRecord') {
      return BitcoinReceivedSPAddressRecord.fromJSON(jsonSource);
    } else if (decoded['runtimeType'] == 'LitecoinMWEBAddressRecord') {
      return LitecoinMWEBAddressRecord.fromJSON(jsonSource);
    } else {
      return BitcoinAddressRecord.fromJSON(jsonSource, derivationInfo, network);
    }
  }
}

class BitcoinAddressRecord extends BaseBitcoinAddressRecord {
  final BitcoinDerivationInfo derivationInfo;

  String _derivationPath = '';

  @override
  String get derivationPath => _derivationPath;

  BitcoinAddressRecord(
    super.address, {
    required super.index,
    required this.derivationInfo,
    super.seedBytesType,
    super.isHidden,
    required super.isChange,
    super.txCount = 0,
    super.balance = 0,
    super.name = '',
    super.isUsed = false,
    required super.type,
    String? scriptHash,
    BasedUtxoNetwork? network,
    String? derivationPath,
  }) {
    if (scriptHash != null) {
      this.scriptHash = scriptHash;
    } else if (network != null) {
      this.scriptHash = BitcoinAddressUtils.scriptHash(address, network: network);
    } else {
      throw ArgumentError('either scriptHash or network must be provided');
    }

    if (derivationPath == null)
      _derivationPath = derivationInfo.derivationPath
          .addElem(Bip32KeyIndex(isChange ? 1 : 0))
          .addElem(Bip32KeyIndex(index))
          .toString();
    else
      _derivationPath = derivationPath;
  }

  factory BitcoinAddressRecord.fromJSON(
    String jsonSource, [
    DerivationInfo? derivationInfo,
    BasedUtxoNetwork? network,
  ]) {
    final decoded = json.decode(jsonSource) as Map;
    final derivationInfoSnp = decoded['derivationInfo'] as Map<String, dynamic>?;
    final seedBytesTypeSnp = decoded['seedBytesType'] as String?;
    final seedBytesType = seedBytesTypeSnp == null
        ? derivationInfo!.derivationType == DerivationType.bip39
            ? SeedBytesType.old_bip39
            : SeedBytesType.old_electrum
        : SeedBytesType.fromValue(seedBytesTypeSnp.toString());

    return BitcoinAddressRecord(
      decoded['address'] as String,
      index: decoded['index'] as int,
      derivationInfo: derivationInfoSnp == null
          ? !seedBytesType.isElectrum
              ? BitcoinDerivationInfo.fromDerivationAndAddress(
                  BitcoinDerivationType.bip39,
                  decoded['address'] as String,
                  network!,
                )
              : BitcoinDerivationInfos.ELECTRUM
          : BitcoinDerivationInfo.fromJSON(derivationInfoSnp),
      seedBytesType: seedBytesType,
      isHidden: decoded['isHidden'] as bool? ?? false,
      isChange: decoded['isChange'] as bool? ?? false,
      isUsed: decoded['isUsed'] as bool? ?? false,
      txCount: decoded['txCount'] as int? ?? 0,
      name: decoded['name'] as String? ?? '',
      balance: decoded['balance'] as int? ?? 0,
      type: decoded['type'] != null && decoded['type'] != ''
          ? BitcoinAddressType.values
              .firstWhere((type) => type.toString() == decoded['type'] as String)
          : SegwitAddressType.p2wpkh,
      scriptHash: decoded['scriptHash'] as String?,
    );
  }

  late String scriptHash;

  @override
  String toJSON() {
    final m = json.decode(super.toJSON()) as Map<String, dynamic>;
    m['derivationInfo'] = derivationInfo.toJSON();
    m['scriptHash'] = scriptHash;
    return json.encode(m);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BitcoinAddressRecord &&
        other.address == address &&
        other.index == index &&
        other.derivationInfo == derivationInfo &&
        other.scriptHash == scriptHash &&
        other.type == type &&
        other.seedBytesType == seedBytesType;
  }

  @override
  int get hashCode =>
      address.hashCode ^
      index.hashCode ^
      derivationInfo.hashCode ^
      scriptHash.hashCode ^
      type.hashCode ^
      seedBytesType.hashCode;
}

class BitcoinSilentPaymentAddressRecord extends BaseBitcoinAddressRecord {
  String _derivationPath;

  @override
  String get derivationPath => _derivationPath;

  int get labelIndex => index;
  final String? labelHex;

  static bool isPrimaryAddress(int labelIndex) => labelIndex == 0;

  BitcoinSilentPaymentAddressRecord(
    super.address, {
    required int labelIndex,
    String derivationPath = BitcoinDerivationPaths.SILENT_PAYMENTS_SPEND,
    super.txCount = 0,
    super.balance = 0,
    super.name = '',
    super.isUsed = false,
    super.type = SilentPaymentsAddresType.p2sp,
    required super.isChange,
    super.seedBytesType,
    super.isHidden,
    this.labelHex,
  })  : _derivationPath = derivationPath,
        super(index: labelIndex) {
    if (labelIndex != 0 && labelHex == null) {
      throw ArgumentError('label must be provided for silent address index != 1');
    }

    if (labelIndex != 0) {
      _derivationPath = _derivationPath.replaceAll(RegExp(r'\d\/?$'), '$labelIndex');
    }
  }

  factory BitcoinSilentPaymentAddressRecord.fromJSON(String jsonSource) {
    final decoded = json.decode(jsonSource) as Map;

    return BitcoinSilentPaymentAddressRecord(
      decoded['address'] as String,
      derivationPath:
          (decoded['derivationPath'] as String?) ?? BitcoinWalletAddressesBase.OLD_SP_PATH,
      labelIndex: decoded['index'] as int,
      isUsed: decoded['isUsed'] as bool? ?? false,
      txCount: decoded['txCount'] as int? ?? 0,
      name: decoded['name'] as String? ?? '',
      balance: decoded['balance'] as int? ?? 0,
      labelHex: decoded['labelHex'] as String?,
      isChange: decoded['isChange'] as bool? ?? false,
      isHidden: decoded['isHidden'] as bool?,
      seedBytesType: SeedBytesType.fromValue(decoded['seedBytesType'] as String),
    );
  }

  @override
  String toJSON() {
    final m = json.decode(super.toJSON()) as Map<String, dynamic>;
    m['index'] = labelIndex;
    m['labelHex'] = labelHex;
    return json.encode(m);
  }
}

class BitcoinReceivedSPAddressRecord extends BitcoinSilentPaymentAddressRecord {
  final String tweak;
  final String spAddress;

  @override
  String get derivationPath => '';

  BitcoinReceivedSPAddressRecord(
    super.address, {
    required super.labelIndex,
    super.txCount = 0,
    super.balance = 0,
    super.name = '',
    super.isUsed = false,
    required this.tweak,
    required this.spAddress,
    required super.isChange,
    super.seedBytesType,
    super.labelHex,
  }) : super(isHidden: true, type: SegwitAddressType.p2tr);

  SilentPaymentOwner getSPWallet(
    List<SilentPaymentOwner> silentPaymentsWallets, [
    BasedUtxoNetwork network = BitcoinNetwork.mainnet,
  ]) {
    return silentPaymentsWallets.firstWhere(
      (wallet) => wallet.toAddress(network) == spAddress,
      orElse: () => throw ArgumentError('SP wallet not found'),
    );
  }

  ECPrivate getSpendKey(
    List<SilentPaymentOwner> silentPaymentsWallets, [
    BasedUtxoNetwork network = BitcoinNetwork.mainnet,
  ]) {
    return getSPWallet(silentPaymentsWallets, network)
        .b_spend
        .tweakAdd(BigintUtils.fromBytes(BytesUtils.fromHexString(tweak)));
  }

  factory BitcoinReceivedSPAddressRecord.fromJSON(String jsonSource) {
    final decoded = json.decode(jsonSource) as Map;

    return BitcoinReceivedSPAddressRecord(
      decoded['address'] as String,
      labelIndex: decoded['index'] as int? ?? 1,
      isUsed: decoded['isUsed'] as bool? ?? false,
      txCount: decoded['txCount'] as int? ?? 0,
      name: decoded['name'] as String? ?? '',
      balance: decoded['balance'] as int? ?? 0,
      labelHex: decoded['label'] as String?,
      tweak: decoded['tweak'] as String? ?? decoded['silent_payment_tweak'] as String? ?? '',
      isChange: decoded['isChange'] as bool? ?? false,
      spAddress: decoded['spAddress'] as String? ?? '',
      seedBytesType: (decoded['seedBytesType'] as String?) == null
          ? null
          : SeedBytesType.fromValue(decoded['seedBytesType'] as String),
    );
  }

  @override
  String toJSON() {
    final m = json.decode(super.toJSON()) as Map<String, dynamic>;
    m['tweak'] = tweak;
    m['spAddress'] = spAddress;
    return json.encode(m);
  }
}

class LitecoinMWEBAddressRecord extends BaseBitcoinAddressRecord {
  String _derivationPath = '';

  @override
  String get derivationPath => _derivationPath;

  LitecoinMWEBAddressRecord(
    super.address, {
    required super.index,
    super.seedBytesType,
    super.isHidden,
    super.isChange = false,
    super.txCount = 0,
    super.balance = 0,
    super.name = '',
    super.isUsed = false,
    BasedUtxoNetwork? network,
  }) : super(type: SegwitAddressType.mweb) {
    var mwebPath = BitcoinDerivationInfos.LITECOIN_MWEB.derivationPath;

    _derivationPath = mwebPath.addElem(Bip32KeyIndex(index)).toString();
  }

  factory LitecoinMWEBAddressRecord.fromJSON(String jsonSource) {
    final decoded = json.decode(jsonSource) as Map;

    return LitecoinMWEBAddressRecord(
      decoded['address'] as String,
      index: decoded['index'] as int,
      isHidden: decoded['isHidden'] as bool? ?? false,
      isChange: decoded['isChange'] as bool? ?? false,
      isUsed: decoded['isUsed'] as bool? ?? false,
      txCount: decoded['txCount'] as int? ?? 0,
      name: decoded['name'] as String? ?? '',
      balance: decoded['balance'] as int? ?? 0,
      seedBytesType: (decoded['seedBytesType'] as String?) == null
          ? null
          : SeedBytesType.fromValue(decoded['seedBytesType'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BitcoinAddressRecord &&
        other.address == address &&
        other.index == index &&
        other.type == type;
  }

  @override
  int get hashCode => address.hashCode ^ index.hashCode ^ type.hashCode;
}
