import 'dart:async';

import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/src/screens/receive/widgets/lightning_input_form.dart';
import 'package:cake_wallet/src/screens/receive/widgets/qr_image.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/present_receive_option_picker.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/dashboard/receive_option_view_model.dart';
import 'package:cake_wallet/view_model/lightning_invoice_page_view_model.dart';
import 'package:cake_wallet/view_model/lightning_view_model.dart';
import 'package:cw_core/receive_page_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/trail_button.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:mobx/mobx.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;

class LightningInvoicePage extends BasePage {
  LightningInvoicePage({
    required this.lightningInvoicePageViewModel,
    required this.receiveOptionViewModel,
  }) : _amountFocusNode = FocusNode() {}

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final FocusNode _amountFocusNode;

  final LightningInvoicePageViewModel lightningInvoicePageViewModel;
  final ReceiveOptionViewModel receiveOptionViewModel;
  final _formKey = GlobalKey<FormState>();
  Timer? _rescanTimer;

  bool effectsInstalled = false;

  @override
  bool get gradientAll => true;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  void onClose(BuildContext context) {
    _rescanTimer?.cancel();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget middle(BuildContext context) => PresentReceiveOptionPicker(
      receiveOptionViewModel: receiveOptionViewModel, color: titleColor(context));

  @override
  Widget trailing(BuildContext context) => TrailButton(
      caption: S.of(context).clear,
      onPressed: () {
        _formKey.currentState?.reset();
      });

  Future<bool> _onNavigateBack(BuildContext context) async {
    onClose(context);
    return false;
  }

  @override
  Widget body(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _setReactions(context));

    return WillPopScope(
      onWillPop: () => _onNavigateBack(context),
      child: KeyboardActions(
        disableScroll: true,
        config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                focusNode: _amountFocusNode,
                toolbarButtons: [(_) => KeyboardDoneButton()],
              ),
            ]),
        child: Container(
          color: Theme.of(context).colorScheme.background,
          child: ScrollableWithBottomSection(
            contentPadding: EdgeInsets.only(bottom: 24),
            content: Container(
              decoration: responsiveLayoutUtil.shouldRenderMobileUI
                  ? BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .firstGradientTopPanelColor,
                          Theme.of(context)
                              .extension<ExchangePageTheme>()!
                              .secondGradientTopPanelColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 120, 24, 0),
                child: LightningInvoiceForm(
                  descriptionController: _descriptionController,
                  amountController: _amountController,
                  depositAmountFocus: _amountFocusNode,
                  formKey: _formKey,
                  lightningInvoicePageViewModel: lightningInvoicePageViewModel,
                ),
              ),
            ),
            bottomSectionPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
            bottomSection: Column(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 12, right: 6),
                  margin: const EdgeInsets.only(left: 24, right: 24, bottom: 48),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color.fromARGB(255, 170, 147, 30),
                    border: Border.all(
                      color: Color.fromARGB(178, 223, 214, 0),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        margin: EdgeInsets.only(left: 12, bottom: 48, right: 20),
                        child: Image.asset(
                          "assets/images/warning.png",
                          color: Color.fromARGB(128, 255, 255, 255),
                        ),
                      ),
                      FutureBuilder(
                        future: lightningInvoicePageViewModel.lightningViewModel
                            .invoiceSoftLimitsSats(),
                        builder: (context, snapshot) {
                          if (snapshot.data == null) {
                            return Expanded(
                                child:
                                    Container(child: Center(child: CircularProgressIndicator())));
                          }
                          late String finalText;
                          InvoiceSoftLimitsResult limits = snapshot.data as InvoiceSoftLimitsResult;
                          if (limits.inboundLiquidity == 0) {
                            finalText = S.of(context).lightning_invoice_min(
                                  limits.feePercent.toString(),
                                  lightning!.satsToLightningString(limits.minFee),
                                );
                          } else {
                            finalText = S.of(context).lightning_invoice_min_max(
                                  limits.feePercent.toString(),
                                  lightning!.satsToLightningString(limits.minFee),
                                  lightning!.satsToLightningString(limits.inboundLiquidity),
                                );
                          }

                          return Expanded(
                            child: Text(
                              finalText,
                              maxLines: 5,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Observer(builder: (_) {
                  return LoadingPrimaryButton(
                    text: S.of(context).create_invoice,
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      lightningInvoicePageViewModel.setRequestParams(
                        inputAmount: _amountController.text,
                        inputDescription: _descriptionController.text,
                      );
                      lightningInvoicePageViewModel.createInvoice();
                    },
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    isLoading: lightningInvoicePageViewModel.state is IsExecutingState,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setReactions(BuildContext context) {
    if (effectsInstalled) {
      return;
    }

    _amountController.addListener(() {
      lightningInvoicePageViewModel.setRequestParams(
        inputAmount: _amountController.text,
        inputDescription: '',
      );
    });

    reaction((_) => receiveOptionViewModel.selectedReceiveOption, (ReceivePageOption option) async {
      if (option == lightning!.getOptionOnchain()) {
        Navigator.popAndPushNamed(
          context,
          Routes.lightningReceiveOnchain,
          arguments: [lightning!.getOptionOnchain()],
        );
      }
    });

    reaction((_) => lightningInvoicePageViewModel.state, (ExecutionState state) {
      if (state is ExecutedSuccessfullyState) {
        showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithTwoActions(
                alertTitle: S.of(context).invoice_created,
                alertContent: '',
                contentWidget: Column(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          padding: EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 3,
                              color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                            ),
                          ),
                          child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  width: 3,
                                  color: Colors.white,
                                ),
                              ),
                              child: QrImage(
                                data: state.payload as String,
                                version: 14,
                                errorCorrectionLevel: qr.QrErrorCorrectLevel.L,
                              )),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(top: 12, bottom: 12, right: 6),
                      margin: const EdgeInsets.only(top: 32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                        color: Color.fromARGB(255, 170, 147, 30),
                        border: Border.all(
                          color: Color.fromARGB(178, 223, 214, 0),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            margin: EdgeInsets.only(left: 12, bottom: 48, right: 12),
                            child: Image.asset(
                              "assets/images/warning.png",
                              color: Color.fromARGB(128, 255, 255, 255),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                S.of(context).lightning_invoice_warning,
                                maxLines: 5,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                rightButtonText: S.of(context).ok,
                actionRightButton: () => Navigator.of(context).pop(),
                actionLeftButton: () async {
                  Clipboard.setData(ClipboardData(text: state.payload as String));
                  showBar<void>(context, S.of(context).copied_to_clipboard);
                },
                leftButtonText: S.of(context).copy,
              );
            });
      }

      if (state is FailureState) {
        showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithOneAction(
                  alertTitle: S.of(context).error,
                  alertContent: state.error.toString(),
                  buttonText: S.of(context).ok,
                  buttonAction: () => Navigator.of(context).pop());
            });
      }
    });

    // the payments stream is NOT consistently triggered but calling updateTransactions()
    // will get breez to notify us of incoming payments, we do this only on this screen:
    _rescanTimer?.cancel();
    _rescanTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      lightningInvoicePageViewModel.updateTransactions();
    });

    effectsInstalled = true;
  }
}
