import 'package:cake_wallet/src/screens/receive/widgets/address_list.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/src/widgets/gradient_background.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/share_util.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:cake_wallet/src/screens/receive/widgets/qr_widget.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

class ReceivePage extends BasePage {
  ReceivePage({required this.addressListViewModel})
      : _cryptoAmountFocus = FocusNode(),
        _amountController = TextEditingController(),
        _formKey = GlobalKey<FormState>() {
    _amountController.addListener(() {
      if (_formKey.currentState!.validate()) {
        addressListViewModel.changeAmount(_amountController.text);
      }
    });
  }

  final WalletAddressListViewModel addressListViewModel;
  final TextEditingController _amountController;
  final GlobalKey<FormState> _formKey;
  static const _heroTag = 'receive_page';

  @override
  String get title => S.current.receive;

  @override
  bool get gradientBackground => true;

  @override
  bool get resizeToAvoidBottomInset => true;

  final FocusNode _cryptoAmountFocus;

  @override
  Widget middle(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          fontFamily: 'Lato',
          color: pageIconColor(context)),
    );
  }

  @override
  Widget Function(BuildContext, Widget) get rootWrapper =>
      (BuildContext context, Widget scaffold) => GradientBackground(scaffold: scaffold);

  @override
  Widget trailing(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: Semantics(
          label: S.of(context).share,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            iconSize: 25,
            onPressed: () {
              ShareUtil.share(
                text: addressListViewModel.uri.toString(),
                context: context,
              );
            },
            icon: Icon(
              Icons.share,
              size: 20,
              color: pageIconColor(context),
            ),
          ),
        ));
  }

  @override
  Widget body(BuildContext context) {
    return KeyboardActions(
        config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                focusNode: _cryptoAmountFocus,
                toolbarButtons: [(_) => KeyboardDoneButton()],
              )
            ]),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(24, 50, 24, 24),
                child: QRWidget(
                  addressListViewModel: addressListViewModel,
                  formKey: _formKey,
                  heroTag: _heroTag,
                  amountTextFieldFocusNode: _cryptoAmountFocus,
                  amountController: _amountController,
                  isLight: currentTheme.type == ThemeType.light,
                ),
              ),
              AddressList(addressListViewModel: addressListViewModel),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Text(
                    addressListViewModel.isSilentPayments
                        ? S.of(context).silent_payments_disclaimer
                        : S.of(context).electrum_address_disclaimer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).extension<BalancePageTheme>()!.labelTextColor)),
              ),
            ],
          ),
        ));
  }
}
