import 'dart:async';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/balance/balance_row_widget.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/home_screen_account_widget.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/src/widgets/dashboard_card_widget.dart';
import 'package:cake_wallet/src/widgets/introducing_card.dart';
import 'package:cake_wallet/src/widgets/standard_switch.dart';
import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:url_launcher/url_launcher.dart';

class CryptoBalanceWidget extends StatelessWidget {
  const CryptoBalanceWidget({
    super.key,
    required this.dashboardViewModel,
  });

  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Observer(
            builder: (_) {
              if (dashboardViewModel.getMoneroError != null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DashBoardRoundedCardWidget(
                    title: "Invalid monero bindings",
                    subTitle: dashboardViewModel.getMoneroError.toString(),
                  ),
                );
              }
              return Container();
            },
          ),
          Observer(
            builder: (_) {
              if (dashboardViewModel.getWowneroError != null) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DashBoardRoundedCardWidget(
                      title: "Invalid wownero bindings",
                      subTitle: dashboardViewModel.getWowneroError.toString(),
                    ));
              }
              return Container();
            },
          ),
          Observer(
              builder: (_) => dashboardViewModel.balanceViewModel.hasAccounts
                  ? HomeScreenAccountWidget(
                      walletName: dashboardViewModel.name, accountName: dashboardViewModel.subname)
                  : Column(
                      children: [
                        SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.only(left: 24, bottom: 16),
                          child: Observer(
                            builder: (_) {
                              return Row(
                                children: [
                                  Text(
                                    dashboardViewModel.balanceViewModel.asset,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Lato',
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .extension<DashboardPageTheme>()!
                                          .pageTitleTextColor,
                                      height: 1,
                                    ),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (dashboardViewModel.wallet.isHardwareWallet)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.asset(
                                        'assets/images/hardware_wallet/ledger_nano_x.png',
                                        width: 24,
                                        color: Theme.of(context)
                                            .extension<DashboardPageTheme>()!
                                            .pageTitleTextColor,
                                      ),
                                    ),
                                  if (dashboardViewModel
                                      .balanceViewModel.isHomeScreenSettingsEnabled)
                                    InkWell(
                                      onTap: () => Navigator.pushNamed(context, Routes.homeSettings,
                                          arguments: dashboardViewModel.balanceViewModel),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.asset(
                                          'assets/images/home_screen_settings_icon.png',
                                          color: Theme.of(context)
                                              .extension<DashboardPageTheme>()!
                                              .pageTitleTextColor,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    )),
          Observer(
            builder: (_) {
              if (dashboardViewModel.balanceViewModel.isShowCard && FeatureFlag.isCakePayEnabled) {
                return IntroducingCard(
                    title: S.of(context).introducing_cake_pay,
                    subTitle: S.of(context).cake_pay_learn_more,
                    borderColor: Theme.of(context).extension<BalancePageTheme>()!.cardBorderColor,
                    closeCard: dashboardViewModel.balanceViewModel.disableIntroCakePayCard);
              }
              return Container();
            },
          ),
          Observer(builder: (_) {
            if (!dashboardViewModel.showRepWarning) {
              return const SizedBox();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DashBoardRoundedCardWidget(
                title: S.of(context).rep_warning,
                subTitle: S.of(context).rep_warning_sub,
                onTap: () => Navigator.of(context).pushNamed(Routes.changeRep),
                onClose: () {
                  dashboardViewModel.settingsStore.shouldShowRepWarning = false;
                },
              ),
            );
          }),
          Observer(
            builder: (_) {
              return ListView.separated(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                separatorBuilder: (_, __) => Container(padding: EdgeInsets.only(bottom: 16)),
                itemCount: dashboardViewModel.balanceViewModel.formattedBalances.length,
                itemBuilder: (__, index) {
                  final balance =
                      dashboardViewModel.balanceViewModel.formattedBalances.elementAt(index);
                  return Observer(builder: (_) {
                    return BalanceRowWidget(
                      dashboardViewModel: dashboardViewModel,
                      availableBalanceLabel:
                          '${dashboardViewModel.balanceViewModel.availableBalanceLabel}',
                      availableBalance: balance.availableBalance,
                      availableFiatBalance: balance.fiatAvailableBalance,
                      additionalBalanceLabel:
                          '${dashboardViewModel.balanceViewModel.additionalBalanceLabel}',
                      additionalBalance: balance.additionalBalance,
                      additionalFiatBalance: balance.fiatAdditionalBalance,
                      frozenBalance: balance.frozenBalance,
                      frozenFiatBalance: balance.fiatFrozenBalance,
                      currency: balance.asset,
                      hasAdditionalBalance:
                          dashboardViewModel.balanceViewModel.hasAdditionalBalance(balance.asset),
                      hasSecondAdditionalBalance:
                          dashboardViewModel.balanceViewModel.hasSecondAdditionalBalance,
                      hasSecondAvailableBalance:
                          dashboardViewModel.balanceViewModel.hasSecondAvailableBalance,
                      secondAdditionalBalance: balance.secondAdditionalBalance,
                      secondAdditionalFiatBalance: balance.fiatSecondAdditionalBalance,
                      secondAvailableBalance: balance.secondAvailableBalance,
                      secondAvailableFiatBalance: balance.fiatSecondAvailableBalance,
                      secondAdditionalBalanceLabel:
                          '${dashboardViewModel.balanceViewModel.secondAdditionalBalanceLabel}',
                      secondAvailableBalanceLabel:
                          '${dashboardViewModel.balanceViewModel.secondAvailableBalanceLabel}',
                      isTestnet: dashboardViewModel.isTestnet,
                    );
                  });
                },
              );
            },
          ),
          Observer(builder: (context) {
            return Column(
              children: [
                if (dashboardViewModel.isMoneroWalletBrokenReasons.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: DashBoardRoundedCardWidget(
                        customBorder: 30,
                        title: "This wallet has encountered an issue",
                        subTitle: "Here are the things that you should note:\n - " +
                            dashboardViewModel.isMoneroWalletBrokenReasons.join("\n - ") +
                            "\n\nPlease restart your wallet and if it doesn't help contact our support.",
                      ))
                ],
                if (dashboardViewModel.showSilentPaymentsCard) ...[
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: DashBoardRoundedCardWidget(
                      shadowBlur: dashboardViewModel.getShadowBlur(),
                      shadowSpread: dashboardViewModel.getShadowSpread(),
                      marginV: 0,
                      marginH: 0,
                      customBorder: 30,
                      title: S.of(context).silent_payments,
                      subTitle: S.of(context).enable_silent_payments_scanning,
                      hint: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => launchUrl(
                                  Uri.parse(
                                      "https://docs.cakewallet.com/cryptos/bitcoin#silent-payments"),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      S.of(context).what_is_silent_payments,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'Lato',
                                        fontWeight: FontWeight.w400,
                                        color: Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .labelTextColor,
                                        height: 1,
                                      ),
                                      softWrap: true,
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
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Semantics(
                                  label: S.of(context).receive,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.addressPage,
                                        arguments: {
                                          'addressType': bitcoin!
                                              .getBitcoinReceivePageOptions()
                                              .where(
                                                (option) => option.value == "Silent Payments",
                                              )
                                              .first
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
                                            S.of(context).receive,
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
                                  label: S.of(context).scan,
                                  child: OutlinedButton(
                                    onPressed: () => _toggleSilentPaymentsScanning(context),
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
                                          Observer(
                                            builder: (_) => StandardSwitch(
                                              value:
                                                  dashboardViewModel.silentPaymentsScanningActive,
                                              onTaped: () => _toggleSilentPaymentsScanning(context),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            S.of(context).scan,
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
                        ],
                      ),
                      onTap: () => _toggleSilentPaymentsScanning(context),
                      icon: Icon(
                        Icons.lock,
                        color:
                            Theme.of(context).extension<DashboardPageTheme>()!.pageTitleTextColor,
                        size: 50,
                      ),
                    ),
                  ),
                ],
                if (dashboardViewModel.showMwebCard) ...[
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: DashBoardRoundedCardWidget(
                      marginV: 0,
                      marginH: 0,
                      customBorder: 30,
                      title: S.of(context).litecoin_mweb,
                      subTitle: S.of(context).litecoin_mweb_description,
                      hint: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => launchUrl(
                              Uri.parse("https://docs.cakewallet.com/cryptos/litecoin/#mweb"),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text(
                              S.of(context).learn_more,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Lato',
                                fontWeight: FontWeight.w400,
                                color:
                                    Theme.of(context).extension<BalancePageTheme>()!.labelTextColor,
                                height: 1,
                              ),
                              softWrap: true,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _dismissMweb(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                  ),
                                  child: Text(
                                    S.of(context).litecoin_mweb_dismiss,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _enableMweb(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text(
                                    S.of(context).enable,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ImageIcon(
                          AssetImage('assets/images/mweb_logo.png'),
                          color: Color.fromARGB(255, 11, 70, 129),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 150),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _toggleSilentPaymentsScanning(BuildContext context) async {
    final isSilentPaymentsScanningActive = dashboardViewModel.silentPaymentsScanningActive;
    final newValue = !isSilentPaymentsScanningActive;
    final willScan = newValue == true;
    dashboardViewModel.silentPaymentsScanningActive = newValue;

    if (willScan) {
      late bool isElectrsSPEnabled;
      try {
        isElectrsSPEnabled = await bitcoin!
            .getNodeIsElectrsSPEnabled(dashboardViewModel.wallet)
            .timeout(const Duration(seconds: 3));
      } on TimeoutException {
        isElectrsSPEnabled = false;
      }

      final needsToSwitch = isElectrsSPEnabled == false;
      if (needsToSwitch) {
        return showPopUp<void>(
          context: context,
          builder: (BuildContext context) => AlertWithTwoActions(
            alertTitle: S.of(context).change_current_node_title,
            alertContent: S.of(context).confirm_silent_payments_switch_node,
            rightButtonText: S.of(context).confirm,
            leftButtonText: S.of(context).cancel,
            actionRightButton: () {
              dashboardViewModel.allowSilentPaymentsScanning(true);
              dashboardViewModel.setSilentPaymentsScanning(true);
              Navigator.of(context).pop();
            },
            actionLeftButton: () {
              dashboardViewModel.silentPaymentsScanningActive = isSilentPaymentsScanningActive;
              Navigator.of(context).pop();
            },
          ),
        );
      }
    }

    return dashboardViewModel.setSilentPaymentsScanning(newValue);
  }

  Future<void> _enableMweb(BuildContext context) async {
    if (!dashboardViewModel.hasEnabledMwebBefore) {
      await showPopUp<void>(
          context: context,
          builder: (BuildContext context) => AlertWithOneAction(
                alertTitle: S.of(context).alert_notice,
                alertContent: S.of(context).litecoin_mweb_warning,
                buttonText: S.of(context).understand,
                buttonAction: () {
                  Navigator.of(context).pop();
                },
              ));
    }
    dashboardViewModel.setMwebEnabled();
  }

  Future<void> _dismissMweb(BuildContext context) async {
    await showPopUp<void>(
        context: context,
        builder: (BuildContext context) => AlertWithOneAction(
              alertTitle: S.of(context).alert_notice,
              alertContent: S.of(context).litecoin_mweb_enable_later,
              buttonText: S.of(context).understand,
              buttonAction: () {
                Navigator.of(context).pop();
              },
            ));
    dashboardViewModel.dismissMweb();
  }
}
