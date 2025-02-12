import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_cell_with_arrow.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_choices_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/settings/choices_list_item.dart';
import 'package:cake_wallet/view_model/settings/privacy_settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class PrivacyPage extends BasePage {
  PrivacyPage(this._privacySettingsViewModel);

  @override
  String get title => S.current.privacy_settings;

  final PrivacySettingsViewModel _privacySettingsViewModel;

  @override
  Widget body(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(top: 10),
        child: Observer(builder: (_) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsChoicesCell(
                ChoicesListItem<FiatApiMode>(
                  title: S.current.fiat_api,
                  items: FiatApiMode.all,
                  selectedItem: _privacySettingsViewModel.fiatApiMode,
                  onItemSelected: (FiatApiMode fiatApiMode) =>
                      _privacySettingsViewModel.setFiatMode(fiatApiMode),
                ),
              ),
              SettingsChoicesCell(
                ChoicesListItem<ExchangeApiMode>(
                  title: S.current.exchange,
                  items: ExchangeApiMode.all,
                  selectedItem: _privacySettingsViewModel.exchangeStatus,
                  onItemSelected: (ExchangeApiMode mode) =>
                      _privacySettingsViewModel.setExchangeApiMode(mode),
                ),
              ),
              if (_privacySettingsViewModel.canUsePayjoin)
                SettingsSwitcherCell(
                  title: S.of(context).use_payjoin,
                  value: _privacySettingsViewModel.usePayjoin,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setUsePayjoin(value);
                  },
                ),
              SettingsSwitcherCell(
                  title: S.current.settings_save_recipient_address,
                  value: _privacySettingsViewModel.shouldSaveRecipientAddress,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setShouldSaveRecipientAddress(value);
                  }),
              if (_privacySettingsViewModel.isAutoGenerateSubaddressesVisible)
                SettingsSwitcherCell(
                  title: _privacySettingsViewModel.isMoneroWallet
                      ? S.current.auto_generate_subaddresses
                      : S.current.auto_generate_addresses,
                  value: _privacySettingsViewModel.isAutoGenerateSubaddressesEnabled,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setAutoGenerateSubaddresses(value);
                  },
                ),
              if (DeviceInfo.instance.isMobile)
                SettingsSwitcherCell(
                    title: S.current.prevent_screenshots,
                    value: _privacySettingsViewModel.isAppSecure,
                    onValueChange: (BuildContext _, bool value) {
                      _privacySettingsViewModel.setIsAppSecure(value);
                    }),
              SettingsSwitcherCell(
                  title: S.current.disable_trade_option,
                  value: _privacySettingsViewModel.disableTradeOption,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setDisableTradeOption(value);
                  }),
              SettingsSwitcherCell(
                  title: S.current.disable_bulletin,
                  value: _privacySettingsViewModel.disableBulletin,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setDisableBulletin(value);
                  }),
              if (_privacySettingsViewModel.canUseEtherscan)
                SettingsSwitcherCell(
                    title: S.current.etherscan_history,
                    value: _privacySettingsViewModel.useEtherscan,
                    onValueChange: (BuildContext _, bool value) {
                      _privacySettingsViewModel.setUseEtherscan(value);
                    }),
              if (_privacySettingsViewModel.canUsePolygonScan)
                SettingsSwitcherCell(
                  title: S.current.polygonscan_history,
                  value: _privacySettingsViewModel.usePolygonScan,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setUsePolygonScan(value);
                  },
                ),
              if (_privacySettingsViewModel.canUseTronGrid)
                SettingsSwitcherCell(
                  title: S.current.trongrid_history,
                  value: _privacySettingsViewModel.useTronGrid,
                  onValueChange: (BuildContext _, bool value) {
                    _privacySettingsViewModel.setUseTronGrid(value);
                  },
                ),
              if (_privacySettingsViewModel.canUseMempoolFeeAPI)
                SettingsSwitcherCell(
                  title: S.current.enable_mempool_api,
                  value: _privacySettingsViewModel.useMempoolFeeAPI,
                  onValueChange: (BuildContext _, bool isEnabled) async {
                    if (!isEnabled) {
                      final bool confirmation = await showPopUp<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertWithTwoActions(
                                    alertTitle: S.of(context).warning,
                                    alertContent: S.of(context).disable_fee_api_warning,
                                    rightButtonText: S.of(context).confirm,
                                    leftButtonText: S.of(context).cancel,
                                    actionRightButton: () => Navigator.of(context).pop(true),
                                    actionLeftButton: () => Navigator.of(context).pop(false));
                              }) ??
                          false;
                      if (confirmation) {
                        _privacySettingsViewModel.setUseMempoolFeeAPI(isEnabled);
                      }
                      return;
                    }

                    _privacySettingsViewModel.setUseMempoolFeeAPI(isEnabled);
                  },
                ),
              SettingsCellWithArrow(
                title: S.current.domain_looks_up,
                handler: (context) => Navigator.of(context).pushNamed(Routes.domainLookupsPage),
              ),
              SettingsCellWithArrow(
                title: 'Trocador providers',
                handler: (context) => Navigator.of(context).pushNamed(Routes.trocadorProvidersPage),
              ),
            ],
          );
        }),
      ),
    );
  }
}
