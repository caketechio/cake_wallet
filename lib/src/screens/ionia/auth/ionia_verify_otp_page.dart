import 'package:cake_wallet/ionia/ionia_create_state.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/ionia/ionia_gift_cards_list_view_model.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:mobx/mobx.dart';

class IoniaVerifyIoniaOtp extends BasePage {
  IoniaVerifyIoniaOtp(this._cardsListViewModel, this._email)
      : _codeController = TextEditingController(),
        _codeFocus = FocusNode() {
    _codeController.addListener(() {
      final otp = _codeController.text;
      _cardsListViewModel.otp = otp;
      if (otp.length > 3) {
        _cardsListViewModel.otpState = IoniaOtpSendEnabled();
      } else {
        _cardsListViewModel.otpState = IoniaOtpSendDisabled();
      }
    });
  }

  final IoniaGiftCardsListViewModel _cardsListViewModel;

  final String _email;

  @override
  Widget middle(BuildContext context) {
    return Text(
      S.current.verification,
      style: textLargeSemiBold(
        color: Theme.of(context).accentTextTheme.display4.backgroundColor,
      ),
    );
  }

  final TextEditingController _codeController;
  final FocusNode _codeFocus;

  @override
  Widget body(BuildContext context) {
    reaction((_) => _cardsListViewModel.otpState, (IoniaOtpState state) {
      if (state is IoniaOtpFailure) {
        _onOtpFailure(context, state.error);
      }
      if (state is IoniaOtpSuccess) {
        _onOtpSuccessful(context);
      }
    });
    return KeyboardActions(
      config: KeyboardActionsConfig(
          keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
          keyboardBarColor: Theme.of(context).accentTextTheme.body2.backgroundColor,
          nextFocus: false,
          actions: [
            KeyboardActionsItem(
              focusNode: _codeFocus,
              toolbarButtons: [(_) => KeyboardDoneButton()],
            ),
          ]),
      child: Container(
        height: 0,
        color: Theme.of(context).backgroundColor,
        child: ScrollableWithBottomSection(
          contentPadding: EdgeInsets.all(24),
          content: Column(
            children: [
              BaseTextFormField(
                hintText: S.of(context).enter_code,
                keyboardType: TextInputType.numberWithOptions(signed: false, decimal: true),
                focusNode: _codeFocus,
                controller: _codeController,
              ),
              SizedBox(height: 14),
              Text(
                S.of(context).fill_code,
                style: TextStyle(color: Color(0xff7A93BA), fontSize: 12),
              ),
              SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(S.of(context).dont_get_code),
                  SizedBox(width: 20),
                  InkWell(
                    onTap: () => _cardsListViewModel.createUser(_email),
                    child: Text(
                      S.of(context).resend_code,
                      style: textSmallSemiBold(color: Palette.blueCraiola),
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomSectionPadding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          bottomSection: Column(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Observer(
                    builder: (_) => LoadingPrimaryButton(
                      text: S.of(context).continue_text,
                      onPressed: () async => await _cardsListViewModel.verifyEmail(_codeController.text),
                      isDisabled: _cardsListViewModel.otpState is IoniaOtpSendDisabled,
                      isLoading: _cardsListViewModel.otpState is IoniaOtpValidating,
                      color: Theme.of(context).accentTextTheme.body2.color,
                      textColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onOtpFailure(BuildContext context, String error) {
    showPopUp<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertWithOneAction(
              alertTitle: S.current.verification,
              alertContent: error,
              buttonText: S.of(context).ok,
              buttonAction: () => Navigator.of(context).pop());
        });
  }

  void _onOtpSuccessful(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(context, Routes.ioniaManageCardsPage, ModalRoute.withName(Routes.dashboard));
}
