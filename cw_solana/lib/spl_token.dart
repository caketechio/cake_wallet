import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'spl_token.g.dart';

@HiveType(typeId: SPLToken.typeId)
class SPLToken extends CryptoCurrency with HiveObjectMixin {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String symbol;

  @HiveField(2)
  final String mintAddress;

  @HiveField(3)
  final int decimal;

  @HiveField(4, defaultValue: true)
  bool _enabled;

  @HiveField(5)
  final String mint;

  @HiveField(6)
  final String? iconPath;

  @HiveField(7)
  final String? tag;

  SPLToken({
    required this.name,
    required this.symbol,
    required this.mintAddress,
    required this.decimal,
    required this.mint,
    this.iconPath,
    this.tag = 'SOL',
    bool enabled = true,
  })  : _enabled = enabled,
        super(
          name: mint.toLowerCase(),
          title: symbol.toUpperCase(),
          fullName: name,
          tag: tag,
          iconPath: iconPath,
          decimals: decimal,
        );

  factory SPLToken.fromMetadata({
    required String name,
    required String mint,
    required String symbol,
    required String mintAddress,
    String? iconPath,
  }) {
    return SPLToken(
      name: name,
      symbol: symbol,
      mintAddress: mintAddress,
      decimal: 0,
      mint: mint,
      iconPath: iconPath,
    );
  }

  factory SPLToken.cryptoCurrency({
    required String name,
    required String symbol,
    required int decimals,
    required String iconPath,
    required String mint,
  }) {
    return SPLToken(
      name: name,
      symbol: symbol,
      decimal: decimals,
      mint: mint,
      iconPath: iconPath,
      mintAddress: '',
    );
  }

  bool get enabled => _enabled;

  set enabled(bool value) => _enabled = value;

  SPLToken.copyWith(SPLToken other, String? icon, String? tag)
      : name = other.name,
        symbol = other.symbol,
        mintAddress = other.mintAddress,
        decimal = other.decimal,
        _enabled = other.enabled,
        mint = other.mint,
        tag = other.tag,
        iconPath = icon,
        super(
          title: other.symbol.toUpperCase(),
          name: other.symbol.toLowerCase(),
          decimals: other.decimal,
          fullName: other.name,
          tag: other.tag,
          iconPath: icon,
        );

  static const typeId = SPL_TOKEN_TYPE_ID;
  static const boxName = 'SPLTokens';

  @override
  bool operator ==(other) =>
      (other is SPLToken && other.mintAddress == mintAddress) ||
      (other is CryptoCurrency && other.title == title);

  @override
  int get hashCode => mintAddress.hashCode;
}
