import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/src/screens/receive/widgets/currency_input_field.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/src/screens/exchange/widgets/currency_picker.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';

class SendCard extends StatefulWidget {
  SendCard({
    Key? key,
    required this.output,
    required this.sendViewModel,
    this.initialPaymentRequest,
  }) : super(key: key);

  final Output output;
  final SendViewModel sendViewModel;
  final PaymentRequest? initialPaymentRequest;

  @override
  SendCardState createState() => SendCardState(
        output: output,
        sendViewModel: sendViewModel,
        initialPaymentRequest: initialPaymentRequest,
      );
}

class SendCardState extends State<SendCard> with AutomaticKeepAliveClientMixin<SendCard> {
  SendCardState({required this.output, required this.sendViewModel, this.initialPaymentRequest})
      : addressController = TextEditingController(),
        cryptoAmountController = TextEditingController(),
        fiatAmountController = TextEditingController(),
        noteController = TextEditingController(),
        extractedAddressController = TextEditingController(),
        cryptoAmountFocus = FocusNode(),
        fiatAmountFocus = FocusNode(),
        addressFocusNode = FocusNode();

  static const prefixIconWidth = 34.0;
  static const prefixIconHeight = 34.0;

  final Output output;
  final SendViewModel sendViewModel;
  final PaymentRequest? initialPaymentRequest;

  final TextEditingController addressController;
  final TextEditingController cryptoAmountController;
  final TextEditingController fiatAmountController;
  final TextEditingController noteController;
  final TextEditingController extractedAddressController;
  final FocusNode cryptoAmountFocus;
  final FocusNode fiatAmountFocus;
  final FocusNode addressFocusNode;

  bool _effectsInstalled = false;

