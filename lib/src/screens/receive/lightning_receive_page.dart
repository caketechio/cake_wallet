import 'package:cake_wallet/entities/qr_view_data.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/present_receive_option_picker.dart';
import 'package:cake_wallet/src/screens/receive/widgets/qr_image.dart';
import 'package:cake_wallet/src/widgets/gradient_background.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/qr_code_theme.dart';
import 'package:cake_wallet/utils/brightness_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/dashboard/receive_option_view_model.dart';
import 'package:cake_wallet/view_model/lightning_view_model.dart';
import 'package:cw_core/receive_page_option.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

class LightningReceiveOnchainPage extends BasePage {
  LightningReceiveOnchainPage(
      {required this.addressListViewModel,
      required this.receiveOptionViewModel,
      required this.lightningViewModel})
      : _amountController = TextEditingController(),
        _formKey = GlobalKey<FormState>() {
    _amountController.addListener(() {
      if (_formKey.currentState!.validate()) {
        addressListViewModel.changeAmount(_amountController.text);
      }
    });
  }

  final WalletAddressListViewModel addressListViewModel;
  final ReceiveOptionViewModel receiveOptionViewModel;
  final LightningViewModel lightningViewModel;
  final TextEditingController _amountController;
  final GlobalKey<FormState> _formKey;

  bool effectsInstalled = false;

  @override
  String get title => S.current.receive;

  @override
  bool get gradientBackground => true;

  @override
  bool get resizeToAvoidBottomInset => true;

  @override
  Widget middle(BuildContext context) => PresentReceiveOptionPicker(
      color: titleColor(context), receiveOptionViewModel: receiveOptionViewModel);

  @override
  Widget Function(BuildContext, Widget) get rootWrapper =>
      (BuildContext context, Widget scaffold) => GradientBackground(scaffold: scaffold);

  @override
  Widget body(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _setReactions(context));
    final copyImage = Image.asset('assets/images/copy_address.png',
        color: Theme.of(context).extension<QRCodeTheme>()!.qrWidgetCopyButtonColor);
    String heroTag = "lightning_receive";
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FutureBuilder(
          future: lightningViewModel.receiveOnchain(),
          builder: ((context, snapshot) {
            if (snapshot.data == null) {
              return CircularProgressIndicator();
            }
            ReceiveOnchainResult results = snapshot.data as ReceiveOnchainResult;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    S.of(context).qr_fullscreen,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).extension<DashboardPageTheme>()!.textColor),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Spacer(flex: 3),
                    Observer(
                      builder: (_) => Flexible(
                        flex: 5,
                        child: GestureDetector(
                          onTap: () {
                            BrightnessUtil.changeBrightnessForFunction(
                              () async {
                                await Navigator.pushNamed(context, Routes.fullscreenQR,
                                    arguments: QrViewData(
                                      data: results.bitcoinAddress,
                                      heroTag: heroTag,
                                    ));
                              },
                            );
                          },
                          child: Hero(
                            tag: Key(heroTag),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      width: 3,
                                      color: Theme.of(context)
                                          .extension<DashboardPageTheme>()!
                                          .textColor,
                                    ),
                                  ),
                                  child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          width: 3,
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: QrImage(data: results.bitcoinAddress)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Spacer(flex: 3)
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 8, left: 24, right: 24),
                  child: Builder(
                    builder: (context) => Observer(
                      builder: (context) => GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: results.bitcoinAddress));
                          showBar<void>(context, S.of(context).copied_to_clipboard);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                results.bitcoinAddress,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .extension<DashboardPageTheme>()!
                                        .textColor),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: copyImage,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          }),
        ),
        Container(
          padding: const EdgeInsets.only(top: 24, bottom: 24, right: 6),
          margin: const EdgeInsets.symmetric(horizontal: 24),
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
                  future: lightningViewModel.receiveOnchain(),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return Expanded(
                          child: Container(child: Center(child: CircularProgressIndicator())));
                    }
                    ReceiveOnchainResult results = snapshot.data as ReceiveOnchainResult;
                    return Expanded(
                      child: Text(
                        S.of(context).lightning_receive_limits(
                              lightning!.satsToLightningString(results.minAllowedDeposit),
                              lightning!.satsToLightningString(results.maxAllowedDeposit),
                              results.feePercent.toString(),
                              lightning!.satsToLightningString(results.fee),
                            ),
                        maxLines: 10,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                        ),
                      ),
                    );
                  }),
            ],
          ),
        ),
      ],
    );
  }

  void _setReactions(BuildContext context) {
    if (effectsInstalled) {
      return;
    }

    reaction((_) => receiveOptionViewModel.selectedReceiveOption, (ReceivePageOption option) async {
      if (option == lightning!.getOptionInvoice()) {
        Navigator.popAndPushNamed(
          context,
          Routes.lightningInvoice,
          arguments: [lightning!.getOptionInvoice()],
        );
      }
    });

    effectsInstalled = true;
  }
}
