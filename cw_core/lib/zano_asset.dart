import 'dart:convert';

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'zano_asset.g.dart';

@HiveType(typeId: ZanoAsset.typeId)
class ZanoAsset extends CryptoCurrency with HiveObjectMixin {
  @HiveField(0)
  final String fullName;
  @HiveField(1)
  final String ticker;
  @HiveField(2)
  final String assetId;
  @HiveField(3)
  final int decimalPoint;
  @HiveField(4, defaultValue: true)
  bool _enabled;
  @HiveField(5)
  final String? iconPath;

  // @HiveField(6)
  // final String? tag;
  @HiveField(6)
  final String owner;
  @HiveField(7)
  final String metaInfo;
  @HiveField(8)
  final BigInt currentSupply;
  @HiveField(9)
  final bool hiddenSupply;
  @HiveField(10)
  final BigInt totalMaxSupply;
  @HiveField(11)
  final bool isInGlobalWhitelist;
  @HiveField(12, defaultValue: null)
  final Map<String, dynamic>? info;

  bool get enabled => _enabled;

  set enabled(bool value) => _enabled = value;

  ZanoAsset({
    this.fullName = '',
    this.ticker = '',
    required this.assetId,
    this.decimalPoint = 12,
    bool enabled = true,
    this.iconPath,
    this.owner = defaultOwner,
    this.metaInfo = '',
    required this.currentSupply,
    this.hiddenSupply = false,
    required this.totalMaxSupply,
    this.isInGlobalWhitelist = false,
    this.info,
  })  : _enabled = enabled,
        super(
          name: fullName,
          title: ticker.toUpperCase(),
          fullName: fullName,
          tag: 'ZANO',
          iconPath: iconPath,
          decimals: decimalPoint,
        );

  ZanoAsset.copyWith(ZanoAsset other, {String? assetId, bool enabled = true})
      : this.fullName = other.fullName,
        this.ticker = other.ticker,
        this.assetId = assetId ?? other.assetId,
        this.decimalPoint = other.decimalPoint,
        this._enabled = enabled && other.enabled,
        this.iconPath = other.iconPath,
        this.currentSupply = other.currentSupply,
        this.hiddenSupply = other.hiddenSupply,
        this.metaInfo = other.metaInfo,
        this.owner = other.owner,
        this.totalMaxSupply = other.totalMaxSupply,
        this.isInGlobalWhitelist = other.isInGlobalWhitelist,
        this.info = other.info,
        super(
          name: other.name,
          title: other.ticker.toUpperCase(),
          fullName: other.name,
          tag: 'ZANO',
          iconPath: other.iconPath,
          decimals: other.decimalPoint,
          enabled: enabled,
        );

  factory ZanoAsset.fromJson(Map<String, dynamic> json, {bool isInGlobalWhitelist = false}) {
    Map<String, dynamic>? info;
    try {
      info = jsonDecode((json['meta_info'] as String?) ?? '{}') as Map<String, dynamic>?;
    } catch (_) {}

    return ZanoAsset(
      assetId: json['asset_id'] as String? ?? '',
      currentSupply: bigIntFromDynamic(json['current_supply']),
      decimalPoint: json['decimal_point'] as int? ?? 12,
      fullName: json['full_name'] as String? ?? '',
      hiddenSupply: json['hidden_supply'] as bool? ?? false,
      metaInfo: json['meta_info'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      ticker: json['ticker'] as String? ?? '',
      iconPath: info?['logo_url'] as String? ?? '',
      totalMaxSupply: bigIntFromDynamic(json['total_max_supply']),
      isInGlobalWhitelist: isInGlobalWhitelist,
      info: info,
    );
  }

  static const typeId = ZANO_ASSET_TYPE_ID;
  static const zanoAssetsBoxName = 'zanoAssetsBox';
  static const defaultOwner = '0000000000000000000000000000000000000000000000000000000000000000';
}

BigInt bigIntFromDynamic(dynamic d) {
  if (d is int) {
    return BigInt.from(d);
  } else if (d is BigInt) {
    return d;
  } else if (d == null) {
    return BigInt.zero;
  } else {
    throw 'cannot cast value of type ${d.runtimeType} to BigInt';
    //return BigInt.zero;
  }
}
