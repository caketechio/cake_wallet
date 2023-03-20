import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/sync_indicator_icon.dart';
import 'package:cake_wallet/src/screens/send/widgets/send_card.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/src/widgets/template_tile.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/trail_button.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/send/send_view_model_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/screens/send/widgets/confirm_sending_alert.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cw_core/crypto_currency.dart';

class SendPage extends BasePage {
  SendPage({
    required this.sendViewModel,
    this.initialPaymentRequest,
  }) : _formKey = GlobalKey<FormState>();

  final SendViewModel sendViewModel;
  final GlobalKey<FormState> _formKey;
  final controller = PageController(initialPage: 0);
  final PaymentRequest? initialPaymentRequest;

  bool _effectsInstalled = false;

  @override
  String get title => S.current.send;

  @override
  Color get titleColor => Colors.white;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  void onClose(BuildContext context) {
    sendViewModel.onClose();
    Navigator.of(context).pop();
  }

  @override
  Widget? middle(BuildContext context) {
    final supMiddle = super.middle(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right:8.0),
          child: Observer(builder: (_) => SyncIndicatorIcon(isSynced: sendViewModel.isReadyForSend),),
        ),
        if (supMiddle != null)
          supMiddle
      ],
    );
  }

  @override
  Widget trailing(context) => Observer(builder: (_) {
        return sendViewModel.isBatchSending
            ? TrailButton(
                caption: S.of(context).remove,
                onPressed: () {
                  var pageToJump = (controller.page?.round() ?? 0) - 1;
                  pageToJump = pageToJump > 0 ? pageToJump : 0;
                  final output = _defineCurrentOutput();
                  sendViewModel.removeOutput(output);
                  controller.jumpToPage(pageToJump);
                })
            : TrailButton(
                caption: S.of(context).clear,
                onPressed: () {
                  final output = _defineCurrentOutput();
                  _formKey.currentState?.reset();
                  output.reset();
                });
      });

  @override
  Widget body(BuildContext context) {
    _setEffects(context);

    return Form(
      key: _formKey,
      child: ScrollableWithBottomSection(
          contentPadding: EdgeInsets.only(bottom: 24),
          content: Column(
            children: <Widget>[
              Container(
                  height: sendViewModel.isElectrumWallet ? 490 : 465,
                  child: Observer(
                    builder: (_) {
                      return PageView.builder(
                          scrollDirection: Axis.horizontal,
                          controller: controller,
                          itemCount: sendViewModel.outputs.length,
                          itemBuilder: (context, index) {
                            final output = sendViewModel.outputs[index];

                            return SendCard(
                              key: output.key,
                              output: output,
                              sendViewModel: sendViewModel,
                              initialPaymentRequest: initialPaymentRequest,
                            );
                          });
                    },
                  )),
              Padding(
                padding:
                    EdgeInsets.only(top: 10, left: 24, right: 24, bottom: 10),
                child: Container(
                  height: 10,
                  child: Observer(
                    builder: (_) {
                      final count = sendViewModel.outputs.length;

                      return count > 1
                          ? SmoothPageIndicator(
                              controller: controller,
                              count: count,
                              effect: ScrollingDotsEffect(
                                  spacing: 6.0,
                                  radius: 6.0,
                                  dotWidth: 6.0,
                                  dotHeight: 6.0,
                                  dotColor: Theme.of(context)
                                      .primaryTextTheme!
                                      .headline3!
                                      .backgroundColor!,
                                  activeDotColor: Theme.of(context)
                                      .primaryTextTheme!
                                      .headline2!
                                      .backgroundColor!),
                            )
                          : Offstage();
                    },
                  ),
                ),
              ),
              if (sendViewModel.hasMultiRecipient)
              Container(
                height: 40,
                width: double.infinity,
                padding: EdgeInsets.only(left: 24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Observer(
                    builder: (_) {
                      final templates = sendViewModel.templates;
                      final itemCount = templates.length;

                      return Row(
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed(Routes.sendTemplate),
                            child: Container(
                              padding: EdgeInsets.only(left: 1, right: 10),
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                dashPattern: [6, 4],
                                color: Theme.of(context)
                                    .primaryTextTheme!
                                    .headline2!
                                    .decorationColor!,
                                strokeWidth: 2,
                                radius: Radius.circular(20),
                                child: Container(
                                  height: 34,
                                  padding: EdgeInsets.only(left: 10, right: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(20)),
                                    color: Colors.transparent,
                                  ),
                                  child: templates.length >= 1
                                      ? Icon(
                                          Icons.add,
                                          color: Theme.of(context)
                                              .primaryTextTheme!
                                              .headline2!
                                              .color!,
                                        )
                                      : Text(
                                          S.of(context).new_template,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .primaryTextTheme!
                                                .headline2!
                                                .color!,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          ListView.builder(
                            scrollDirection: Axis.horizontal,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              final template = templates[index];
                              return TemplateTile(
                                key: UniqueKey(),
                                to: template.name,
                                amount: template.isCurrencySelected ? template.amount : template.amountFiat,
                                from: template.isCurrencySelected ? template.cryptoCurrency : template.fiatCurrency,
                                onTap: () async {
                                  final fiatFromTemplate = FiatCurrency.all.singleWhere((element) => element.title == template.fiatCurrency);
                                  final output = _defineCurrentOutput();
                                  output.address = template.address;
                                  if(template.isCurrencySelected){
                                    output.setCryptoAmount(template.amount);
                                  }else{
                                    sendViewModel.setFiatCurrency(fiatFromTemplate);
                                    output.setFiatAmount(template.amountFiat);
                                  }
                                  output.resetParsedAddress();
                                  await output.fetchParsedAddress(context);
                                },
                                onRemove: () {
                                  showPopUp<void>(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertWithTwoActions(
                                          alertTitle: S.of(context).template,
                                          alertContent: S
                                              .of(context)
                                              .confirm_delete_template,
                                          rightButtonText: S.of(context).delete,
                                          leftButtonText: S.of(context).cancel,
                                          actionRightButton: () {
                                            Navigator.of(dialogContext).pop();
                                            sendViewModel.sendTemplateViewModel
                                                .removeTemplate(
                                                    template: template);
                                          },
                                          actionLeftButton: () =>
                                              Navigator.of(dialogContext)
                                                  .pop());
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )
            ],
          ),
          bottomSectionPadding:
              EdgeInsets.only(left: 24, right: 24, bottom: 24),
          bottomSection: Column(
            children: [
              if (sendViewModel.hasCurrecyChanger)
                Observer(builder: (_) =>
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: PrimaryButton(
                      onPressed: () => presentCurrencyPicker(context),
                      text: 'Change your asset (${sendViewModel.selectedCryptoCurrency})',
                      color: Colors.transparent,
                      textColor: Theme.of(context)
                          .accentTextTheme!
                          .headline3!
                          .decorationColor!,
                    )
                  )
                ),
              if (sendViewModel.hasMultiRecipient)
                Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: PrimaryButton(
                      onPressed: () {
                        sendViewModel.addOutput();
                        sendViewModel.estimateFee();
                        Future.delayed(const Duration(milliseconds: 250), () {
                          controller.jumpToPage(sendViewModel.outputs.length - 1);
                        });
                      },
                      text: S.of(context).add_receiver,
                      color: Colors.transparent,
                      textColor: Theme.of(context)
                          .accentTextTheme!
                          .headline3!
                          .decorationColor!,
                      isDottedBorder: true,
                      borderColor: Theme.of(context)
                          .primaryTextTheme!
                          .headline3!
                          .decorationColor!,
                    )),
              Observer(
                builder: (_) {
                  return LoadingPrimaryButton(
                    onPressed: () async {
                      if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                        if (sendViewModel.outputs.length > 1) {
                          showErrorValidationAlert(context);
                        }

                        return;
                      }

                      final notValidItems = sendViewModel.outputs
                          .where((item) =>
                              item.address.isEmpty || item.cryptoAmount.isEmpty)
                          .toList();

                      if (notValidItems?.isNotEmpty ?? false) {
                        showErrorValidationAlert(context);
                        return;
                      }

                      await sendViewModel.createTransaction();

                    },
                    text: S.of(context).send,
                    color: Theme.of(context).accentTextTheme!.bodyText1!.color!,
                    textColor: Colors.white,
                    isLoading: sendViewModel.state is IsExecutingState ||
                        sendViewModel.state is TransactionCommitting,
                    isDisabled: !sendViewModel.isReadyForSend,
                  );
                },
              )
            ],
          )),
    );
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    reaction((_) => sendViewModel.state, (ExecutionState state) {
      if (state is FailureState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: S.of(context).error,
                    alertContent: state.error,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
        });
      }

      if (state is ExecutedSuccessfullyState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return ConfirmSendingAlert(
                    alertTitle: S.of(context).confirm_sending,
                    amount: S.of(context).send_amount,
                    amountValue:
                        sendViewModel.pendingTransaction!.amountFormatted,
                    fiatAmountValue: sendViewModel.pendingTransactionFiatAmountFormatted,
                    fee: S.of(context).send_fee,
                    feeValue: sendViewModel.pendingTransaction!.feeFormatted,
                    feeFiatAmount: sendViewModel.pendingTransactionFeeFiatAmountFormatted,
                    outputs: sendViewModel.outputs,
                    rightButtonText: S.of(context).ok,
                    leftButtonText: S.of(context).cancel,
                    actionRightButton: () {
                      Navigator.of(context).pop();
                      sendViewModel.commitTransaction();
                      showPopUp<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return Observer(builder: (_) {
                              final state = sendViewModel.state;

                              if (state is FailureState) {
                                Navigator.of(context).pop();
                              }

                              if (state is TransactionCommitted) {
                                return AlertWithOneAction(
                                    alertTitle: '',
                                    alertContent: S.of(context).send_success(
                                        sendViewModel.selectedCryptoCurrency.toString()),
                                    buttonText: S.of(context).ok,
                                    buttonAction: () =>
                                        Navigator.of(context).pop());
                              }

                              return Offstage();
                            });
                          });
                    },
                    actionLeftButton: () => Navigator.of(context).pop());
              });
          }
        });
      }

      if (state is TransactionCommitted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sendViewModel.clearOutputs();
        });
      }
    });

    _effectsInstalled = true;
  }

  Output _defineCurrentOutput() {
    if (controller.page == null) {
      throw Exception('Controller page is null');
    }
    final itemCount = controller.page!.round();
    return sendViewModel.outputs[itemCount];
  }

  void showErrorValidationAlert(BuildContext context) async {
    await showPopUp<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertWithOneAction(
              alertTitle: S.of(context).error,
              alertContent: 'Please, check receiver forms',
              buttonText: S.of(context).ok,
              buttonAction: () => Navigator.of(context).pop());
        });
  }

   void presentCurrencyPicker(BuildContext context) async {
    await showPopUp<CryptoCurrency>(
        builder: (_) => Picker(
          items: sendViewModel.currencies,
          displayItem: (Object item) => item.toString(),
          selectedAtIndex: sendViewModel.currencies.indexOf(sendViewModel.selectedCryptoCurrency),
          title: S.of(context).please_select,
          mainAxisAlignment: MainAxisAlignment.center,
          onItemSelected: (CryptoCurrency cur) => sendViewModel.selectedCryptoCurrency = cur,
        ),
        context: context);
  }
}
