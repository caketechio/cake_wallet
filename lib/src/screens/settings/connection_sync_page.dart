import 'dart:io';

import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_cell_with_arrow.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_tor_status.dart';
import 'package:cake_wallet/src/screens/settings/widgets/wallet_connect_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cw_core/battery_optimization_native.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/standard_list.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class ConnectionSyncPage extends BasePage {
  ConnectionSyncPage(this.dashboardViewModel);

  @override
  String get title => S.current.connection_sync;

  final DashboardViewModel dashboardViewModel;

  @override
  Widget body(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsCellWithArrow(
            title: S.current.reconnect,
            handler: (context) => _presentReconnectAlert(context),
          ),
          if (dashboardViewModel.hasRescan) ...[
            SettingsCellWithArrow(
              title: S.current.rescan,
              handler: (context) => Navigator.of(context).pushNamed(Routes.rescan),
            ),
            if (DeviceInfo.instance.isMobile) ...[
              Observer(builder: (context) {
                return SettingsPickerCell<SyncMode>(
                    title: S.current.background_sync_mode,
                    items: SyncMode.all,
                    displayItem: (SyncMode syncMode) => syncMode.name,
                    selectedItem: dashboardViewModel.syncMode,
                    onItemSelected: (syncMode) async {
                      dashboardViewModel.setSyncMode(syncMode);

                      if (syncMode.type != SyncType.disabled) {
                        await showPopUp<void>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertWithOneAction(
                              alertTitle: S.current.warning,
                              alertContent: S.current.sync_enabled_warning,
                              buttonText: S.of(context).ok,
                              buttonAction: () => Navigator.of(dialogContext).pop(),
                            );
                          },
                        );
                      }

                      if (Platform.isIOS) return;

                      if (syncMode.type != SyncType.disabled) {
                        final isDisabled = await isBatteryOptimizationDisabled();

                        if (isDisabled) return;

                        await showPopUp<void>(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertWithTwoActions(
                              alertTitle: S.current.disableBatteryOptimization,
                              alertContent: S.current.disableBatteryOptimizationDescription,
                              leftButtonText: S.of(context).cancel,
                              rightButtonText: S.of(context).ok,
                              actionLeftButton: () => Navigator.of(dialogContext).pop(),
                              actionRightButton: () async {
                                await requestDisableBatteryOptimization();

                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                        );
                      }
                    });
              }),
              Observer(builder: (context) {
                return SettingsSwitcherCell(
                  title: S.current.sync_all_wallets,
                  value: dashboardViewModel.syncAll,
                  onValueChange: (_, bool value) => dashboardViewModel.setSyncAll(value),
                );
              }),
            ],
          ],
          SettingsCellWithArrow(
            title: S.current.manage_nodes,
            handler: (context) => Navigator.of(context).pushNamed(Routes.manageNodes),
          ),
          Observer(
            builder: (context) {
              if (!dashboardViewModel.hasPowNodes) return const SizedBox();

              return Column(
                children: [
                  SettingsCellWithArrow(
                    title: S.current.manage_pow_nodes,
                    handler: (context) => Navigator.of(context).pushNamed(Routes.managePowNodes),
                  ),
                ],
              );
            },
          ),
          if (isWalletConnectCompatibleChain(dashboardViewModel.wallet.type)) ...[
            WalletConnectTile(
              onTap: () => Navigator.of(context).pushNamed(Routes.walletConnectConnectionsListing),
            ),
          ],
          if (FeatureFlag.isInAppTorEnabled && DeviceInfo.instance.isMobile) ...[
            Observer(builder: (context) {
              if (!dashboardViewModel.torViewModel.supportsNodeProxy &&
                  dashboardViewModel.torViewModel.torConnectionMode == TorConnectionMode.enabled)
                return Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 12, right: 6),
                  margin: const EdgeInsets.only(left: 24, right: 24, top: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Color.fromARGB(200, 255, 221, 44),
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
                      Expanded(
                        child: Text(
                          S.of(context).tor_node_warning,
                          maxLines: 5,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              return const SizedBox();
            }),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(children: [
                Observer(builder: (context) {
                  return SettingsPickerCell<TorConnectionMode>(
                    title: S.current.tor_connection,
                    items: TorConnectionMode.enabledDisabled,
                    displayItem: (TorConnectionMode mode) => mode.title,
                    selectedItem: dashboardViewModel.torViewModel.torConnectionMode,
                    onItemSelected: (TorConnectionMode mode) async {
                      if (mode == TorConnectionMode.enabled) {
                        await showPopUp<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertWithOneAction(
                              alertTitle: S.of(context).warning,
                              alertContent: S.of(context).tor_enabled_warning,
                              buttonText: S.of(context).ok,
                              buttonAction: () => Navigator.of(context).pop(),
                            );
                          },
                        );
                      }
                      dashboardViewModel.torViewModel.setTorConnectionMode(mode);
                    },
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                      color: Theme.of(context)
                          .extension<SyncIndicatorTheme>()!
                          .notSyncedBackgroundColor,
                    ),
                  );
                }),
                TorStatus(
                  torViewModel: dashboardViewModel.torViewModel,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
                    color:
                        Theme.of(context).extension<SyncIndicatorTheme>()!.notSyncedBackgroundColor,
                  ),
                  title: S.current.tor_status,
                  isSelected: false,
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _presentReconnectAlert(BuildContext context) async {
    await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertWithTwoActions(
            alertTitle: S.of(context).reconnection,
            alertContent: S.of(context).reconnect_alert_text,
            rightButtonText: S.of(context).ok,
            leftButtonText: S.of(context).cancel,
            actionRightButton: () async {
              Navigator.of(context).pop();
              await dashboardViewModel.reconnect();
            },
            actionLeftButton: () => Navigator.of(context).pop());
      },
    );
  }
}
