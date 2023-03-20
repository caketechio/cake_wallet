import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/ionia/ionia_merchant.dart';
import 'package:cake_wallet/ionia/ionia_tip.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/ionia/widgets/ionia_alert_model.dart';
import 'package:cake_wallet/src/screens/ionia/widgets/text_icon_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/discount_badge.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/ionia/ionia_purchase_merch_view_model.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/send/widgets/confirm_sending_alert.dart';

class IoniaBuyGiftCardDetailPage extends BasePage {
  IoniaBuyGiftCardDetailPage(this.ioniaPurchaseViewModel);

  final IoniaMerchPurchaseViewModel ioniaPurchaseViewModel;

  @override
  Widget middle(BuildContext context) {
    return Text(
      ioniaPurchaseViewModel.ioniaMerchant.legalName,
      style: textMediumSemiBold(color: Theme.of(context).accentTextTheme!.headline1!.backgroundColor!),
    );
  }

  @override
  Widget? trailing(BuildContext context)
    => ioniaPurchaseViewModel.ioniaMerchant.discount > 0
      ? DiscountBadge(percentage: ioniaPurchaseViewModel.ioniaMerchant.discount)
      : null;

  @override
  Widget body(BuildContext context) {
    reaction((_) => ioniaPurchaseViewModel.invoiceCreationState, (ExecutionState state) {
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
    });

    reaction((_) => ioniaPurchaseViewModel.invoiceCommittingState, (ExecutionState state) {
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
          Navigator.of(context).pushReplacementNamed(
            Routes.ioniaPaymentStatusPage,
            arguments: [
              ioniaPurchaseViewModel.paymentInfo,
              ioniaPurchaseViewModel.committedInfo]);
        });
      }
    });

    return ScrollableWithBottomSection(
        contentPadding: EdgeInsets.zero,
        content: Observer(builder: (_) {
          final tipAmount = ioniaPurchaseViewModel.tipAmount;
          return Column(
            children: [
              SizedBox(height: 36),
              Container(
                padding: EdgeInsets.symmetric(vertical: 24),
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryTextTheme!.subtitle1!.color!,
                      Theme.of(context).primaryTextTheme!.subtitle1!.decorationColor!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      S.of(context).gift_card_amount,
                      style: textSmall(),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\$${ioniaPurchaseViewModel.giftCardAmount.toStringAsFixed(2)}',
                      style: textXLargeSemiBold(),
                    ),
                    SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).bill_amount,
                                style: textSmall(),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '\$${ioniaPurchaseViewModel.billAmount.toStringAsFixed(2)}',
                                style: textLargeSemiBold(),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                S.of(context).tip,
                                style: textSmall(),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '\$${tipAmount.toStringAsFixed(2)}',
                                style: textLargeSemiBold(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if(ioniaPurchaseViewModel.ioniaMerchant.acceptsTips)
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 24.0, 0, 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context).tip,
                      style: TextStyle(
                        color: Theme.of(context).primaryTextTheme!.headline6!.color!,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Observer(
                      builder: (_) => TipButtonGroup(
                        selectedTip: ioniaPurchaseViewModel.selectedTip!.percentage,
                        tipsList: ioniaPurchaseViewModel.tips,
                        onSelect: (value) => ioniaPurchaseViewModel.addTip(value),
                        amount: ioniaPurchaseViewModel.amount,
                        merchant: ioniaPurchaseViewModel.ioniaMerchant,
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextIconButton(
                  label: S.of(context).how_to_use_card,
                  onTap: () => _showHowToUseCard(context, ioniaPurchaseViewModel.ioniaMerchant),
                ),
              ),
            ],
          );
        }),
        bottomSection: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Observer(builder: (_) {
                return LoadingPrimaryButton(
                  isLoading: ioniaPurchaseViewModel.invoiceCreationState is IsExecutingState ||
                      ioniaPurchaseViewModel.invoiceCommittingState is IsExecutingState,
                  onPressed: () => purchaseCard(context),
                  text: S.of(context).purchase_gift_card,
                  color: Theme.of(context).accentTextTheme!.bodyText1!.color!,
                  textColor: Colors.white,
                );
              }),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _showTermsAndCondition(context),
              child: Text(S.of(context).settings_terms_and_conditions,
                  style: textMediumSemiBold(
                    color: Theme.of(context).primaryTextTheme!.bodyText2!.color!,
                  ).copyWith(fontSize: 12)),
            ),
            SizedBox(height: 16)
          ],
        ),
    );
  }

  void _showTermsAndCondition(BuildContext context) {
    showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
          return IoniaAlertModal(
            title: S.of(context).settings_terms_and_conditions,
            content: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              ioniaPurchaseViewModel.ioniaMerchant.termsAndConditions,
              style: textMedium(
                color: Theme.of(context).textTheme!.headline3!.color!,
              ),
            ),
          ),
          actionTitle: S.of(context).agree,
          showCloseButton: false,
          heightFactor: 0.6,
        );
  }); 
  }

  Future<void> purchaseCard(BuildContext context) async {
    await ioniaPurchaseViewModel.createInvoice();

    if (ioniaPurchaseViewModel.invoiceCreationState is ExecutedSuccessfullyState) {
      await _presentSuccessfulInvoiceCreationPopup(context);
    }
  }

  void _showHowToUseCard(
    BuildContext context,
    IoniaMerchant merchant,
  ) {
    showPopUp<void>(
        context: context,
          builder: (BuildContext context) {
        return  IoniaAlertModal(
          title: S.of(context).how_to_use_card,
          content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: merchant.instructions
                    .map((instruction) {
                      return [
                        Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              instruction.header,
                              style: textLargeSemiBold(
                                color: Theme.of(context).textTheme!.headline3!.color!,
                              ),
                            )),
                        Text(
                          instruction.body,
                          style: textMedium(
                            color: Theme.of(context).textTheme!.headline3!.color!,
                          ),
                        )
                      ];
                    })
                    .expand((e) => e)
                    .toList()), 
          actionTitle: S.current.send_got_it,
        ); 
    });
  }

  Future<void> _presentSuccessfulInvoiceCreationPopup(BuildContext context) async {
    if (ioniaPurchaseViewModel.invoice == null) {
      return;
    }
    
    final amount = ioniaPurchaseViewModel.invoice!.totalAmount;
    final addresses = ioniaPurchaseViewModel.invoice!.outAddresses;
    ioniaPurchaseViewModel.sendViewModel.outputs.first.setCryptoAmount(amount);
    ioniaPurchaseViewModel.sendViewModel.outputs.first.address = addresses.first;

    await showPopUp<void>(
      context: context,
      builder: (_) {
        return ConfirmSendingAlert(
            alertTitle: S.of(context).confirm_sending,
            paymentId: S.of(context).payment_id,
            paymentIdValue: ioniaPurchaseViewModel.invoice!.paymentId,
            amount: S.of(context).send_amount,
            amountValue: '$amount ${ioniaPurchaseViewModel.invoice!.chain}',
            fiatAmountValue:
            '~ ${ioniaPurchaseViewModel.sendViewModel.outputs.first.fiatAmount} '
                '${ioniaPurchaseViewModel.sendViewModel.fiat.title}',
            fee: S.of(context).send_fee,
            feeValue:
            '${ioniaPurchaseViewModel.sendViewModel.estimatedFee} '
                '${ioniaPurchaseViewModel.invoice!.chain}',
            feeFiatAmount:
            '${ioniaPurchaseViewModel.sendViewModel.estimatedFeeFiatAmount} '
                '${ioniaPurchaseViewModel.sendViewModel.fiat.title}',
            outputs: ioniaPurchaseViewModel.sendViewModel.outputs,
            rightButtonText: S.of(context).ok,
            leftButtonText: S.of(context).cancel,
            alertLeftActionButtonTextColor: Colors.white,
            alertRightActionButtonTextColor: Colors.white,
            alertLeftActionButtonColor: Palette.brightOrange,
            alertRightActionButtonColor: Theme.of(context).textTheme!.subtitle2!.color,
            actionRightButton: () async {
              Navigator.of(context).pop();
              await ioniaPurchaseViewModel.commitPaymentInvoice();
            },
            actionLeftButton: () => Navigator.of(context).pop());
      },
    );
  }
}

