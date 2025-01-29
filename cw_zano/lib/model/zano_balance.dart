import 'package:cw_core/balance.dart';
import 'package:cw_zano/zano_formatter.dart';

class ZanoBalance extends Balance {
  final BigInt total;
  final BigInt unlocked;
  final int decimalPoint;
  ZanoBalance({required this.total, required this.unlocked, this.decimalPoint = ZanoFormatter.defaultDecimalPoint}) : super(unlocked.isValidInt ? unlocked.toInt() : 0, (total - unlocked).isValidInt ? (total - unlocked).toInt() : 0);

  ZanoBalance.empty({this.decimalPoint = ZanoFormatter.defaultDecimalPoint}): total = BigInt.zero, unlocked = BigInt.zero, super(0, 0);

  @override
  String get formattedAdditionalBalance => ZanoFormatter.bigIntAmountToString(total - unlocked, decimalPoint);

  @override
  String get formattedAvailableBalance => ZanoFormatter.bigIntAmountToString(unlocked, decimalPoint);
}
