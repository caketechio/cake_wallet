import 'package:another_flushbar/flushbar.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/entities/desktop_dropdown_item.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/dropdown_item_widget.dart';
import 'package:cake_wallet/src/screens/wallet_unlock/wallet_unlock_arguments.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/menu_theme.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class DesktopWalletSelectionDropDown extends StatefulWidget {
  final WalletListViewModel walletListViewModel;
  final AuthService _authService;

  DesktopWalletSelectionDropDown(this.walletListViewModel, this._authService, {Key? key})
      : super(key: key);

  @override
  State<DesktopWalletSelectionDropDown> createState() => _DesktopWalletSelectionDropDownState();
}

class _DesktopWalletSelectionDropDownState extends State<DesktopWalletSelectionDropDown> {
  final moneroIcon = Image.asset('assets/images/monero_logo.png', height: 24, width: 24);
  final bitcoinIcon = Image.asset('assets/images/bitcoin.png', height: 24, width: 24);
  final lightningIcon = Image.asset('assets/images/lightning_logo.png', height: 24, width: 24);
  final tBitcoinIcon = Image.asset('assets/images/tbtc.png', height: 24, width: 24);
  final litecoinIcon = Image.asset('assets/images/litecoin_icon.png', height: 24, width: 24);
  final havenIcon = Image.asset('assets/images/haven_logo.png', height: 24, width: 24);
  final ethereumIcon = Image.asset('assets/images/eth_icon.png', height: 24, width: 24);
  final polygonIcon = Image.asset('assets/images/matic_icon.png', height: 24, width: 24);
  final bitcoinCashIcon = Image.asset('assets/images/bch_icon.png', height: 24, width: 24);
  final nanoIcon = Image.asset('assets/images/nano_icon.png', height: 24, width: 24);
  final bananoIcon = Image.asset('assets/images/nano_icon.png', height: 24, width: 24);
  final solanaIcon = Image.asset('assets/images/sol_icon.png', height: 24, width: 24);
  final tronIcon = Image.asset('assets/images/trx_icon.png', height: 24, width: 24);
  final wowneroIcon = Image.asset('assets/images/wownero_icon.png', height: 24, width: 24);
  final nonWalletTypeIcon = Image.asset('assets/images/close.png', height: 24, width: 24);

  Image _newWalletImage(BuildContext context) => Image.asset(
        'assets/images/new_wallet.png',
        height: 12,
        width: 12,
        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
      );

  Image _restoreWalletImage(BuildContext context) => Image.asset(
        'assets/images/restore_wallet.png',
        height: 12,
        width: 12,
        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
      );

  Flushbar<void>? _progressBar;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    return Observer(builder: (context) {
      final dropDownItems = [
        ...widget.walletListViewModel.wallets
            .map((wallet) => DesktopDropdownItem(
                  isSelected: wallet.isCurrent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 500),
                    child: DropDownItemWidget(
                      title: wallet.name,
                      image: wallet.isEnabled
                          ? _imageFor(type: wallet.type, isTestnet: wallet.isTestnet)
                          : nonWalletTypeIcon,
                    ),
                  ),
                  onSelected: () => _onSelectedWallet(wallet),
                ))
            .toList(),
        DesktopDropdownItem(
          onSelected: () => _navigateToCreateWallet(),
          child: DropDownItemWidget(
            title: S.of(context).create_new,
            image: _newWalletImage(context),
          ),
        ),
        DesktopDropdownItem(
          onSelected: () => _navigateToRestoreWallet(),
          child: DropDownItemWidget(
            title: S.of(context).restore_wallet,
            image: _restoreWalletImage(context),
          ),
        ),
      ];

