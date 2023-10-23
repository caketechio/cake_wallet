import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/language_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_theme_choice.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/settings/display_settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';

class DisplaySettingsPage extends BasePage {
  DisplaySettingsPage(this._displaySettingsViewModel);

  @override
  String get title => S.current.display_settings;

  final DisplaySettingsViewModel _displaySettingsViewModel;

  @override
  Widget body(BuildContext context) {
    return SingleChildScrollView(
      child: Observer(builder: (_) {
        return Container(
          padding: EdgeInsets.only(top: 10),
          child: Column(
            children: [
              SettingsSwitcherCell(
                  title: S.current.settings_display_balance,
                  value: _displaySettingsViewModel.shouldDisplayBalance,
                  onValueChange: (_, bool value) {
                    _displaySettingsViewModel.setShouldDisplayBalance(value);
                  }),
              SettingsSwitcherCell(
                title: S.current.show_market_place,
                value: _displaySettingsViewModel.shouldShowMarketPlaceInDashboard,
                onValueChange: (_, bool value) {
                  _displaySettingsViewModel.setShouldShowMarketPlaceInDashbaord(value);
                },
              ),
              //if (!isHaven) it does not work correctly
              if (!_displaySettingsViewModel.disabledFiatApiMode)
                SettingsPickerCell<FiatCurrency>(
                  title: S.current.settings_currency,
                  searchHintText: S.current.search_currency,
                  items: FiatCurrency.all,
                  selectedItem: _displaySettingsViewModel.fiatCurrency,
                  onItemSelected: (FiatCurrency currency) =>
                      _displaySettingsViewModel.setFiatCurrency(currency),
                  images: FiatCurrency.all
                      .map((e) => SvgPicture.asset("assets/images/flags/${e.countryCode}.svg",
                          width: 42, height: 26, fit: BoxFit.contain))
                      .toList(),
                  isGridView: true,
                  matchingCriteria: (FiatCurrency currency, String searchText) {
                    return currency.title.toLowerCase().contains(searchText) ||
                        currency.fullName.toLowerCase().contains(searchText);
                  },
                ),
              SettingsPickerCell<String>(
                title: S.current.settings_change_language,
                searchHintText: S.current.search_language,
                items: LanguageService.list.keys.toList(),
                displayItem: (dynamic code) {
                  return LanguageService.list[code] ?? '';
                },
                selectedItem: _displaySettingsViewModel.languageCode,
                onItemSelected: _displaySettingsViewModel.onLanguageSelected,
                images: LanguageService.list.keys
                    .map((e) => SvgPicture.asset(
                        "assets/images/flags/${LanguageService.localeCountryCode[e]}.svg",
                    width: 42, height: 26, fit: BoxFit.contain))
                    .toList(),
                matchingCriteria: (String code, String searchText) {
                  return LanguageService.list[code]?.toLowerCase().contains(searchText) ?? false;
                },
              ),
              if (ResponsiveLayoutUtil.instance.isMobile && DeviceInfo.instance.isMobile)
                SettingsThemeChoicesCell(_displaySettingsViewModel),
            ],
          ),
        );
      }),
    );
  }
}
