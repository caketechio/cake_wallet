import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/src/screens/receive/widgets/anonpay_currency_input_field.dart';
import 'package:cake_wallet/src/screens/send/widgets/confirm_sending_alert.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/lightning_send_view_model.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/trail_button.dart';
import 'package:cake_wallet/generated/i18n.dart';

class LightningRefundPage extends BasePage {
  LightningRefundPage({
    required this.output,
    required this.authService,
    required this.lightningSendViewModel,
    String? address,
  })  : _invoiceController = TextEditingController(text: address),
        address = address ?? '',
        _formKey = GlobalKey<FormState>() {
    _amountController = TextEditingController();
    _fiatAmountController = TextEditingController();
    _amountFocus = FocusNode();
    _fiatAmountController.text = lightningSendViewModel.formattedFiatAmount(0);
    _invoiceFocusNode = FocusNode();
  }

  final Output output;
  final AuthService authService;
  late TextEditingController _amountController;
  late TextEditingController _fiatAmountController;
  late FocusNode _amountFocus;
  final LightningSendViewModel lightningSendViewModel;
  final GlobalKey<FormState> _formKey;

  late TextEditingController _invoiceController;
  late FocusNode _invoiceFocusNode;

  bool _effectsInstalled = false;

  late String address;

  @override
  String get title => S.current.send;

  @override
  bool get gradientAll => true;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  bool get extendBodyBehindAppBar => true;

  @override
  Widget? leading(BuildContext context) {
    final _backButton = Icon(
      Icons.arrow_back_ios,
      color: titleColor(context),
      size: 16,
    );
    final _closeButton =
        currentTheme.type == ThemeType.dark ? closeButtonImageDarkTheme : closeButtonImage;

    bool isMobileView = responsiveLayoutUtil.shouldRenderMobileUI;

    return MergeSemantics(
      child: SizedBox(
        height: isMobileView ? 37 : 45,
        width: isMobileView ? 37 : 45,
        child: ButtonTheme(
          minWidth: double.minPositive,
          child: Semantics(
            label: !isMobileView ? S.of(context).close : S.of(context).seed_alert_back,
            child: TextButton(
              style: ButtonStyle(
                overlayColor: MaterialStateColor.resolveWith((states) => Colors.transparent),
              ),
              onPressed: () => onClose(context),
              child: !isMobileView ? _closeButton : _backButton,
            ),
          ),
        ),
      ),
    );
  }

  @override
  AppBarStyle get appBarStyle => AppBarStyle.transparent;

