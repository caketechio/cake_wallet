import 'package:another_flushbar/flushbar.dart';
import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/core/new_wallet_arguments.dart';
import 'package:cake_wallet/entities/wallet_edit_page_arguments.dart';
import 'package:cake_wallet/entities/wallet_list_order_types.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/connect_device/connect_device_page.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/filter_list_widget.dart';
import 'package:cake_wallet/src/screens/new_wallet/widgets/grouped_wallet_expansion_tile.dart';
import 'package:cake_wallet/src/screens/wallet_list/edit_wallet_button_widget.dart';
import 'package:cake_wallet/src/screens/wallet_list/filtered_list.dart';
import 'package:cake_wallet/src/screens/wallet_unlock/wallet_unlock_arguments.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/filter_theme.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class WalletListPage extends BasePage {
  WalletListPage({
    required this.walletListViewModel,
    required this.authService,
    this.onWalletLoaded,
  });

  final WalletListViewModel walletListViewModel;
  final AuthService authService;
  final Function(BuildContext)? onWalletLoaded;

  @override
  String get title => S.current.wallets;

  @override
  Widget body(BuildContext context) => WalletListBody(
        walletListViewModel: walletListViewModel,
        authService: authService,
        onWalletLoaded:
            onWalletLoaded ?? (context) => Navigator.of(context).pop(),
      );

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
                    onClose: (bool ascending, FilterListOrderType type) async {
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
  WalletListBody({
    required this.walletListViewModel,
    required this.authService,
    required this.onWalletLoaded,
  });

  final WalletListViewModel walletListViewModel;
  final AuthService authService;
  final Function(BuildContext) onWalletLoaded;

  @override
  WalletListBodyState createState() => WalletListBodyState();
}

class WalletListBodyState extends State<WalletListBody> {
  final moneroIcon = Image.asset('assets/images/monero_logo.png', height: 24, width: 24);
  final bitcoinIcon = Image.asset('assets/images/bitcoin.png', height: 24, width: 24);
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
  final zanoIcon = Image.asset('assets/images/zano_icon.png', height: 24, width: 24);
  final scrollController = ScrollController();
  final double tileHeight = 60;
  Flushbar<void>? _progressBar;

