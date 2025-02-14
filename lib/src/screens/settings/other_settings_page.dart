import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/setting_priority_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_cell_with_arrow.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_version_cell.dart';
import 'package:cake_wallet/view_model/settings/other_settings_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class OtherSettingsPage extends BasePage {
  OtherSettingsPage(this._otherSettingsViewModel) {
    if (_otherSettingsViewModel.sendViewModel.isElectrumWallet) {
      bitcoin!.updateFeeRates(_otherSettingsViewModel.sendViewModel.wallet);
    }
  }

  @override
  String get title => S.current.other_settings;

  final OtherSettingsViewModel _otherSettingsViewModel;

  @override
  Widget body(BuildContext context) {
    return Observer(
      builder: (_) {
        return Container(
          padding: EdgeInsets.only(top: 10),
          child: Column(
            children: [
              if (_otherSettingsViewModel.displayTransactionPriority)
                _otherSettingsViewModel.walletType == WalletType.bitcoin
                    ? SettingsPriorityPickerCell(
                        title: S.current.settings_fee_priority,
                        items: priorityForWallet(_otherSettingsViewModel.sendViewModel.wallet),
                        displayItem: _otherSettingsViewModel.getDisplayBitcoinPriority,
                        selectedItem: _otherSettingsViewModel.transactionPriority,
                        customItemIndex: _otherSettingsViewModel.customPriorityItemIndex,
                        onItemSelected: _otherSettingsViewModel.onDisplayBitcoinPrioritySelected,
                        customValue: _otherSettingsViewModel.customBitcoinFeeRate,
                        maxValue: _otherSettingsViewModel.maxCustomFeeRate?.toDouble(),
                      )
                    : SettingsPickerCell(
                        title: S.current.settings_fee_priority,
                        items: priorityForWallet(_otherSettingsViewModel.sendViewModel.wallet),
                        displayItem: _otherSettingsViewModel.getDisplayPriority,
                        selectedItem: _otherSettingsViewModel.transactionPriority,
                        onItemSelected: _otherSettingsViewModel.onDisplayPrioritySelected,
                      ),
              if (_otherSettingsViewModel.changeRepresentativeEnabled)
                SettingsCellWithArrow(
                  title: S.current.change_rep,
                  handler: (BuildContext context) =>
                      Navigator.of(context).pushNamed(Routes.changeRep),
                ),
              SettingsCellWithArrow(
                title: S.current.settings_terms_and_conditions,
                handler: (BuildContext context) =>
                    Navigator.of(context).pushNamed(Routes.readDisclaimer),
              ),
              Spacer(),
              SettingsVersionCell(
                  title: S.of(context).version(_otherSettingsViewModel.currentVersion)),
            ],
          ),
        );
      },
    );
  }
}
