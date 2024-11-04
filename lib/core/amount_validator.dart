import 'package:cake_wallet/core/validator.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';

class AmountValidator extends TextValidator {
  AmountValidator({
    required CryptoCurrency currency,
    bool isAutovalidate = false,
    String? minValue,
    String? maxValue,
  }) {
    symbolsAmountValidator =
        SymbolsAmountValidator(isAutovalidate: isAutovalidate);
    decimalAmountValidator = DecimalAmountValidator(currency: currency,isAutovalidate: isAutovalidate);

    amountMinValidator = AmountMinValidator(
      minValue: minValue,
      isAutovalidate: isAutovalidate,
    );

    amountMaxValidator = AmountMaxValidator(
      maxValue: maxValue,
      isAutovalidate: isAutovalidate,
    );
  }

  late final AmountMinValidator amountMinValidator;

  late final AmountMaxValidator amountMaxValidator;

  late final SymbolsAmountValidator symbolsAmountValidator;

  late final DecimalAmountValidator decimalAmountValidator;

  String? call(String? value) {
    if (value == null || value.isEmpty) {
      return S.current.error_text_amount;
    }

    //* Validate for Text(length, symbols, decimals etc)

    final textValidation = symbolsAmountValidator(value) ?? decimalAmountValidator(value);

    //* Validate for Comparison(Value greater than min and less than )
    final comparisonValidation = amountMinValidator(value) ?? amountMaxValidator(value);

    return textValidation ?? comparisonValidation;
  }
}

class SymbolsAmountValidator extends TextValidator {
  SymbolsAmountValidator({required bool isAutovalidate})
      : super(
      errorMessage: S.current.error_text_amount,
      pattern: _pattern(),
      isAutovalidate: isAutovalidate,
      minLength: 0,
      maxLength: 0);

  static String _pattern() => '^([0-9]+([.\,][0-9]+)?|[.\,][0-9]+)\$';
}

class DecimalAmountValidator extends TextValidator {
  DecimalAmountValidator({required Currency currency, required bool isAutovalidate })
      : super(
            errorMessage: S.current.decimal_places_error,
            pattern: _pattern(currency),
            isAutovalidate: isAutovalidate,
            minLength: 0,
            maxLength: 0);

  static String _pattern(Currency currency) {
    switch (currency) {
      case CryptoCurrency.xmr:
        return '^([0-9]+([.\,][0-9]{1,12})?|[.\,][0-9]{1,12})\$';
      case CryptoCurrency.btc:
        return '^([0-9]+([.\,][0-9]{1,8})?|[.\,][0-9]{1,8})\$';
      default:
        return '^([0-9]+([.\,][0-9]{1,12})?|[.\,][0-9]{1,12})\$';
    }
  }
}

class AllAmountValidator extends TextValidator {
  AllAmountValidator()
      : super(
            errorMessage: S.current.error_text_amount,
            pattern: S.current.all,
            minLength: 0,
            maxLength: 0);
}

class AmountMinValidator extends Validator<String> {
  final String? minValue;
  final bool isAutovalidate;

  AmountMinValidator({
    this.minValue,
    required this.isAutovalidate,
  }) : super(errorMessage: S.current.error_text_input_below_minimum_limit);

  @override
  bool isValid(String? value) {
    if (value == null || value.isEmpty) {
      return isAutovalidate ? true : false;
    }

    if (minValue == null || minValue == "null") {
      return true;
    }

    final valueInDouble = parseToDouble(value);
    final minInDouble = parseToDouble(minValue ?? '');

    if (valueInDouble == null || minInDouble == null) {
      return false;
    }

    return valueInDouble >= minInDouble;
  }

  double? parseToDouble(String value) {
    final data = double.tryParse(value.replaceAll(',', '.'));
    return data;
  }
}

class AmountMaxValidator extends Validator<String> {
  final String? maxValue;
  final bool isAutovalidate;

  AmountMaxValidator({
    this.maxValue,
    required this.isAutovalidate,
  }) : super(errorMessage: S.current.error_text_input_above_maximum_limit);

  @override
  bool isValid(String? value) {
    if (value == null || value.isEmpty) {
      return isAutovalidate ? true : false;
    }

    if (maxValue == null || maxValue == "null") {
      return true;
    }

    final valueInDouble = parseToDouble(value);
    final maxInDouble = parseToDouble(maxValue ?? '');

    if (valueInDouble == null || maxInDouble == null) {
      return false;
    }
    return valueInDouble < maxInDouble;
  }

  double? parseToDouble(String value) {
    return double.tryParse(value.replaceAll(',', '.'));
  }
}
