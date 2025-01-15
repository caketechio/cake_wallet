import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/view_model/settings/privacy_settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class DomainLookupsPage extends BasePage {
  DomainLookupsPage(this._privacySettingsViewModel);

  @override
  String get title => S.current.domain_looks_up;

  final PrivacySettingsViewModel _privacySettingsViewModel;

  @override
  Widget body(BuildContext context) {
    return SingleChildScrollView(
      child: Observer(builder: (_) {
        return Container(
          padding: EdgeInsets.only(top: 10),
          child: Column(
            children: [
              SettingsSwitcherCell(
                  title: 'Twitter',
                  value: _privacySettingsViewModel.lookupTwitter,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsTwitter(value)),
              SettingsSwitcherCell(
                  title: 'Mastodon',
                  value: _privacySettingsViewModel.looksUpMastodon,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsMastodon(value)),
              SettingsSwitcherCell(
                  title: 'Yat service',
                  value: _privacySettingsViewModel.looksUpYatService,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsYatService(value)),
              SettingsSwitcherCell(
                  title: 'Unstoppable Domains',
                  value: _privacySettingsViewModel.looksUpUnstoppableDomains,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsUnstoppableDomains(value)),
              SettingsSwitcherCell(
                  title: 'OpenAlias',
                  value: _privacySettingsViewModel.looksUpOpenAlias,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsOpenAlias(value)),
              SettingsSwitcherCell(
                  title: 'Ethereum Name Service',
                  value: _privacySettingsViewModel.looksUpENS,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsENS(value)),
              SettingsSwitcherCell(
                  title: '.well-known',
                  value: _privacySettingsViewModel.looksUpWellKnown,
                  onValueChange: (_, bool value) => _privacySettingsViewModel.setLookupsWellKnown(value)),

              //if (!isHaven) it does not work correctly
            ],
          ),
        );
      }),
    );
  }
}