  @override
  Widget build(BuildContext context) {
    final newWalletImage = Image.asset('assets/images/new_wallet.png',
        height: 12, width: 12, color: Colors.white);
    final restoreWalletImage = Image.asset('assets/images/restore_wallet.png',
        height: 12,
        width: 12,
        color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor);

    return Container(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.walletListViewModel.multiWalletGroups.isNotEmpty) ...{
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        S.current.shared_seed_wallet_groups,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      child: Observer(
                        builder: (_) => FilteredList(
                          shrinkWrap: true,
                          list: widget.walletListViewModel.multiWalletGroups,
                          updateFunction: widget.walletListViewModel.reorderAccordingToWalletList,
                          itemBuilder: (context, index) {
                            final group = widget.walletListViewModel.multiWalletGroups[index];
                            final groupName = group.groupName ??
                                '${S.current.wallet_group} ${index + 1}';

                            widget.walletListViewModel.updateTileState(
                              index,
                              widget.walletListViewModel.expansionTileStateTrack[index] ?? false,
                            );

                            return GroupedWalletExpansionTile(
                              onExpansionChanged: (value) {
                                widget.walletListViewModel.updateTileState(index, value);
                                setState(() {});
                              },
                              shouldShowCurrentWalletPointer: true,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                              margin: EdgeInsets.only(left: 20, right: 20, bottom: 12),
                              title: groupName,
                              tileKey: ValueKey('group_wallets_expansion_tile_widget_$index'),
                              leadingWidget: Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 28,
                              ),
                              trailingWidget: EditWalletButtonWidget(
                                width: 74,
                                isGroup: true,
                                isExpanded: widget.walletListViewModel.expansionTileStateTrack[index]!,
                                onTap: () {
                                  final wallet = widget.walletListViewModel
                                      .convertWalletInfoToWalletListItem(group.wallets.first);
                                  Navigator.of(context).pushNamed(
                                    Routes.walletEdit,
                                    arguments: WalletEditPageArguments(
                                      walletListViewModel: widget.walletListViewModel,
                                      editingWallet: wallet,
                                      isWalletGroup: true,
                                      groupName: groupName,
                                      parentAddress: group.parentAddress,
                                    ),
                                  );
                                },
                              ),
                              childWallets: group.wallets.map((walletInfo) {
                                return widget.walletListViewModel.convertWalletInfoToWalletListItem(walletInfo);
                              }).toList(),
                              isSelected: false,
                              onChildItemTapped: (wallet) =>
                                  wallet.isCurrent ? null : _loadWallet(wallet),
                              childTrailingWidget: (item) {
                                return item.isCurrent
                                    ? SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(right: 16),
                                        child: EditWalletButtonWidget(
                                          width: 44,
                                          onTap: () => Navigator.of(context).pushNamed(
                                            Routes.walletEdit,
                                            arguments: WalletEditPageArguments(
                                              walletListViewModel: widget.walletListViewModel,
                                              editingWallet: item,
                                            ),
                                          ),
                                        ),
                                      );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  },
                  if (widget.walletListViewModel.singleWalletsList.isNotEmpty) ...{
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        S.current.single_seed_wallets_group,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      child: Observer(
                        builder: (_) => FilteredList(
                          shrinkWrap: true,
                          list: widget.walletListViewModel.singleWalletsList,
                          updateFunction: widget.walletListViewModel.reorderAccordingToWalletList,
                          itemBuilder: (context, index) {
                            final wallet = widget.walletListViewModel.singleWalletsList[index];
                            final currentColor = wallet.isCurrent
                                ? Theme.of(context)
                                    .extension<WalletListTheme>()!
                                    .createNewWalletButtonBackgroundColor
                                : Theme.of(context).colorScheme.background;

                            return GroupedWalletExpansionTile(
                              tileKey: ValueKey('single_wallets_expansion_tile_widget_$index'),
                              isCurrentlySelectedWallet: wallet.isCurrent,
                              leadingWidget: SizedBox(
                                width: wallet.isCurrent ? 56 : 40,
                                child: Row(
                                  children: [
                                    wallet.isCurrent
                                        ? Container(
                                            height: 35,
                                            width: 6,
                                            margin: EdgeInsets.only(right: 16),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.only(
                                                topRight: Radius.circular(16),
                                                bottomRight: Radius.circular(16),
                                              ),
                                              color: currentColor,
                                            ),
                                          )
                                        : SizedBox(width: 6),
                                    Image.asset(
                                      walletTypeToCryptoCurrency(wallet.type).iconPath!,
                                      width: 32,
                                      height: 32,
                                    ),
                                  ],
                                ),
                              ),
                              title: wallet.name,
                              isSelected: false,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                              margin: EdgeInsets.only(left: 20, right: 20, bottom: 12),
                              onTitleTapped: () => wallet.isCurrent ? null : _loadWallet(wallet),
                              trailingWidget: wallet.isCurrent
                                  ? null
                                  : EditWalletButtonWidget(
                                      width: 44,
                                      onTap: () {
                                        Navigator.of(context).pushNamed(
                                          Routes.walletEdit,
                                          arguments: WalletEditPageArguments(
                                            walletListViewModel: widget.walletListViewModel,
                                            editingWallet: wallet,
                                          ),
                                        );
                                      },
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  },
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                PrimaryImageButton(
                  key: ValueKey('wallet_list_page_restore_wallet_button_key'),
                  onPressed: () {
                    if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                      widget.authService.authenticateAction(
                        context,
                        route: Routes.restoreOptions,
                        arguments: false,
                        conditionToDetermineIfToUse2FA: widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
                      );
                    } else {
                      Navigator.of(context).pushNamed(Routes.restoreOptions, arguments: false);
                    }
                  },
                  image: restoreWalletImage,
                  text: S.of(context).wallet_list_restore_wallet,
                  color: Theme.of(context).cardColor,
                  textColor: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
                ),
                SizedBox(height: 10.0),
                PrimaryImageButton(
                  key: ValueKey('wallet_list_page_create_new_wallet_button_key'),
                  onPressed: () {
                    //TODO(David): Find a way to optimize this
                    if (isSingleCoin) {
                      if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                        widget.authService.authenticateAction(
                          context,
                          route: Routes.newWallet,
                          arguments: NewWalletArguments(
                            type: widget.walletListViewModel.currentWalletType,
                          ),
                          conditionToDetermineIfToUse2FA: widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
                        );
                      } else {
                        Navigator.of(context).pushNamed(
                          Routes.newWallet,
                          arguments: NewWalletArguments(
                            type: widget.walletListViewModel.currentWalletType,
                          ),
                        );
                      }
                    } else {
                      if (widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets) {
                        widget.authService.authenticateAction(
                          context,
                          route: Routes.newWalletType,
                          conditionToDetermineIfToUse2FA: widget.walletListViewModel.shouldRequireTOTP2FAForCreatingNewWallets,
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
              ],
            ),
          ),
        ],
      ),
    );
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

    await widget.authService.authenticateAction(
      context,
      onAuthSuccess: (isAuthenticatedSuccessfully) async {
        if (!isAuthenticatedSuccessfully) return;

        try {
          final requireHardwareWalletConnection = widget.walletListViewModel
              .requireHardwareWalletConnection(wallet);
          if (requireHardwareWalletConnection) {
            await Navigator.of(context).pushNamed(
              Routes.connectDevices,
              arguments: ConnectDevicePageParams(
                walletType: WalletType.monero,
                onConnectDevice: (context, ledgerVM) async {
                  monero!.setGlobalLedgerConnection(ledgerVM.connection);
                  Navigator.of(context).pop();
                },
              ),
            );

            showPopUp<void>(
              context: context,
              builder: (BuildContext context) => AlertWithOneAction(
                  alertTitle: S.of(context).proceed_on_device,
                  alertContent: S.of(context).proceed_on_device_description,
                  buttonText: S.of(context).cancel,
                  buttonAction: () => Navigator.of(context).pop()),
            );
          }

          changeProcessText(
              S.of(context).wallet_list_loading_wallet(wallet.name));
          await widget.walletListViewModel.loadWallet(wallet);
          await hideProgressText();
          // only pop the wallets route in mobile as it will go back to dashboard page
          // in desktop platforms the navigation tree is different
          if (responsiveLayoutUtil.shouldRenderMobileUI) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (this.mounted) {
                if (requireHardwareWalletConnection) {
                  Navigator.of(context).pop();
                }
                widget.onWalletLoaded.call(context);
              }
            });
          }
        } catch (e) {
          await ExceptionHandler.resetLastPopupDate();
          final err = e.toString();
          await ExceptionHandler.onError(FlutterErrorDetails(exception: err));
          if (this.mounted) {
            changeProcessText(S
                .of(context)
                .wallet_list_failed_to_load(wallet.name, e.toString()));
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
