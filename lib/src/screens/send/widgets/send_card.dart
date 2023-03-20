import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';

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

class SendCardState extends State<SendCard>
    with AutomaticKeepAliveClientMixin<SendCard> {
  SendCardState({
    required this.output,
    required this.sendViewModel,
    this.initialPaymentRequest})
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
        showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithOneAction(
                  alertTitle: S.of(context).error,
                  alertContent: S.of(context).unmatched_currencies,
                  buttonText: S.of(context).ok,
                  buttonAction: () => Navigator.of(context).pop());
            });
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
                keyboardBarColor: Theme.of(context).accentTextTheme!.bodyText1!
                    .backgroundColor!,
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
                ]),
            child: Container(
              height: 0,
              color: Colors.transparent,
            )),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
            gradient: LinearGradient(colors: [
              Theme.of(context).primaryTextTheme!.subtitle1!.color!,
              Theme.of(context)
                  .primaryTextTheme!
                  .subtitle1!
                  .decorationColor!,
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 100, 24, 32),
            child: SingleChildScrollView(
                child: Observer(builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Observer(builder: (_) {
                      final validator = output.isParsedAddress
                          ? sendViewModel.textValidator
                          : sendViewModel.addressValidator;

                      return AddressTextField(
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
                        buttonColor: Theme.of(context)
                            .primaryTextTheme!
                            .headline4!
                            .color!,
                        borderColor: Theme.of(context)
                            .primaryTextTheme!
                            .headline5!
                            .color!,
                        textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .primaryTextTheme!
                                .headline5!
                                .decorationColor!),
                        onPushPasteButton: (context) async {
                          output.resetParsedAddress();
                          await output.fetchParsedAddress(context);
                        },
                        onPushAddressBookButton: (context) async {
                          output.resetParsedAddress();
                          await output.fetchParsedAddress(context);
                        },
                        validator: validator,
                        selectedCurrency: sendViewModel.currency,
                      );
                    }),
                    if (output.isParsedAddress) Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: BaseTextFormField(
                        controller: extractedAddressController,
                        readOnly: true,
                        borderColor: Theme.of(context)
                            .primaryTextTheme!
                            .headline5!
                            .color!,
                        textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        validator: sendViewModel.addressValidator
                      )
                    ),
                    Observer(
                        builder: (_) => Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Text(
                                          sendViewModel.selectedCryptoCurrency.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          )),
                                      sendViewModel.selectedCryptoCurrency.tag != null ? Padding(
                                        padding: const EdgeInsets.fromLTRB(3.0,0,3.0,0),
                                        child: Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .primaryTextTheme!
                                                  .headline4!
                                                  .color!,
                                              borderRadius:
                                              BorderRadius.all(Radius.circular(6))),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(6.0),
                                              child: Text( sendViewModel.selectedCryptoCurrency.tag!,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context)
                                                          .primaryTextTheme!
                                                          .headline4!
                                                          .decorationColor!)),
                                            ),
                                          ),
                                        ),
                                      ) : Container(),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 10.0),
                                        child: Text(':',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Stack(
                                      children: [
                                        BaseTextFormField(
                                            focusNode: cryptoAmountFocus,
                                            controller: cryptoAmountController,
                                            keyboardType:
                                            TextInputType.numberWithOptions(
                                                signed: false, decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.deny(RegExp('[\\-|\\ ]'))
                                            ],
                                            suffixIcon: SizedBox(
                                              width: prefixIconWidth,
                                            ),
                                            hintText: '0.0000',
                                            borderColor: Colors.transparent,
                                            textStyle: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white),
                                            placeholderTextStyle: TextStyle(
                                                color: Theme.of(context)
                                                    .primaryTextTheme!
                                                    .headline5!
                                                    .decorationColor!,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14),
                                            validator: output.sendAll
                                                ? sendViewModel.allAmountValidator
                                                : sendViewModel
                                                .amountValidator),
                                        if (!sendViewModel.isBatchSending) Positioned(
                                            top: 2,
                                            right: 0,
                                            child: Container(
                                                width: prefixIconWidth,
                                                height: prefixIconHeight,
                                                child: InkWell(
                                                    onTap: () {
                                                      output.setSendAll();
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                          color: Theme.of(context)
                                                              .primaryTextTheme!
                                                              .headline4!
                                                              .color!,
                                                          borderRadius:
                                                          BorderRadius.all(
                                                              Radius.circular(6))),
                                                      child: Center(
                                                          child: Text(
                                                              S.of(context).all,
                                                              textAlign:
                                                              TextAlign.center,
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                  FontWeight.bold,
                                                                  color:
                                                                  Theme.of(context)
                                                                      .primaryTextTheme!
                                                                      .headline4!
                                                                      .decorationColor!))),
                                                    ))))]),
                                ),
                              ],
                            )
                        )),
                    Divider(height: 1,color: Theme.of(context)
                        .primaryTextTheme!
                        .headline5!
                        .decorationColor!),
                    Observer(
                        builder: (_) => Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                  child: Text(
                                    S.of(context).available_balance +
                                        ':',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .primaryTextTheme!
                                            .headline5!
                                            .decorationColor!),
                                  )),
                              Text(
                                sendViewModel.balance,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .primaryTextTheme!
                                        .headline5!
                                        .decorationColor!),
                              )
                            ],
                          ),
                        )),
                    if (!sendViewModel.isFiatDisabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: BaseTextFormField(
                          focusNode: fiatAmountFocus,
                          controller: fiatAmountController,
                          keyboardType:
                          TextInputType.numberWithOptions(
                              signed: false, decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp('[\\-|\\ ]'))
                          ],
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(top: 9),
                            child:
                            Text(sendViewModel.fiat.title + ':',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                )),
                          ),
                          hintText: '0.00',
                          borderColor: Theme.of(context)
                              .primaryTextTheme!
                              .headline5!
                              .color!,
                          textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                          placeholderTextStyle: TextStyle(
                              color: Theme.of(context)
                                  .primaryTextTheme!.headline5!.decorationColor!,
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                        )),
                    Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: BaseTextFormField(
                        controller: noteController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        borderColor: Theme.of(context)
                            .primaryTextTheme!
                            .headline5!
                            .color!,
                        textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                        hintText: S.of(context).note_optional,
                        placeholderTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .primaryTextTheme!
                                .headline5!
                                .decorationColor!),
                      ),
                    ),
                    Observer(
                        builder: (_) => GestureDetector(
                          onTap: () =>
                              _setTransactionPriority(context),
                          child: Container(
                            padding: EdgeInsets.only(top: 24),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                    S
                                        .of(context)
                                        .send_estimated_fee,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                        FontWeight.w500,
                                        //color: Theme.of(context).primaryTextTheme!.headline3!.color!,
                                        color: Colors.white)),
                                Container(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                              sendViewModel.estimatedFee.toString() + ' ' + sendViewModel.currency.title,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  //color: Theme.of(context).primaryTextTheme!.headline3!.color!,
                                                  color:
                                                  Colors.white)),
                                          Padding(
                                              padding:
                                              EdgeInsets.only(top: 5),
                                              child: sendViewModel.isFiatDisabled
                                                  ? const SizedBox(height: 14)
                                                  : Text(sendViewModel
                                                      .estimatedFeeFiatAmount
                                                      +  ' ' +
                                                      sendViewModel
                                                          .fiat.title,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                      color: Theme
                                                          .of(context)
                                                          .primaryTextTheme!
                                                          .headline5!
                                                          .decorationColor!))
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: 2,
                                            left: 5),
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
                        )),
                    if (sendViewModel.isElectrumWallet) Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed(Routes.unspentCoinsList),
                            child: Container(
                                color: Colors.transparent,
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        S.of(context).coin_control,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white)),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  ],
                                )
                            )
                        )
                    )
                  ],
                ))
            ),
          ),
        )
      ],
    );
  }

  void _setEffects(BuildContext context) {
    if (output.address.isNotEmpty) {
      addressController.text = output.address;
    }
    if (output.cryptoAmount.isNotEmpty) {
      cryptoAmountController.text = output.cryptoAmount;
    }
    fiatAmountController.text = output.fiatAmount;
    noteController.text = output.note;
    extractedAddressController.text = output.extractedAddress;

    if (_effectsInstalled) {
      return;
    }

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
      final note = noteController.text ?? '';

      if (note != output.note) {
        output.note = note;
      }
    });

    reaction((_) => sendViewModel.estimatedFee, (double estimatedFee) {
      final firstOutput = sendViewModel.outputs[0];
      if (firstOutput != null && firstOutput.sendAll) {
        firstOutput.updateFiatAmount();
      }
    });

    reaction((_) => output.sendAll, (bool all) {
      if (all) {
        cryptoAmountController.text = S.current.all;
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

  Future<void> _setTransactionPriority(BuildContext context) async {
    final items = priorityForWalletType(sendViewModel.walletType);
    final selectedItem = items.indexOf(sendViewModel.transactionPriority);

    await showPopUp<void>(
        builder: (_) => Picker(
          items: items,
          displayItem: sendViewModel.displayFeeRate,
          selectedAtIndex: selectedItem,
          title: S.of(context).please_select,
          mainAxisAlignment: MainAxisAlignment.center,
          onItemSelected: (TransactionPriority priority) =>
              sendViewModel.setTransactionPriority(priority),
        ),
        context: context);
  }

  @override
  bool get wantKeepAlive => true;
}