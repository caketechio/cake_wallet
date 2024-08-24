import 'package:cake_wallet/entities/wallet_list_order_types.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/filter_list_widget.dart';
import 'package:cake_wallet/src/screens/wallet_list/filtered_list.dart';
import 'package:cake_wallet/src/screens/wallet_unlock/wallet_unlock_arguments.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/themes/extensions/filter_theme.dart';
import 'package:cake_wallet/themes/extensions/receive_page_theme.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';

class WalletListPage extends BasePage {
  WalletListPage({required this.walletListViewModel, required this.authService});

  final WalletListViewModel walletListViewModel;
  final AuthService authService;

  @override
  String get title => S.current.wallets;

  @override
  Widget body(BuildContext context) =>
      WalletListBody(walletListViewModel: walletListViewModel, authService: authService);

  @override
  Widget trailing(BuildContext context) {
    final filterIcon = Image.asset('assets/images/filter_icon.png',
        color: Theme.of(context).extension<FilterTheme>()!.iconColor);
    return MergeSemantics(
      child: SizedBox(
        height: 37,
        width: 37,
        child: ButtonTheme(
          minWidth: double.minPositive,
          child: Semantics(
            container: true,
            child: GestureDetector(
              onTap: () async {
                await showPopUp<void>(
                  context: context,
                  builder: (context) => FilterListWidget(
                    initalType: walletListViewModel.orderType,
                    initalAscending: walletListViewModel.ascending,
                    onClose: (bool ascending, WalletListOrderType type) async {
                      walletListViewModel.setAscending(ascending);
                      await walletListViewModel.setOrderType(type);
                    },
                  ),
                );
              },
              child: Semantics(
                label: 'Transaction Filter',
                button: true,
                enabled: true,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).extension<FilterTheme>()!.buttonColor,
                  ),
                  child: filterIcon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WalletListBody extends StatefulWidget {
  WalletListBody({required this.walletListViewModel, required this.authService});

  final WalletListViewModel walletListViewModel;
  final AuthService authService;

  @override
  WalletListBodyState createState() => WalletListBodyState();
}

class WalletListBodyState extends State<WalletListBody> {
  final moneroIcon = Image.asset('assets/images/monero_logo.png', height: 24, width: 24);
  final bitcoinIcon = Image.asset('assets/images/bitcoin.png', height: 24, width: 24);
  final lightningIcon = Image.asset('assets/images/lightning_logo.png', height: 24, width: 24);
  final tBitcoinIcon = Image.asset('assets/images/tbtc.png', height: 24, width: 24);
  final litecoinIcon = Image.asset('assets/images/litecoin_icon.png', height: 24, width: 24);
  final nonWalletTypeIcon = Image.asset('assets/images/close.png', height: 24, width: 24);
  final havenIcon = Image.asset('assets/images/haven_logo.png', height: 24, width: 24);
  final ethereumIcon = Image.asset('assets/images/eth_icon.png', height: 24, width: 24);
  final bitcoinCashIcon = Image.asset('assets/images/bch_icon.png', height: 24, width: 24);
  final nanoIcon = Image.asset('assets/images/nano_icon.png', height: 24, width: 24);
  final polygonIcon = Image.asset('assets/images/matic_icon.png', height: 24, width: 24);
  final solanaIcon = Image.asset('assets/images/sol_icon.png', height: 24, width: 24);
  final tronIcon = Image.asset('assets/images/trx_icon.png', height: 24, width: 24);
  final wowneroIcon = Image.asset('assets/images/wownero_icon.png', height: 24, width: 24);
  final scrollController = ScrollController();
  final double tileHeight = 60;
  Flushbar<void>? _progressBar;

  @override
  Widget build(BuildContext context) {
    final newWalletImage =
        Image.asset('assets/images/new_wallet.png', height: 12, width: 12, color: Colors.white);
    final restoreWalletImage = Image.asset('assets/images/restore_wallet.png',
        height: 12,
        width: 12,
        color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor);

    return Container(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              child: Observer(
                builder: (_) => FilteredList(
                  list: widget.walletListViewModel.wallets,
                  updateFunction: widget.walletListViewModel.reorderAccordingToWalletList,
                  itemBuilder: (__, index) {
                    final wallet = widget.walletListViewModel.wallets[index];
                    final currentColor = wallet.isCurrent
                        ? Theme.of(context)
                            .extension<WalletListTheme>()!
                            .createNewWalletButtonBackgroundColor
                        : Theme.of(context).colorScheme.background;
                    final row = GestureDetector(
                      key: ValueKey(wallet.name),
                      onTap: () => wallet.isCurrent ? null : _loadWallet(wallet),
                      child: Container(
                        height: tileHeight,
                        width: double.infinity,
                        child: Row(
                          children: <Widget>[
                            Container(
                              height: tileHeight,
                              width: 4,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(4),
                                      bottomRight: Radius.circular(4)),
                                  color: currentColor),
                            ),
                            Expanded(
                              child: Container(
                                height: tileHeight,
                                padding: EdgeInsets.only(left: 20, right: 20),
                                color: Theme.of(context).colorScheme.background,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    wallet.isEnabled
                                        ? _imageFor(
                                            type: wallet.type,
                                            isTestnet: wallet.isTestnet,
                                          )
                                        : nonWalletTypeIcon,
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        wallet.name,
                                        maxLines: null,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: DeviceInfo.instance.isDesktop ? 18 : 20,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .extension<CakeTextTheme>()!
                                              .titleColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    return wallet.isCurrent
                        ? row
                        : Row(
                            key: ValueKey(wallet.name),
                            children: [
                              Expanded(child: row),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pushNamed(Routes.walletEdit,
                                    arguments: [widget.walletListViewModel, wallet]),
                                child: Container(
                                  padding: EdgeInsets.only(
                                      right: DeviceInfo.instance.isMobile ? 20 : 40),
                                  child: Center(
                                    child: Container(
                                      height: 40,
                                      width: 44,
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context)
                                            .extension<ReceivePageTheme>()!
                                            .iconsBackgroundColor,
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Theme.of(context)
                                            .extension<ReceivePageTheme>()!
                                            .iconsColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                PrimaryImageButton(
                  onPressed: () {
                    //TODO(David): Find a way to optimize this
                    if (isSingleCoin) {
                      if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                        widget.authService.authenticateAction(
                          context,
                          route: Routes.newWallet,
                          arguments: widget.walletListViewModel.currentWalletType,
                          conditionToDetermineIfToUse2FA:
                              widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
                        );
                      } else {
                        Navigator.of(context).pushNamed(
                          Routes.newWallet,
                          arguments: widget.walletListViewModel.currentWalletType,
                        );
                      }
                    } else {
                      if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                        widget.authService.authenticateAction(
                          context,
                          route: Routes.newWalletType,
                          conditionToDetermineIfToUse2FA:
                              widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
                        );
                      } else {
                        Navigator.of(context).pushNamed(Routes.newWalletType);
                      }
                    }
                  },
                  image: newWalletImage,
                  text: S.of(context).wallet_list_create_new_wallet,
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                ),
                SizedBox(height: 10.0),
                PrimaryImageButton(
                  onPressed: () {
                    if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                      widget.authService.authenticateAction(
                        context,
                        route: Routes.restoreOptions,
                        arguments: false,
                        conditionToDetermineIfToUse2FA:
                            widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
                      );
                    } else {
                      Navigator.of(context).pushNamed(Routes.restoreOptions, arguments: false);
                    }
                  },
                  image: restoreWalletImage,
                  text: S.of(context).wallet_list_restore_wallet,
                  color: Theme.of(context).cardColor,
                  textColor: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Image _imageFor({required WalletType type, bool? isTestnet}) {
    switch (type) {
      case WalletType.bitcoin:
        if (isTestnet == true) {
          return tBitcoinIcon;
        }
        return bitcoinIcon;
      case WalletType.lightning:
        return lightningIcon;
      case WalletType.monero:
        return moneroIcon;
      case WalletType.litecoin:
        return litecoinIcon;
      case WalletType.haven:
        return havenIcon;
      case WalletType.ethereum:
        return ethereumIcon;
      case WalletType.bitcoinCash:
        return bitcoinCashIcon;
      case WalletType.nano:
      case WalletType.banano:
        return nanoIcon;
      case WalletType.polygon:
        return polygonIcon;
      case WalletType.solana:
        return solanaIcon;
      case WalletType.tron:
        return tronIcon;
      case WalletType.wownero:
        return wowneroIcon;
      case WalletType.none:
        return nonWalletTypeIcon;
    }
  }

  Future<void> _loadWallet(WalletListItem wallet) async {
    if (SettingsStoreBase.walletPasswordDirectInput) {
      Navigator.of(context).pushNamed(
          Routes.walletUnlockLoadable,
          arguments: WalletUnlockArguments(
              callback: (bool isAuthenticatedSuccessfully, AuthPageState auth) async {
                if (isAuthenticatedSuccessfully) {
                  auth.close();
                  setState(() {});
                }
              }, walletName: wallet.name,
              walletType: wallet.type));
      return;
    }

    await widget.authService.authenticateAction(
      context,
      onAuthSuccess: (isAuthenticatedSuccessfully) async {
        if (!isAuthenticatedSuccessfully) {
          return;
        }

        try {
          changeProcessText(S.of(context).wallet_list_loading_wallet(wallet.name));
          await widget.walletListViewModel.loadWallet(wallet);
          await hideProgressText();
          // only pop the wallets route in mobile as it will go back to dashboard page
          // in desktop platforms the navigation tree is different
          if (responsiveLayoutUtil.shouldRenderMobileUI) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (this.mounted) {
                Navigator.of(context).pop();
              }
            });
          }
        } catch (e) {
          if (this.mounted) {
            changeProcessText(S.of(context).wallet_list_failed_to_load(wallet.name, e.toString()));
          }
        }
      },
      conditionToDetermineIfToUse2FA:
          widget.walletListViewModel.shouldRequireTOTP2FAForAccessingWallet,
    );
  }

  void changeProcessText(String text) {
    _progressBar = createBar<void>(text, duration: null)..show(context);
  }

  Future<void> hideProgressText() async {
    await Future.delayed(Duration(milliseconds: 50), () {
      _progressBar?.dismiss();
      _progressBar = null;
    });
  }
}
