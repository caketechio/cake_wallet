import 'dart:math';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_zano/zano_wallet_api.dart';
import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class ZanoFormatter {
  static const defaultDecimalPoint = 12;

  //static final numberFormat = NumberFormat()
  //  ..maximumFractionDigits = defaultDecimalPoint
  //  ..minimumFractionDigits = 1;

  static Decimal _bigIntDivision({required BigInt amount, required BigInt divider}) {
    return (Decimal.fromBigInt(amount) / Decimal.fromBigInt(divider)).toDecimal();
  }

  static String intAmountToString(int amount, [int decimalPoint = defaultDecimalPoint]) {
      final numberFormat = NumberFormat()..maximumFractionDigits = decimalPoint
                                         ..minimumFractionDigits = 1;
      return numberFormat.format(
        DecimalIntl(
          _bigIntDivision(
            amount: BigInt.from(amount),
            divider: BigInt.from(pow(10, decimalPoint)),
          ),
        ),
      )
      .replaceAll(',', '');
  }

  static String bigIntAmountToString(BigInt amount, [int decimalPoint = defaultDecimalPoint]) {
    if (decimalPoint == 0) {
      return '0';
    }
    final numberFormat = NumberFormat()..maximumFractionDigits = decimalPoint
                                        ..minimumFractionDigits = 1;
    return numberFormat.format(
        DecimalIntl(
          _bigIntDivision(
            amount: amount,
            divider: BigInt.from(pow(10, decimalPoint)),
          ),
        ),
      )
      .replaceAll(',', '');
  }

  static double intAmountToDouble(int amount, [int decimalPoint = defaultDecimalPoint]) => _bigIntDivision(
        amount: BigInt.from(amount),
        divider: BigInt.from(pow(10, decimalPoint)),
      ).toDouble();

  static int parseAmount(String amount, [int decimalPoint = defaultDecimalPoint]) {
    final resultBigInt = (Decimal.parse(amount) * Decimal.fromBigInt(BigInt.from(10).pow(decimalPoint))).toBigInt();
    if (!resultBigInt.isValidInt) {
      Fluttertoast.showToast(msg: 'Cannot transfer $amount. Maximum is ${intAmountToString(resultBigInt.toInt(), decimalPoint)}.');
    }
    return resultBigInt.toInt();
  }

  static BigInt bigIntFromDynamic(dynamic d) {
    if (d is int) {
      return BigInt.from(d);
    } else if (d is BigInt) {
      return d;
    } else if (d == null) {
      return BigInt.zero;
    } else {
      printV(('cannot cast value of type ${d.runtimeType} to BigInt'));
      throw 'cannot cast value of type ${d.runtimeType} to BigInt';
      //return BigInt.zero;
    }
  }
}
