import 'package:intl/intl.dart';
import 'package:cw_core/crypto_amount_format.dart';

const decredAmountLength = 8;
const decredAmountDivider = 100000000;
final decredAmountFormat = NumberFormat()
  ..maximumFractionDigits = decredAmountLength
  ..minimumFractionDigits = 1;

String decredAmountToString({required int amount}) =>
    decredAmountFormat.format(cryptoAmountToDouble(amount: amount, divider: decredAmountDivider));

double decredAmountToDouble({required int amount}) =>
    cryptoAmountToDouble(amount: amount, divider: decredAmountDivider);

int stringDoubleToDecredAmount(String amount) {
  int result = 0;

  try {
    result = (double.parse(amount) * decredAmountDivider).round();
  } catch (e) {
    result = 0;
  }

  return result;
}
