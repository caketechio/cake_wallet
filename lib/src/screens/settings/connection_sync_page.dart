import 'dart:io';

import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_cell_with_arrow.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/wallet_connect_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cw_core/battery_optimization_native.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
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
              title: dashboardViewModel.hasSilentPayments
                  ? S.current.silent_payments_scanning
                  : S.current.rescan,
              handler: (context) => Navigator.of(context).pushNamed(Routes.rescan),
            ),
            if (DeviceInfo.instance.isMobile && FeatureFlag.isBackgroundSyncEnabled) ...[
              Observer(builder: (context) {
                return SettingsPickerCell<SyncMode>(
                    title: S.current.background_sync_mode,
                    items: SyncMode.all,
                    displayItem: (SyncMode syncMode) => syncMode.name,
                    selectedItem: dashboardViewModel.syncMode,
                    onItemSelected: (syncMode) async {
                      dashboardViewModel.setSyncMode(syncMode);

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
          Observer(
            builder: (context) {
              if (!dashboardViewModel.hasNodes) return const SizedBox();
              return Column(
                children: [
                  SettingsCellWithArrow(
                    title: S.current.manage_nodes,
                    handler: (context) => Navigator.of(context).pushNamed(Routes.manageNodes),
                  ),
                ],
              );
            },
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
          if (isWalletConnectCompatibleChain(dashboardViewModel.wallet.type) &&
              !dashboardViewModel.wallet.isHardwareWallet) ...[
            // ToDo: Remove this line once WalletConnect is implemented
            WalletConnectTile(
              onTap: () => Navigator.of(context).pushNamed(Routes.walletConnectConnectionsListing),
            ),
          ],
          if (FeatureFlag.isInAppTorEnabled)
            SettingsCellWithArrow(
              title: S.current.tor_connection,
              handler: (context) => Navigator.of(context).pushNamed(Routes.torPage),
            ),
          Observer(
            builder: (context) {
              if (dashboardViewModel.wallet.type != WalletType.lightning) return const SizedBox();
              return Column(
                children: [
                  SettingsCellWithArrow(
                    title: S.current.refund_address,
                    handler: (context) => Navigator.of(context).pushNamed(Routes.lightningRefund),
                  ),
                ],
              );
            },
          ),
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
