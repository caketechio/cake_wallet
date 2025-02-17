import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/exchange_trade/information_page.dart';
import 'package:cake_wallet/src/widgets/cake_image_widget.dart';
import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/utils/payment_request.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cake_wallet/themes/theme_base.dart';

class BalanceRowWidget extends StatelessWidget {
  BalanceRowWidget({
    required this.availableBalanceLabel,
    required this.availableBalance,
    required this.availableFiatBalance,
    required this.additionalBalanceLabel,
    required this.additionalBalance,
    required this.additionalFiatBalance,
    required this.secondAvailableBalanceLabel,
    required this.secondAvailableBalance,
    required this.secondAvailableFiatBalance,
    required this.secondAdditionalBalanceLabel,
    required this.secondAdditionalBalance,
    required this.secondAdditionalFiatBalance,
    required this.frozenBalance,
    required this.frozenFiatBalance,
    required this.currency,
    required this.hasAdditionalBalance,
    required this.hasSecondAvailableBalance,
    required this.hasSecondAdditionalBalance,
    required this.isTestnet,
    required this.dashboardViewModel,
    super.key,
  });

  final String availableBalanceLabel;
  final String availableBalance;
  final String availableFiatBalance;
  final String additionalBalanceLabel;
  final String additionalBalance;
  final String additionalFiatBalance;
  final String secondAvailableBalanceLabel;
  final String secondAvailableBalance;
  final String secondAvailableFiatBalance;
  final String secondAdditionalBalanceLabel;
  final String secondAdditionalBalance;
  final String secondAdditionalFiatBalance;
  final String frozenBalance;
  final String frozenFiatBalance;
  final CryptoCurrency currency;
  final bool hasAdditionalBalance;
  final bool hasSecondAvailableBalance;
  final bool hasSecondAdditionalBalance;
  final bool isTestnet;
  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    bool brightThemeType = false;
    if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.bright) brightThemeType = true;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(
              color: Theme.of(context).extension<BalancePageTheme>()!.cardBorderColor,
              width: 1,
            ),
            color: Theme.of(context).extension<SyncIndicatorTheme>()!.syncedBackgroundColor,
            // boxShadow: [
            //   BoxShadow(
            //       color: Theme.of(context)
            //           .extension<BalancePageTheme>()!
            //           .cardBorderColor
            //           .withAlpha(50),
            //       spreadRadius: dashboardViewModel.getShadowSpread(),
            //       blurRadius: dashboardViewModel.getShadowBlur())
            // ],
          ),
          child: TextButton(
            onPressed: () => Fluttertoast.showToast(
              msg: S.current.show_balance_toast,
              backgroundColor: Color.fromRGBO(0, 0, 0, 0.85),
            ),
            onLongPress: () => dashboardViewModel.balanceViewModel.switchBalanceValue(),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Container(
              margin: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: hasAdditionalBalance
                                ? () => _showBalanceDescription(
                                    context, S.of(context).available_balance_description)
                                : null,
                            child: Row(
                              children: [
                                Semantics(
                                  hint: 'Double tap to see more information',
                                  container: true,
                                  child: Text('${availableBalanceLabel}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Lato',
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .extension<BalancePageTheme>()!
                                              .labelTextColor,
                                          height: 1)),
                                ),
                                if (hasAdditionalBalance)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.help_outline,
                                        size: 16,
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .labelTextColor),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),
                          AutoSizeText(availableBalance,
                              style: TextStyle(
                                  fontSize: 24,
                                  fontFamily: 'Lato',
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context)
                                      .extension<BalancePageTheme>()!
                                      .balanceAmountColor,
                                  height: 1),
                              maxLines: 1,
                              textAlign: TextAlign.start),
                          SizedBox(height: 6),
                          if (isTestnet)
                            Text(S.of(context).testnet_coins_no_value,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Lato',
                                    fontWeight: FontWeight.w400,
                                    color:
                                        Theme.of(context).extension<BalancePageTheme>()!.textColor,
                                    height: 1)),
                          if (!isTestnet)
                            Text('${availableFiatBalance}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'Lato',
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).extension<BalancePageTheme>()!.textColor,
                                    height: 1)),
                        ],
                      ),
                      SizedBox(
                        //width: min(MediaQuery.of(context).size.width * 0.2, 100),
                        child: Center(
                          child: Column(
                            children: [
                              CakeImageWidget(
                                imageUrl: currency.iconPath,
                                height: 40,
                                width: 40,
                                displayOnError: Container(
                                  height: 30.0,
                                  width: 30.0,
                                  child: Center(
                                    child: Text(
                                      currency.title.substring(0, min(currency.title.length, 2)),
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                currency.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Lato',
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .extension<BalancePageTheme>()!
                                      .assetTitleColor,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  //),
                  if (frozenBalance.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 26),
                        Row(
                          children: [
                            Text(
                              S.of(context).frozen_balance,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Lato',
                                fontWeight: FontWeight.w400,
                                color:
                                    Theme.of(context).extension<BalancePageTheme>()!.labelTextColor,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        AutoSizeText(
                          frozenBalance,
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w400,
                            color:
                                Theme.of(context).extension<BalancePageTheme>()!.balanceAmountColor,
                            height: 1,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        if (!isTestnet)
                          Text(
                            frozenFiatBalance,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Lato',
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).extension<BalancePageTheme>()!.textColor,
                              height: 1,
                            ),
                          ),
                      ],
                    ),
                  if (hasAdditionalBalance)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24),
                        Text(
                          '${additionalBalanceLabel}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).extension<BalancePageTheme>()!.labelTextColor,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 8),
                        AutoSizeText(
                          additionalBalance,
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w400,
                            color: Theme.of(context).extension<BalancePageTheme>()!.assetTitleColor,
                            height: 1,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        if (!isTestnet)
                          Text(
                            '${additionalFiatBalance}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Lato',
                              fontWeight: FontWeight.w400,
                              color: Theme.of(context).extension<BalancePageTheme>()!.textColor,
                              height: 1,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasSecondAdditionalBalance || hasSecondAvailableBalance) ...[
          SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30.0),
              border: Border.all(
                color: Theme.of(context).extension<BalancePageTheme>()!.cardBorderColor,
                width: 1,
              ),
              color: Theme.of(context).extension<SyncIndicatorTheme>()!.syncedBackgroundColor,
              // boxShadow: [
              //   BoxShadow(
              //       color: Theme.of(context)
              //           .extension<BalancePageTheme>()!
              //           .cardBorderColor
              //           .withAlpha(50),
              //       spreadRadius: dashboardViewModel.getShadowSpread(),
              //       blurRadius: dashboardViewModel.getShadowBlur())
              // ],
            ),
            child: TextButton(
              onPressed: () => Fluttertoast.showToast(
                msg: S.current.show_balance_toast,
                backgroundColor: Color.fromRGBO(0, 0, 0, 0.85),
              ),
              onLongPress: () => dashboardViewModel.balanceViewModel.switchBalanceValue(),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, left: 12, right: 12, bottom: 10),
                    child: Stack(
                      children: [
                        if (currency == CryptoCurrency.ltc)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                child: Column(
                                  children: [
                                    Container(
                                      child: ImageIcon(
                                        AssetImage('assets/images/mweb_logo.png'),
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .assetTitleColor,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'MWEB',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontFamily: 'Lato',
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .assetTitleColor,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (hasSecondAvailableBalance)
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => launchUrl(
                                      Uri.parse(
                                          "https://docs.cakewallet.com/cryptos/litecoin#mweb"),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${secondAvailableBalanceLabel}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'Lato',
                                            fontWeight: FontWeight.w400,
                                            color: Theme.of(context)
                                                .extension<BalancePageTheme>()!
                                                .labelTextColor,
                                            height: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Icon(Icons.help_outline,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .extension<BalancePageTheme>()!
                                                  .labelTextColor),
                                        )
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  AutoSizeText(
                                    secondAvailableBalance,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Lato',
                                      fontWeight: FontWeight.w900,
                                      color: Theme.of(context)
                                          .extension<BalancePageTheme>()!
                                          .assetTitleColor,
                                      height: 1,
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6),
                                  if (!isTestnet)
                                    Text(
                                      '${secondAvailableFiatBalance}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'Lato',
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .textColor,
                                        height: 1,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 0, left: 24, right: 8, bottom: 16),
                    child: Stack(
                      children: [
                        if (hasSecondAdditionalBalance)
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 24),
                                  Text(
                                    '${secondAdditionalBalanceLabel}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Lato',
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context)
                                          .extension<BalancePageTheme>()!
                                          .labelTextColor,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  AutoSizeText(
                                    secondAdditionalBalance,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: 'Lato',
                                      fontWeight: FontWeight.w400,
                                      color: Theme.of(context)
                                          .extension<BalancePageTheme>()!
                                          .assetTitleColor,
                                      height: 1,
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 4),
                                  if (!isTestnet)
                                    Text(
                                      '${secondAdditionalFiatBalance}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Lato',
                                        fontWeight: FontWeight.w400,
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .textColor,
                                        height: 1,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IntrinsicHeight(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Semantics(
                              label: S.of(context).litecoin_mweb_pegin,
                              child: OutlinedButton(
                                onPressed: () {
                                  final mwebAddress =
                                      bitcoin!.getUnusedMwebAddress(dashboardViewModel.wallet);
                                  PaymentRequest? paymentRequest = null;
                                  if ((mwebAddress?.isNotEmpty ?? false)) {
                                    paymentRequest = PaymentRequest.fromUri(
                                        Uri.parse("litecoin:${mwebAddress}"));
                                  }
                                  Navigator.pushNamed(
                                    context,
                                    Routes.send,
                                    arguments: {
                                      'paymentRequest': paymentRequest,
                                      'coinTypeToSpendFrom': UnspentCoinType.nonMweb,
                                    },
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade400.withAlpha(50),
                                  side: BorderSide(
                                      color: Colors.grey.shade400.withAlpha(50), width: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        height: 30,
                                        width: 30,
                                        'assets/images/received.png',
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .balanceAmountColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        S.of(context).litecoin_mweb_pegin,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .extension<BalancePageTheme>()!
                                              .textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 24),
                          Expanded(
                            child: Semantics(
                              label: S.of(context).litecoin_mweb_pegout,
                              child: OutlinedButton(
                                onPressed: () {
                                  final litecoinAddress =
                                      bitcoin!.getUnusedSegwitAddress(dashboardViewModel.wallet);
                                  PaymentRequest? paymentRequest = null;
                                  if ((litecoinAddress?.isNotEmpty ?? false)) {
                                    paymentRequest = PaymentRequest.fromUri(
                                        Uri.parse("litecoin:${litecoinAddress}"));
                                  }
                                  Navigator.pushNamed(
                                    context,
                                    Routes.send,
                                    arguments: {
                                      'paymentRequest': paymentRequest,
                                      'coinTypeToSpendFrom': UnspentCoinType.mweb,
                                    },
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade400.withAlpha(50),
                                  side: BorderSide(
                                      color: Colors.grey.shade400.withAlpha(50), width: 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        height: 30,
                                        width: 30,
                                        'assets/images/upload.png',
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .balanceAmountColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        S.of(context).litecoin_mweb_pegout,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .extension<BalancePageTheme>()!
                                              .textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  //  double getShadowSpread(){
  //   double spread = 3;
  //   if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.bright) spread = 3;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.light) spread = 3;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.dark) spread = 1;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.oled) spread = 3;
  //   return spread;
  // }
  //
  //
  // double getShadowBlur(){
  //   double blur = 7;
  //   if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.bright) blur = 7;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.light) blur = 7;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.dark) blur = 3;
  //   else if (dashboardViewModel.settingsStore.currentTheme.type == ThemeType.oled) blur = 7;
  //   return blur;
  // }

  void _showBalanceDescription(BuildContext context, String content) {
    showPopUp<void>(context: context, builder: (_) => InformationPage(information: content));
  }
}
