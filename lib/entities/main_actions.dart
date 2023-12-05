import 'package:cake_wallet/buy/moonpay/moonpay_exchange_provider.dart';
import 'package:cake_wallet/buy/moonpay/moonpay_sell_provider.dart';
import 'package:cake_wallet/buy/onramper/onramper_buy_provider.dart';
import 'package:cake_wallet/buy/robinhood/robinhood_buy_provider.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/buy_provider_types.dart';
import 'package:cake_wallet/entities/exchange_provider_types.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MainActions {
  final String Function(BuildContext context) name;
  final String image;

  final bool Function(DashboardViewModel viewModel)? isEnabled;
  final bool Function(DashboardViewModel viewModel)? canShow;
  final Future<void> Function(
      BuildContext context, DashboardViewModel viewModel) onTap;

  MainActions._({
    required this.name,
    required this.image,
    this.isEnabled,
    this.canShow,
    required this.onTap,
  });

  static List<MainActions> all = [
    buyAction,
    receiveAction,
    exchangeAction,
    sendAction,
    sellAction,
  ];

  static MainActions buyAction = MainActions._(
    name: (context) => S.of(context).buy,
    image: 'assets/images/buy.png',
    isEnabled: (viewModel) => viewModel.isEnabledBuyAction,
    canShow: (viewModel) => viewModel.hasBuyAction,
    onTap: (BuildContext context, DashboardViewModel viewModel) async {
      final defaultBuyProvider = viewModel.defaultBuyProvider;
      final walletType = viewModel.type;

      if (!viewModel.isEnabledBuyAction) return;

      switch (walletType) {
        case WalletType.bitcoin:
        case WalletType.litecoin:
        case WalletType.ethereum:
        case WalletType.polygon:
        case WalletType.bitcoinCash:
          switch (defaultBuyProvider) {
            case BuyProviderType.AskEachTime:
              Navigator.pushNamed(context, Routes.buy);
              break;
            case BuyProviderType.Onramper:
              await getIt.get<OnRamperBuyProvider>().launchProvider(context);
              break;
            case BuyProviderType.Robinhood:
              await getIt.get<RobinhoodBuyProvider>().launchProvider(context);
              break;
          }
          break;
        case WalletType.nano:
        case WalletType.banano:
        case WalletType.monero:
          await getIt.get<OnRamperBuyProvider>().launchProvider(context);
          break;
        default:
          await showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: S.of(context).buy,
                    alertContent: S.of(context).unsupported_asset,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
      }
    },
  );

  static MainActions receiveAction = MainActions._(
    name: (context) => S.of(context).receive,
    image: 'assets/images/received.png',
    onTap: (BuildContext context, DashboardViewModel viewModel) async {
      Navigator.pushNamed(context, Routes.addressPage);
    },
  );

  static MainActions exchangeAction = MainActions._(
    name: (context) => S.of(context).exchange,
    image: 'assets/images/transfer.png',
    isEnabled: (viewModel) => viewModel.isEnabledExchangeAction,
    canShow: (viewModel) => viewModel.hasExchangeAction,
    onTap: (BuildContext context, DashboardViewModel viewModel) async {
      if (!viewModel.isEnabledExchangeAction) return;
      final defaultExchangeProvider = viewModel.defaultExchangeProvider;
      final walletType = viewModel.type;

      switch (walletType) {
        case WalletType.ethereum:
          switch (defaultExchangeProvider) {
            case ExchangeProviderType.AskEachTime:
              Navigator.pushNamed(context, Routes.choose_exchange_provider);
              break;
            case ExchangeProviderType.MoonPay:
              await getIt.get<MoonPayExchangeProvider>().launchProvider(context);
              break;
            case ExchangeProviderType.Normal:
              await Navigator.of(context).pushNamed(Routes.exchange);
              break;
          }
          break;
        case WalletType.bitcoin:
        case WalletType.litecoin:
        case WalletType.bitcoinCash:
        case WalletType.nano:
        case WalletType.banano:
        case WalletType.monero:
          await Navigator.of(context).pushNamed(Routes.exchange);
          break;
        default:
          await showPopUp<void>(
              context: context,
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: S.of(context).exchange,
                    alertContent: S.of(context).unsupported_asset,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
          break;
      }
    },
  );

  static MainActions sendAction = MainActions._(
    name: (context) => S.of(context).send,
    image: 'assets/images/upload.png',
    onTap: (BuildContext context, DashboardViewModel viewModel) async {
      Navigator.pushNamed(context, Routes.send);
    },
  );

  static MainActions sellAction = MainActions._(
    name: (context) => S.of(context).sell,
    image: 'assets/images/sell.png',
    isEnabled: (viewModel) => viewModel.isEnabledSellAction,
    canShow: (viewModel) => viewModel.hasSellAction,
    onTap: (BuildContext context, DashboardViewModel viewModel) async {
      final walletType = viewModel.type;

      switch (walletType) {
        case WalletType.bitcoin:
        case WalletType.litecoin:
        case WalletType.ethereum:
        case WalletType.polygon:
        case WalletType.bitcoinCash:
          if (viewModel.isEnabledSellAction) {
            final moonPaySellProvider = MoonPaySellProvider();
            final uri = await moonPaySellProvider.requestUrl(
              currency: viewModel.wallet.currency,
              refundWalletAddress: viewModel.wallet.walletAddresses.address,
              settingsStore: viewModel.settingsStore,
            );
            if (DeviceInfo.instance.isMobile) {
              Navigator.of(context)
                  .pushNamed(Routes.webViewPage, arguments: [S.of(context).sell, uri]);
            } else {
              await launchUrl(uri);
            }
          }

          break;
        default:
          await showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithOneAction(
                  alertTitle: S.of(context).sell,
                  alertContent: S.of(context).unsupported_asset,
                  buttonText: S.of(context).ok,
                  buttonAction: () => Navigator.of(context).pop());
            },
          );
      }
    },
  );
}
