import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/themes/extensions/receive_page_theme.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:cw_core/currency_for_wallet_type.dart';
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
import 'package:flutter_svg/flutter_svg.dart';

class WalletListPage extends BasePage {
  WalletListPage({required this.walletListViewModel, required this.authService});

  final WalletListViewModel walletListViewModel;
  final AuthService authService;

  @override
  String get title => S.current.wallets;

  @override
  Widget body(BuildContext context) =>
      WalletListBody(walletListViewModel: walletListViewModel, authService: authService);
}

class WalletListBody extends StatefulWidget {
  WalletListBody({required this.walletListViewModel, required this.authService});

  final WalletListViewModel walletListViewModel;
  final AuthService authService;

  @override
  WalletListBodyState createState() => WalletListBodyState();
}

class WalletListBodyState extends State<WalletListBody> {
  final nonWalletTypeIcon = Image.asset('assets/images/close.png', height: 24, width: 24);
  final havenIcon = Image.asset('assets/images/haven_logo.png', height: 24, width: 24);
  final ethereumIcon = Image.asset('assets/images/eth_icon.png', height: 24, width: 24);
  final bitcoinCashIcon = Image.asset('assets/images/bch_icon.png', height: 24, width: 24);
  final nanoIcon = Image.asset('assets/images/nano_icon.png', height: 24, width: 24);
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
                builder: (_) => ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (_, index) =>
                      Divider(color: Theme.of(context).colorScheme.background, height: 32),
                  itemCount: widget.walletListViewModel.wallets.length,
                  itemBuilder: (__, index) {
                    final wallet = widget.walletListViewModel.wallets[index];
                    final currentColor = wallet.isCurrent
                        ? Theme.of(context)
                            .extension<WalletListTheme>()!
                            .createNewWalletButtonBackgroundColor
                        : Theme.of(context).colorScheme.background;
                    final row = GestureDetector(
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
                                        ? buildIconFromPath(currencyForWalletType(wallet.type).iconPath)
                                        : nonWalletTypeIcon,
                                    SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        wallet.name,
                                        maxLines: null,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 22,
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
                            children: [
                              Expanded(child: row),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pushNamed(Routes.walletEdit,
                                    arguments: [widget.walletListViewModel, wallet]),
                                child: Container(
                                  padding: EdgeInsets.only(right: 20),
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
  
  Widget buildIconFromPath(String? iconPath) {
    if (iconPath != null && iconPath.contains('svg')) {
      return SvgPicture.asset(
        iconPath,
        height: 24,
        width: 24,
        fit: BoxFit.contain,
      );
    } else {
      return Image.asset(
        iconPath ?? '',
        height: 24,
        width: 24,
      );
    }
  }


  Future<void> _loadWallet(WalletListItem wallet) async {
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
          if (ResponsiveLayoutUtil.instance.shouldRenderMobileUI()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
          }
        } catch (e) {
          changeProcessText(S.of(context).wallet_list_failed_to_load(wallet.name, e.toString()));
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