class TipButtonGroup extends StatelessWidget {
  const TipButtonGroup({
    Key? key,
    required this.selectedTip,
    required this.onSelect,
    required this.tipsList,
    required this.amount,
    required this.merchant,
  }) : super(key: key);

  final Function(IoniaTip) onSelect;
  final double selectedTip;
  final List<IoniaTip> tipsList;
  final double amount;
  final IoniaMerchant merchant;

  bool _isSelected(double value) => selectedTip == value;
  Set<double> get filter => tipsList.map((e) => e.percentage).toSet();
  bool get _isCustomSelected => !filter.contains(selectedTip);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tipsList.length,
        itemBuilder: (BuildContext context, int index) {
          final tip = tipsList[index];
          return Padding(
            padding: EdgeInsets.only(right: 5),
            child: TipButton(
                isSelected: tip.isCustom ? _isCustomSelected :  _isSelected(tip.percentage),
                onTap: () async {
                    IoniaTip ioniaTip = tip;
                    if(tip.isCustom){
                      final customTip = await Navigator.pushNamed(context, Routes.ioniaCustomTipPage, arguments: [amount, merchant, tip]) as IoniaTip?;
                      ioniaTip =  customTip ?? tip;
                    }
                    onSelect(ioniaTip);
                },
                caption: tip.isCustom ? S.of(context).custom : '${tip.percentage.toStringAsFixed(0)}%',
                subTitle: tip.isCustom ? null : '\$${tip.additionalAmount.toStringAsFixed(2)}',
              ));
        }));
  }
}

