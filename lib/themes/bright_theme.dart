import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/themes/extensions/filter_theme.dart';
import 'package:cake_wallet/themes/extensions/indicator_dot_theme.dart';
import 'package:cake_wallet/themes/extensions/menu_theme.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/order_theme.dart';
import 'package:cake_wallet/themes/extensions/placeholder_theme.dart';
import 'package:cake_wallet/themes/extensions/qr_code_theme.dart';
import 'package:cake_wallet/themes/extensions/receive_page_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/themes/extensions/transaction_trade_theme.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';
import 'package:cake_wallet/themes/light_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/palette.dart';
import 'package:flutter/material.dart';

class BrightTheme extends LightTheme {
  BrightTheme({required int raw}) : super(raw: raw);

  @override
  String get title => S.current.bright_theme;
  @override
  ThemeType get type => ThemeType.bright;
  @override
  Color get primaryColor => Palette.moderateSlateBlue;
  @override
  Color get containerColor => Palette.moderateLavender;

  @override
  DashboardPageTheme get dashboardPageTheme =>
      super.dashboardPageTheme.copyWith(
          firstGradientBackgroundColor: Palette.blueCraiola,
          secondGradientBackgroundColor: Palette.pinkFlamingo,
          thirdGradientBackgroundColor: Palette.redHat,
          pageTitleTextColor: Colors.white,
          mainActionsIconColor: Colors.white,
          textColor: Colors.white,
          cardTextColor: Colors.white,
          indicatorDotTheme: IndicatorDotTheme(
              indicatorColor: Colors.white.withOpacity(0.5),
              activeIndicatorColor: Colors.white));

  @override
  SyncIndicatorTheme get syncIndicatorStyle =>
      super.syncIndicatorStyle.copyWith(
          textColor: Colors.white,
          syncedBackgroundColor: Colors.white.withOpacity(0.2),
          notSyncedBackgroundColor: Colors.grey.withOpacity(0.15));

  @override
  ExchangePageTheme get exchangePageTheme => super.exchangePageTheme.copyWith(
      secondGradientBottomPanelColor: Palette.pinkFlamingo.withOpacity(0.7),
      firstGradientBottomPanelColor: Palette.blueCraiola.withOpacity(0.7),
      secondGradientTopPanelColor: Palette.pinkFlamingo,
      firstGradientTopPanelColor: Palette.blueCraiola);

  @override
  NewWalletTheme get newWalletTheme => super.newWalletTheme.copyWith(
      hintTextColor: Palette.darkGray,
      underlineColor: Palette.periwinkleCraiola);

  @override
  BalancePageTheme get balancePageTheme => super
      .balancePageTheme
      .copyWith(labelTextColor: Colors.white.withOpacity(0.5));

  @override
  CakeMenuTheme get menuTheme =>
      super.menuTheme.copyWith(headerSecondGradientColor: Palette.pinkFlamingo);

  @override
  FilterTheme get filterTheme => super.filterTheme.copyWith(
      checkboxSecondGradientColor: Palette.pinkFlamingo,
      checkboxBackgroundColor: Colors.white,
      buttonColor: Palette.darkGray.withOpacity(0.2),
      iconColor: Colors.white);

  @override
  WalletListTheme get walletListTheme => super.walletListTheme.copyWith(
      createNewWalletButtonBackgroundColor: Palette.moderateSlateBlue);

  @override
  OrderTheme get orderTheme => OrderTheme(iconColor: Colors.white);

  @override
  SendPageTheme get sendPageTheme => super.sendPageTheme.copyWith(
      templateBackgroundColor: Palette.shadowWhite,
      templateDottedBorderColor: Palette.shadowWhite,
      secondGradientColor: Palette.pinkFlamingo);

  @override
  PlaceholderTheme get placeholderTheme =>
      PlaceholderTheme(color: Colors.white.withOpacity(0.5));

  @override
  TransactionTradeTheme get transactionTradeTheme => super
      .transactionTradeTheme
      .copyWith(rowsColor: Colors.white.withOpacity(0.2));

  @override
  ReceivePageTheme get receivePageTheme => super.receivePageTheme.copyWith(
        currentTileBackgroundColor: Palette.moderateSlateBlue,
        tilesBackgroundColor: Colors.white,
        iconsBackgroundColor: Palette.lavender,
        amountBottomBorderColor: Colors.white.withOpacity(0.5),
        amountHintTextColor: Colors.white,
      );

  @override
  QRCodeTheme get qrCodeTheme => super
      .qrCodeTheme
      .copyWith(qrWidgetCopyButtonColor: Colors.white.withOpacity(0.4));

  @override
  CakeTextTheme get cakeTextTheme => super.cakeTextTheme.copyWith(
      buttonSecondaryTextColor: super.cakeTextTheme.secondaryTextColor,
      buttonTextColor: super.cakeTextTheme.titleColor,
      addressButtonBorderColor: Colors.white.withOpacity(0.4),
      dateSectionRowColor: Colors.white.withOpacity(0.5));
}