  @override
  void onClose(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget trailing(context) => TrailButton(
      caption: S.of(context).clear,
      onPressed: () {
        _formKey.currentState?.reset();
        _amountController.text = "";
        _fiatAmountController.text = lightningSendViewModel.formattedFiatAmount(0);
        _invoiceController.text = '';
        lightningSendViewModel.processSilently('');
      });

  @override
  Widget body(BuildContext context) {
    _setEffects(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: WillPopScope(
        onWillPop: () => _onNavigateBack(context),
        child: KeyboardActions(
          disableScroll: true,
          config: KeyboardActionsConfig(
              keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
              keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
              nextFocus: false,
              actions: [
                KeyboardActionsItem(
                  focusNode: FocusNode(),
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
                  child: Column(
                    children: [
                      AddressTextField(
                        focusNode: _invoiceFocusNode,
                        controller: _invoiceController,
                        onURIScanned: (uri) {
                          final paymentRequest = PaymentRequest.fromUri(uri);
                          _invoiceController.text = paymentRequest.address;
                        },
                        options: [
                          AddressTextFieldOption.paste,
                          AddressTextFieldOption.qrCode,
                          AddressTextFieldOption.addressBook
                        ],
                        buttonColor:
                            Theme.of(context).extension<SendPageTheme>()!.textFieldButtonColor,
                        borderColor:
                            Theme.of(context).extension<SendPageTheme>()!.textFieldBorderColor,
                        textStyle: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                        hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).extension<SendPageTheme>()!.textFieldHintColor),
                        onPushPasteButton: (context) async {
                          output.resetParsedAddress();
                          await output.fetchParsedAddress(context);
                          await processInput(context);
                        },
                        onPushAddressBookButton: (context) async {
                          output.resetParsedAddress();
                        },
                        onSelectedContact: (contact) {
                          output.loadContact(contact);
                        },
                        selectedCurrency: CryptoCurrency.btc,
                      ),
                      SizedBox(height: 12),
                      Observer(
                        builder: (_) => GestureDetector(
                          onTap: () => pickTransactionPriority(context),
                          child: Container(
                            padding: EdgeInsets.only(top: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  S.of(context).send_estimated_fee,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white),
                                ),
                                Container(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "${lightningSendViewModel.estimatedFeeSats} ${lightningSendViewModel.currency.toString()}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(top: 5),
                                            child: lightningSendViewModel.isFiatDisabled
                                                ? const SizedBox(height: 14)
                                                : Text(
                                                    "${lightningSendViewModel.estimatedFeeFiatAmount} ${lightningSendViewModel.fiat.title}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Theme.of(context)
                                                          .extension<SendPageTheme>()!
                                                          .textFieldHintColor,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(top: 2, left: 5),
                                        child: Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              bottomSectionPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
              bottomSection: Observer(builder: (_) {
                return Column(
                  children: <Widget>[
                    Observer(
                      builder: (context) {
                        return LoadingPrimaryButton(
                          text: S.current.send,
                          onPressed: () async {
                            try {
                              await lightningSendViewModel
                                  .prepareRefundBtc(lightningSendViewModel.btcAddress);

                              bool cancel = await showPopUp<bool>(
                                      context: context,
                                      builder: (BuildContext _dialogContext) {
                                        final output = Output(
                                          lightningSendViewModel.wallet,
                                          lightningSendViewModel.settingsStore,
                                          lightningSendViewModel.fiatConversionStore,
                                          () {
                                            return CryptoCurrency.btcln;
                                          },
                                        );
                                        String feeValue = '';
                                        String feeFiatAmount = '';

                                        output.address = lightningSendViewModel.btcAddress;
                                        feeValue =
                                            lightningSendViewModel.estimatedFeeSats.toString();
                                        feeFiatAmount = lightningSendViewModel.formattedFiatAmount(
                                            lightningSendViewModel.estimatedFeeSats);
                                        output.cryptoAmount =
                                            "${lightning!.getOnchainBalance(lightningSendViewModel.wallet)} sats";

                                        return ConfirmSendingAlert(
                                          alertTitle: S.current.confirm_sending,
                                          amount: S.current.send_amount,
                                          amountValue: output.cryptoAmount,
                                          fiatAmountValue:
                                              "${_fiatAmountController.text} ${lightningSendViewModel.fiat.title}",
                                          fee: S.current.send_fee,
                                          feeValue: feeValue,
                                          feeFiatAmount: feeFiatAmount,
                                          outputs: [output],
                                          leftButtonText: S.current.cancel,
                                          rightButtonText: S.current.ok,
                                          actionRightButton: () {
                                            Navigator.of(_dialogContext).pop(false);
                                          },
                                          actionLeftButton: () {
                                            Navigator.of(_dialogContext).pop(true);
                                          },
                                        );
                                      }) ??
                                  true;

                              if (cancel) {
                                return;
                              }

                              await lightningSendViewModel
                                  .refundBtc(lightningSendViewModel.btcAddress);

                              await showPopUp<void>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertWithOneAction(
                                        alertTitle: '',
                                        alertContent: S
                                            .of(context)
                                            .send_success(CryptoCurrency.btc.toString()),
                                        buttonText: S.of(context).ok,
                                        buttonAction: () {
                                          Navigator.of(context).pop();
                                          // todo: Navigator.popUntil(context, (route) => route.isFirst);
                                        });
                                  });
                              Navigator.of(context).pop();
                            } catch (e) {
                              showPopUp<void>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertWithOneAction(
                                      alertTitle: S.of(context).error,
                                      alertContent: e.toString(),
                                      buttonText: S.of(context).ok,
                                      buttonAction: () => Navigator.of(context).pop(),
                                    );
                                  });
                            }
                          },
                          color: Theme.of(context).primaryColor,
                          textColor: Colors.white,
                          isLoading: lightningSendViewModel.loading,
                        );
                      },
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> processInput(BuildContext context) async {
    try {
      await lightningSendViewModel.processInput(_invoiceController.text, context: context);
    } catch (e) {
      showPopUp<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertWithOneAction(
                alertTitle: S.of(context).error,
                alertContent: e.toString(),
                buttonText: S.of(context).ok,
                buttonAction: () => Navigator.of(context).pop());
          });
    }
  }

  Future<bool> _onNavigateBack(BuildContext context) async {
    onClose(context);
    return false;
  }

  Future<void> pickTransactionPriority(BuildContext context) async {
    final items = priorityForWalletType(WalletType.lightning);
    final selectedItem = items.indexOf(lightningSendViewModel.transactionPriority);
    final customItemIndex = lightningSendViewModel.getCustomPriorityIndex(items);
    double? maxCustomFeeRate = (await lightningSendViewModel.maxCustomFeeRate)?.toDouble();
    double? customFeeRate = lightningSendViewModel.customBitcoinFeeRate.toDouble();

    await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        int selectedIdx = selectedItem;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Picker(
              items: items,
              displayItem: (TransactionPriority priority) => lightningSendViewModel.displayFeeRate(
                priority,
                customFeeRate?.round(),
              ),
              selectedAtIndex: selectedIdx,
              customItemIndex: customItemIndex,
              maxValue: maxCustomFeeRate,
              title: S.of(context).please_select,
              headerEnabled: false,
              closeOnItemSelected: false,
              mainAxisAlignment: MainAxisAlignment.center,
              sliderValue: customFeeRate,
              onSliderChanged: (double newValue) => setState(() => customFeeRate = newValue),
              onItemSelected: (TransactionPriority priority) {
                lightningSendViewModel.setTransactionPriority(priority);
                setState(() => selectedIdx = items.indexOf(priority));
              },
            );
          },
        );
      },
    );
    lightningSendViewModel.customBitcoinFeeRate = customFeeRate!.round();
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    lightningSendViewModel.fetchLimits();
    lightningSendViewModel.fetchFees();
    lightningSendViewModel.estimateFeeSats();

    int redeemableBalance = lightning!.getOnchainBalance(lightningSendViewModel.wallet);
    // ensure we can calculate the fee because the breez api thinks we're doing a swap-out:
    // 60k is arbitrary but we don't have any way of knowing the actual minimum
    if (redeemableBalance < 60000) {
      redeemableBalance = 60000;
    }
    lightningSendViewModel.setCryptoAmount(redeemableBalance);

    _invoiceController.addListener(() async {
      await lightningSendViewModel.processSilently(_invoiceController.text);
      await lightningSendViewModel.prepareRefundBtc(lightningSendViewModel.btcAddress);
    });

    _effectsInstalled = true;
  }
}