class TipButton extends StatelessWidget {
  const TipButton({
    required this.caption,
    required this.onTap,
    this.subTitle,
    this.isSelected = false,
  });

  final String caption;
  final String? subTitle;
  final bool isSelected;
  final void Function() onTap;

  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  Color captionTextColor(BuildContext context) {
    if (isDark(context)) {
      return Theme.of(context).primaryTextTheme!.headline6!.color!;
    }

    return isSelected
      ? Theme.of(context).accentTextTheme!.headline6!.color!
      : Theme.of(context).primaryTextTheme!.headline6!.color!;
  }

  Color subTitleTextColor(BuildContext context) {
    if (isDark(context)) {
      return Theme.of(context).primaryTextTheme!.headline6!.color!;
    }

    return isSelected
      ? Theme.of(context).accentTextTheme!.headline6!.color!
      : Theme.of(context).primaryTextTheme!.overline!.color!;
  }

  Color? backgroundColor(BuildContext context) {
    if (isDark(context)) {
      return isSelected
        ? null
        : Theme.of(context).accentTextTheme!.headline1!.backgroundColor!.withOpacity(0.01);
    }

    return isSelected
        ? null
        : Theme.of(context).accentTextTheme!.headline1!.backgroundColor!.withOpacity(0.1);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 49,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(caption,
                style: textSmallSemiBold(
                    color: captionTextColor(context))),
            if (subTitle != null) ...[
              SizedBox(height: 4),
              Text(
                subTitle!,
                style: textXxSmallSemiBold(
                  color: subTitleTextColor(context),
                ),
              ),
            ]
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: backgroundColor(context),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).primaryTextTheme!.subtitle1!.color!,
                    Theme.of(context).primaryTextTheme!.subtitle1!.decorationColor!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
      ),
    );
  }
}