  @override
  void initState() {
    super.initState();

    /// if the current wallet doesn't match the one in the qr code
    if (initialPaymentRequest != null &&
        sendViewModel.walletCurrencyName != initialPaymentRequest!.scheme.toLowerCase()) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (mounted) {
          showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: S.of(context).error,
                    alertContent: S.of(context).unmatched_currencies,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _setEffects(context);

    return Stack(
      children: [
        KeyboardActions(
          config: KeyboardActionsConfig(
            keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
            keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
            nextFocus: false,
            actions: [
              KeyboardActionsItem(
                focusNode: cryptoAmountFocus,
                toolbarButtons: [(_) => KeyboardDoneButton()],
              ),
              KeyboardActionsItem(
                focusNode: fiatAmountFocus,
                toolbarButtons: [(_) => KeyboardDoneButton()],
              )
            ],
          ),
          child: Container(
            height: 0,
            color: Colors.transparent,
          ),
        ),
        Container(
          decoration: responsiveLayoutUtil.shouldRenderMobileUI
              ? BoxDecoration(
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).extension<SendPageTheme>()!.firstGradientColor,
                      Theme.of(context).extension<SendPageTheme>()!.secondGradientColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              responsiveLayoutUtil.shouldRenderMobileUI ? 110 : 55,
              24,
              responsiveLayoutUtil.shouldRenderMobileUI ? 32 : 0,
            ),
            child: SingleChildScrollView(
              child: Observer(
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Observer(builder: (_) {
                      final validator = output.isParsedAddress
                          ? sendViewModel.textValidator
                          : sendViewModel.addressValidator;

                      return AddressTextField(
                        addressKey: ValueKey('send_page_address_textfield_key'),
                        focusNode: addressFocusNode,
                        controller: addressController,
                        onURIScanned: (uri) {
                          final paymentRequest = PaymentRequest.fromUri(uri);
                          addressController.text = paymentRequest.address;
                          cryptoAmountController.text = paymentRequest.amount;
                          noteController.text = paymentRequest.note;
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
                        },
                        onPushAddressBookButton: (context) async {
                          output.resetParsedAddress();
                        },
                        onSelectedContact: (contact) {
                          output.loadContact(contact);
                        },
                        validator: validator,
                        selectedCurrency: sendViewModel.selectedCryptoCurrency,
                      );
                    }),
                    if (output.isParsedAddress)
                      Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: BaseTextFormField(
                              controller: extractedAddressController,
                              readOnly: true,
                              borderColor: Theme.of(context)
                                  .extension<SendPageTheme>()!
                                  .textFieldBorderColor,
                              textStyle: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                              validator: sendViewModel.addressValidator)),
                    CurrencyAmountTextField(
                        currencyPickerButtonKey: ValueKey('send_page_currency_picker_button_key'),
                        amountTextfieldKey: ValueKey('send_page_amount_textfield_key'),
                        sendAllButtonKey: ValueKey('send_page_send_all_button_key'),
                        currencyAmountTextFieldWidgetKey:
                            ValueKey('send_page_crypto_currency_amount_textfield_widget_key'),
                        selectedCurrency: sendViewModel.selectedCryptoCurrency.title,
                        amountFocusNode: cryptoAmountFocus,
                        amountController: cryptoAmountController,
                        isAmountEditable: true,
                        onTapPicker: () => _presentPicker(context),
                        isPickerEnable: sendViewModel.hasMultipleTokens,
                        tag: sendViewModel.selectedCryptoCurrency.tag,
                        allAmountButton:
                            !sendViewModel.isBatchSending && sendViewModel.shouldDisplaySendALL,
                        currencyValueValidator: output.sendAll
                            ? sendViewModel.allAmountValidator
                            : sendViewModel.amountValidator,
                        allAmountCallback: () async => output.setSendAll(sendViewModel.balance)),
                    Divider(
                        height: 1,
                        color: Theme.of(context).extension<SendPageTheme>()!.textFieldHintColor),
                    Observer(
                      builder: (_) => Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                S.of(context).available_balance + ':',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .extension<SendPageTheme>()!
                                        .textFieldHintColor),
                              ),
                            ),
                            Text(
                              sendViewModel.balance,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .extension<SendPageTheme>()!
                                      .textFieldHintColor),
                            )
                          ],
                        ),
                      ),
                    ),
                    if (!sendViewModel.isFiatDisabled)
                      CurrencyAmountTextField(
                          amountTextfieldKey: ValueKey('send_page_fiat_amount_textfield_key'),
                          currencyAmountTextFieldWidgetKey:
                              ValueKey('send_page_fiat_currency_amount_textfield_widget_key'),
                          selectedCurrency: sendViewModel.fiat.title,
                          amountFocusNode: fiatAmountFocus,
                          amountController: fiatAmountController,
                          hintText: '0.00',
                          isAmountEditable: true,
                          allAmountButton: false),
                    Divider(
                        height: 1,
                        color: Theme.of(context).extension<SendPageTheme>()!.textFieldHintColor),
                    Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: BaseTextFormField(
                        key: ValueKey('send_page_note_textfield_key'),
                        controller: noteController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        borderColor:
                            Theme.of(context).extension<SendPageTheme>()!.textFieldBorderColor,
                        textStyle: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                        hintText: S.of(context).note_optional,
                        placeholderTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).extension<SendPageTheme>()!.textFieldHintColor),
                      ),
                    ),
                    if (sendViewModel.hasFees)
                      Observer(
                        builder: (_) => GestureDetector(
                          key: ValueKey('send_page_select_fee_priority_button_key'),
                          onTap: sendViewModel.hasFeesPriority
                              ? () => pickTransactionPriority(context)
                              : () {},
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
                                          FutureBuilder<double>(
                                            future: output.estimatedFee,
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Text(
                                                  '${snapshot.data} ${sendViewModel.currency.toString()}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              }
                                              return CircularProgressIndicator();
                                            },
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(top: 5),
                                            child: sendViewModel.isFiatDisabled
                                                ? const SizedBox(height: 14)
                                                : FutureBuilder<String>(
                                                    future: output.estimatedFeeFiatAmount,
                                                    builder: (context, snapshot) {
                                                      if (snapshot.hasData) {
                                                        return Text(
                                                          '${snapshot.data} ${sendViewModel.fiat.title}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Theme.of(context)
                                                                .extension<SendPageTheme>()!
                                                                .textFieldHintColor,
                                                          ),
                                                        );
                                                      }
                                                      return CircularProgressIndicator();
                                                    },
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
                    if (sendViewModel.hasCoinControl)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: GestureDetector(
                          key: ValueKey('send_page_unspent_coin_button_key'),
                          onTap: () => Navigator.of(context).pushNamed(
                            Routes.unspentCoinsList,
                            arguments: widget.sendViewModel.coinTypeToSpendFrom,
                          ),
                          child: Container(
                            color: Colors.transparent,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  S.of(context).coin_control,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    if (output.address.isNotEmpty) {
      addressController.text = output.address;
    }
    if (output.cryptoAmount.isNotEmpty) {
      cryptoAmountController.text = output.cryptoAmount;
    }
    fiatAmountController.text = output.fiatAmount;
    noteController.text = output.note;
    extractedAddressController.text = output.extractedAddress;

    cryptoAmountController.addListener(() {
      final amount = cryptoAmountController.text;

      if (output.sendAll && amount != S.current.all) {
        output.sendAll = false;
      }

      if (amount != output.cryptoAmount) {
        output.setCryptoAmount(amount);
      }
    });

    fiatAmountController.addListener(() {
      final amount = fiatAmountController.text;

      if (amount != output.fiatAmount) {
        output.sendAll = false;
        output.setFiatAmount(amount);
      }
    });

    noteController.addListener(() {
      final note = noteController.text;

      if (note != output.note) {
        output.note = note;
      }
    });

    reaction((_) => output.sendAll, (bool all) {
      if (all) {
        cryptoAmountController.text = S.current.all;
        fiatAmountController.text = '';
      }
    });

    reaction((_) => output.fiatAmount, (String amount) {
      if (amount != fiatAmountController.text) {
        fiatAmountController.text = amount;
      }
    });

    reaction((_) => output.cryptoAmount, (String amount) {
      if (output.sendAll && amount != S.current.all) {
        output.sendAll = false;
      }

      if (amount != cryptoAmountController.text) {
        cryptoAmountController.text = amount;
      }
    });

    reaction((_) => output.address, (String address) {
      if (address != addressController.text) {
        addressController.text = address;
      }
    });

    addressController.addListener(() {
      final address = addressController.text;

      if (output.address != address) {
        output.resetParsedAddress();
        output.address = address;
      }
    });

    reaction((_) => output.note, (String note) {
      if (note != noteController.text) {
        noteController.text = note;
      }
    });

    addressFocusNode.addListener(() async {
      if (!addressFocusNode.hasFocus && addressController.text.isNotEmpty) {
        await output.fetchParsedAddress(context);
      }
    });

    reaction((_) => output.extractedAddress, (String extractedAddress) {
      extractedAddressController.text = extractedAddress;
    });

    if (initialPaymentRequest != null &&
        sendViewModel.walletCurrencyName == initialPaymentRequest!.scheme.toLowerCase()) {
      addressController.text = initialPaymentRequest!.address;
      cryptoAmountController.text = initialPaymentRequest!.amount;
      noteController.text = initialPaymentRequest!.note;
    }

    _effectsInstalled = true;
  }

  Future<void> pickTransactionPriority(BuildContext context) async {
    final items = priorityForWallet(sendViewModel.wallet);
    final selectedItem = items.indexOf(sendViewModel.transactionPriority);
    final customItemIndex = sendViewModel.getCustomPriorityIndex(items);
    final isBitcoinWallet = sendViewModel.walletType == WalletType.bitcoin;
    final maxCustomFeeRate = sendViewModel.maxCustomFeeRate?.toDouble();
    double? customFeeRate = isBitcoinWallet ? sendViewModel.customBitcoinFeeRate.toDouble() : null;

    await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        int selectedIdx = selectedItem;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Picker(
              items: items,
              displayItem: (TransactionPriority priority) =>
                  sendViewModel.displayFeeRate(priority, customFeeRate?.round()),
              selectedAtIndex: selectedIdx,
              customItemIndex: customItemIndex,
              maxValue: maxCustomFeeRate,
              title: S.of(context).please_select,
              headerEnabled: !isBitcoinWallet,
              closeOnItemSelected: !isBitcoinWallet,
              mainAxisAlignment: MainAxisAlignment.center,
              sliderValue: customFeeRate,
              onSliderChanged: (double newValue) => setState(() => customFeeRate = newValue),
              onItemSelected: (TransactionPriority priority) {
                sendViewModel.setTransactionPriority(priority);
                setState(() => selectedIdx = items.indexOf(priority));
              },
            );
          },
        );
      },
    );
    if (isBitcoinWallet) sendViewModel.customBitcoinFeeRate = customFeeRate!.round();
  }

  void _presentPicker(BuildContext context) {
    showPopUp<void>(
      context: context,
      builder: (_) => CurrencyPicker(
        key: ValueKey('send_page_currency_picker_dialog_button_key'),
        selectedAtIndex: sendViewModel.currencies.indexOf(sendViewModel.selectedCryptoCurrency),
        items: sendViewModel.currencies,
        hintText: S.of(context).search_currency,
        onItemSelected: (Currency cur) =>
            sendViewModel.selectedCryptoCurrency = (cur as CryptoCurrency),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
