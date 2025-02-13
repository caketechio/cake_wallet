import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/themes/extensions/qr_code_theme.dart';
import 'package:cake_wallet/src/widgets/check_box_picker.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/view_model/exchange/exchange_view_model.dart';

class PresentProviderPicker extends StatelessWidget {
  PresentProviderPicker({required this.exchangeViewModel});

  final ExchangeViewModel exchangeViewModel;

  @override
  Widget build(BuildContext context) {
    final arrowBottom = Image.asset(
        'assets/images/arrow_bottom_purple_icon.png',
        color: Colors.white,
        height: 6);

    return TextButton(
        onPressed: () => presentProviderPicker(context),
        style: ButtonStyle(
          padding: MaterialStateProperty.all(EdgeInsets.zero),
          splashFactory: NoSplash.splashFactory,
          foregroundColor: MaterialStateProperty.all(Colors.transparent),
          overlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(S.of(context).exchange,
                    style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Observer(
                    builder: (_) => Text(
                        exchangeViewModel.selectedProviders.isEmpty
                            ? S.of(context).choose_one
                            : exchangeViewModel.selectedProviders.length > 1
                              ? S.of(context).automatic
                              : exchangeViewModel.selectedProviders.first.title,
                            style: TextStyle(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).extension<QRCodeTheme>()!.qrCodeColor)))
              ],
            ),
            SizedBox(width: 5),
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: arrowBottom,
            )
          ],
        ));
  }

  void presentProviderPicker(BuildContext context) async {
    await showPopUp<void>(
        builder: (BuildContext popUpContext) => CheckBoxPicker(
            items: exchangeViewModel.providerList
                .map((e) => CheckBoxItem(
                      e.title,
                      exchangeViewModel.selectedProviders.contains(e),
                      isDisabled: !exchangeViewModel.providersForCurrentPair().contains(e),
                    ))
                .toList(),
            title: S.of(context).change_exchange_provider,
            onChanged: (int index, bool value) {
              if (!exchangeViewModel.providerList[index].isAvailable) {
                showPopUp<void>(
                    builder: (BuildContext popUpContext) => AlertWithOneAction(
                        alertTitle: 'Error',
                        alertContent: 'The exchange is blocked in your region.',
                        buttonText: S.of(context).ok,
                        buttonAction: () => Navigator.of(context).pop()),
                    context: context);
                return;
              }
              if (value) {
                exchangeViewModel.addExchangeProvider(exchangeViewModel.providerList[index]);
              } else {
                exchangeViewModel.removeExchangeProvider(exchangeViewModel.providerList[index]);
              }
            }),
        context: context);

    exchangeViewModel.saveSelectedProviders();
  }
}
