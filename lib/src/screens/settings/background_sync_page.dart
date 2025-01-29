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
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class BackgroundSyncPage extends BasePage {
  BackgroundSyncPage(this.dashboardViewModel);

  @override
  String get title => S.current.background_sync;

  final DashboardViewModel dashboardViewModel;

  @override
  Widget body(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Observer(builder: (context) {
            return SettingsSwitcherCell(
              title: S.current.background_sync,
              value: dashboardViewModel.backgroundSyncEnabled,
              onValueChange: (_, bool value) =>
                  dashboardViewModel.setBackgroundSyncEnabled(value),
            );
          }),
          Observer(builder: (context) {
            return SettingsPickerCell<SyncMode>(
                title: S.current.background_sync_mode,
                items: SyncMode.all,
                displayItem: (SyncMode syncMode) => syncMode.name,
                selectedItem: dashboardViewModel.syncMode,
                onItemSelected: (syncMode) async {
                  dashboardViewModel.setSyncMode(syncMode);

                  if (Platform.isIOS) return;
                });
          }),
          Observer(builder: (context) {
            return SettingsSwitcherCell(
              title: S.current.show_sync_notifications,
              value: dashboardViewModel.showSyncNotification,
              onValueChange: (BuildContext _, bool isEnabled) async {
                dashboardViewModel.setShowSyncNotification(isEnabled);
              },
            );
          }),
          // Observer(builder: (context) {
          //   return SettingsSwitcherCell(
          //     title: S.current.sync_all_wallets,
          //     value: dashboardViewModel.syncAll,
          //     onValueChange: (_, bool value) => dashboardViewModel.setSyncAll(value),
          //   );
          // }),
          Observer(builder: (context) {
            return SettingsSwitcherCell(
              title: S.current.background_sync_on_battery,
              value: dashboardViewModel.backgroundSyncOnBattery,
              onValueChange: (_, bool value) =>
                  dashboardViewModel.setBackgroundSyncOnBattery(value),
            );
          }),
          Observer(builder: (context) {
            return SettingsSwitcherCell(
              title: S.current.background_sync_on_data,
              value: dashboardViewModel.backgroundSyncOnData,
              onValueChange: (_, bool value) => dashboardViewModel.setBackgroundSyncOnData(value),
            );
          }),
        ],
      ),
    );
  }
}
