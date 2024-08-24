import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/currency_picker.dart';
import 'package:cake_wallet/src/screens/receive/widgets/anonpay_currency_input_field.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/lightning_invoice_page_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class LightningInvoiceForm extends StatelessWidget {
  LightningInvoiceForm({
    super.key,
    required this.formKey,
    required this.lightningInvoicePageViewModel,
    required this.amountController,
    required this.descriptionController,
    required this.depositAmountFocus,
  }) : _descriptionFocusNode = FocusNode() {
    amountController.text = lightningInvoicePageViewModel.amount;
    descriptionController.text = lightningInvoicePageViewModel.description;
  }

  final TextEditingController amountController;
  final TextEditingController descriptionController;
  final LightningInvoicePageViewModel lightningInvoicePageViewModel;
  final FocusNode depositAmountFocus;
  final FocusNode _descriptionFocusNode;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              S.of(context).invoice_details,
              style: textMediumSemiBold(),
            ),
            Observer(builder: (_) {
              return AnonpayCurrencyInputField(
                controller: amountController,
                focusNode: depositAmountFocus,
                maxAmount: '',
                minAmount: lightningInvoicePageViewModel.minimumCurrency,
                selectedCurrency: lightningInvoicePageViewModel.selectedCurrency,
                onTapPicker: () => _presentPicker(context),
              );
            }),
            Observer(builder: (context) {
              if (lightningInvoicePageViewModel.selectedCurrency is FiatCurrency) {
                String satString =
                    "${lightning!.satsToLightningString(lightningInvoicePageViewModel.satAmount ?? 0)} sats";
                return BaseTextFormField(
                  enabled: false,
                  borderColor: Theme.of(context)
                      .extension<ExchangePageTheme>()!
                      .textFieldBorderTopPanelColor,
                  hintText: satString,
                  placeholderTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
                  ),
                );
              }
              return SizedBox();
            }),
            SizedBox(
              height: 24,
            ),
            BaseTextFormField(
              controller: descriptionController,
              focusNode: _descriptionFocusNode,
              textInputAction: TextInputAction.next,
              borderColor:
                  Theme.of(context).extension<ExchangePageTheme>()!.textFieldBorderTopPanelColor,
              suffixIcon: SizedBox(width: 36),
              hintText: S.of(context).optional_description,
              placeholderTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).extension<ExchangePageTheme>()!.hintTextColor,
              ),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              validator: null,
            ),
            SizedBox(
              height: 52,
            ),
          ],
        ));
  }

  void _presentPicker(BuildContext context) async {
    await showPopUp<void>(
      builder: (_) => CurrencyPicker(
        selectedAtIndex: lightningInvoicePageViewModel.selectedCurrencyIndex,
        items: lightningInvoicePageViewModel.currencies,
        hintText: S.of(context).search_currency,
        onItemSelected: lightningInvoicePageViewModel.selectCurrency,
      ),
      context: context,
    );
    lightningInvoicePageViewModel.fetchFiatRate();
  }
}
