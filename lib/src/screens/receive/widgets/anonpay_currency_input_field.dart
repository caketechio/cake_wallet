import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cw_core/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';

class AnonpayCurrencyInputField extends StatelessWidget {
  const AnonpayCurrencyInputField({
    super.key,
    this.onTapPicker,
    required this.selectedCurrency,
    required this.focusNode,
    required this.controller,
    required this.minAmount,
    required this.maxAmount,
  });
  final Function()? onTapPicker;
  final Currency selectedCurrency;
  final FocusNode focusNode;
  final TextEditingController controller;
  final String minAmount;
  final String maxAmount;
  @override
  Widget build(BuildContext context) {
    bool hasDecimals = selectedCurrency.name.toLowerCase() != "sats";
    final arrowBottomPurple = Image.asset(
      'assets/images/arrow_bottom_purple_icon.png',
      color: Colors.white,
      height: 8,
    );
    return Column(
      children: [
        Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context)
                          .extension<ExchangePageTheme>()!
                          .textFieldBorderBottomPanelColor,
                      width: 1)),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  if (onTapPicker != null)
                    Container(
                      padding: EdgeInsets.only(right: 8),
                      height: 32,
                      child: InkWell(
                        onTap: onTapPicker,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.only(right: 5),
                                child: arrowBottomPurple,
                              ),
                              Text(selectedCurrency.name.toUpperCase(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.white))
                            ]),
                      ),
                    )
                  else
                    Text(selectedCurrency.name.toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                  selectedCurrency.tag != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 3.0),
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .extension<SendPageTheme>()!
                                    .textFieldButtonColor,
                                borderRadius: BorderRadius.all(Radius.circular(6))),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Text(
                                  selectedCurrency.tag!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .extension<SendPageTheme>()!
                                        .textFieldButtonIconColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Container(),
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Text(':',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: BaseTextFormField(
                            focusNode: focusNode,
                            controller: controller,
                            textInputAction: TextInputAction.next,
                            enabled: true,
                            textAlign: TextAlign.left,
                            keyboardType: TextInputType.numberWithOptions(
                                signed: false, decimal: hasDecimals),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp('[\\-|\\ ]')),
                              if (!hasDecimals) FilteringTextInputFormatter.deny(RegExp('[\.,]')),
                            ],
                            hintText: hasDecimals ? '0.0000' : '0',
                            borderColor: Colors.transparent,
                            textStyle: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            placeholderTextStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                            ),
                            validator: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
        Container(
          height: 15,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (minAmount.isNotEmpty) ...[
                Text(
                  S.of(context).min_value(minAmount, selectedCurrency.toString()),
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor),
                ),
              ],
              SizedBox(width: 10),
              if (maxAmount.isNotEmpty) ...[
                Text(S.of(context).max_value(maxAmount, selectedCurrency.toString()),
                    style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor))
              ],
            ],
          ),
        )
      ],
    );
  }
}