      return DropdownButton<DesktopDropdownItem>(
        items: dropDownItems
            .map(
              (wallet) => DropdownMenuItem<DesktopDropdownItem>(
                child: wallet.child,
                value: wallet,
              ),
            )
            .toList(),
        onChanged: (item) {
          item?.onSelected();
        },
        dropdownColor: themeData.extension<CakeMenuTheme>()!.backgroundColor,
        style: TextStyle(color: themeData.extension<CakeTextTheme>()!.titleColor),
        selectedItemBuilder: (context) => dropDownItems.map((item) => item.child).toList(),
        value: dropDownItems.firstWhere((element) => element.isSelected),
        underline: const SizedBox(),
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(15.0),
      );
    });
  }

  void _onSelectedWallet(WalletListItem selectedWallet) async {
    if (selectedWallet.isCurrent || !selectedWallet.isEnabled) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final confirmed = await showPopUp<bool>(
              context: context,
              builder: (dialogContext) {
                return AlertWithTwoActions(
                    alertTitle: S.of(context).change_wallet_alert_title,
                    alertContent: S.of(context).change_wallet_alert_content(selectedWallet.name),
                    leftButtonText: S.of(context).cancel,
                    rightButtonText: S.of(context).change,
                    actionLeftButton: () => Navigator.of(dialogContext).pop(false),
                    actionRightButton: () => Navigator.of(dialogContext).pop(true));
              }) ??
          false;

      if (confirmed) {
        await _loadWallet(selectedWallet);
      }
    });
  }

  Image _imageFor({required WalletType type, bool? isTestnet}) {
    switch (type) {
      case WalletType.bitcoin:
        if (isTestnet == true) return tBitcoinIcon;
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
        return nanoIcon;
      case WalletType.banano:
        return bananoIcon;
      case WalletType.polygon:
        return polygonIcon;
      case WalletType.solana:
        return solanaIcon;
      case WalletType.tron:
        return tronIcon;
      case WalletType.wownero:
        return wowneroIcon;
      default:
        return nonWalletTypeIcon;
    }
  }

  Future<void> _loadWallet(WalletListItem wallet) async {
    if (SettingsStoreBase.walletPasswordDirectInput) {
      Navigator.of(context).pushNamed(Routes.walletUnlockLoadable,
          arguments: WalletUnlockArguments(
              callback: (bool isAuthenticatedSuccessfully, AuthPageState auth) async {
                if (isAuthenticatedSuccessfully) {
                  auth.close();
                  setState(() {});
                }
              },
              walletName: wallet.name,
              walletType: wallet.type));
      return;
    }

    widget._authService.authenticateAction(
      context,
      onAuthSuccess: (isAuthenticatedSuccessfully) async {
        if (!isAuthenticatedSuccessfully) return;

        try {
          if (mounted) {
            changeProcessText(S.of(context).wallet_list_loading_wallet(wallet.name));
          }
          await widget.walletListViewModel.loadWallet(wallet);
          hideProgressText();
          setState(() {});
        } catch (e) {
          if (mounted) {
            changeProcessText(S.of(context).wallet_list_failed_to_load(wallet.name, e.toString()));
          }
        }
      },
      conditionToDetermineIfToUse2FA:
          widget.walletListViewModel.shouldRequireTOTP2FAForAccessingWallet,
    );
  }

  void _navigateToCreateWallet() {
    if (isSingleCoin) {
      widget._authService.authenticateAction(
        context,
        route: Routes.newWallet,
        arguments: widget.walletListViewModel.currentWalletType,
        conditionToDetermineIfToUse2FA:
            widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
      );
    } else {
      widget._authService.authenticateAction(
        context,
        route: Routes.newWalletType,
        conditionToDetermineIfToUse2FA:
            widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
      );
    }
  }

  void _navigateToRestoreWallet() {
    if (isSingleCoin) {
      Navigator.of(context)
          .pushNamed(Routes.restoreWallet, arguments: widget.walletListViewModel.currentWalletType);
    } else {
      Navigator.of(context).pushNamed(Routes.restoreWalletType);
    }
  }

  void changeProcessText(String text) {
    _progressBar = createBar<void>(text, duration: null)..show(context);
  }

  void hideProgressText() {
    _progressBar?.dismiss();
    _progressBar = null;
  }
}
