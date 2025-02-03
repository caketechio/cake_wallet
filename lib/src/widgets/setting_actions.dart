import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:flutter/material.dart';

class SettingActions {
  final String Function(BuildContext) name;
  final String image;
  final Key key;
  final void Function(BuildContext) onTap;

  SettingActions._({
    required this.key,
    required this.name,
    required this.image,
    required this.onTap,
  });

  static List<SettingActions> all = [
    connectionSettingAction,
    walletSettingAction,
    addressBookSettingAction,
    silentPaymentsSettingAction,
    litecoinMwebSettingAction,
    exportOutputsAction,
    securityBackupSettingAction,
    privacySettingAction,
    displaySettingAction,
    otherSettingAction,
    supportSettingAction,
  ];

  static List<SettingActions> desktopSettings = [
    connectionSettingAction,
    walletSettingAction,
    addressBookSettingAction,
    silentPaymentsSettingAction,
    securityBackupSettingAction,
    privacySettingAction,
    displaySettingAction,
    otherSettingAction,
    supportSettingAction,
  ];

  static SettingActions silentPaymentsSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_silent_payment_settings_button_key'),
    name: (context) => S.of(context).silent_payments_settings,
    image: 'assets/images/bitcoin_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.silentPaymentsSettings);
    },
  );

  static SettingActions exportOutputsAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_export_outputs_settings_button_key'),
    name: (context) => S.of(context).export_outputs,
    image: 'assets/images/monero_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.urqrAnimatedPage, arguments: 'export-outputs');
    },
  );
  
  static SettingActions litecoinMwebSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_litecoin_mweb_settings_button_key'),
    name: (context) => S.of(context).litecoin_mweb_settings,
    image: 'assets/images/litecoin_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.mwebSettings);
    },
  );

  static SettingActions connectionSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_connection_and_sync_settings_button_key'),
    name: (context) => S.of(context).connection_sync,
    image: 'assets/images/nodes_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.connectionSync);
    },
  );

  static SettingActions walletSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_wallet_menu_button_key'),
    name: (context) => S.of(context).wallets,
    image: 'assets/images/wallet_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.walletList, arguments: (_) {
        Navigator.of(context).pop(); // pops wallet list
        Navigator.of(context).pop(); // pops drawer
      });
    },
  );

  static SettingActions addressBookSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_address_book_button_key'),
    name: (context) => S.of(context).address_book_menu,
    image: 'assets/images/open_book_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.addressBook);
    },
  );

  static SettingActions securityBackupSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_security_and_backup_button_key'),
    name: (context) => S.of(context).security_and_backup,
    image: 'assets/images/key_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.securityBackupPage);
    },
  );

  static SettingActions privacySettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_privacy_settings_button_key'),
    name: (context) => S.of(context).privacy,
    image: 'assets/images/privacy_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.privacyPage);
    },
  );

  static SettingActions displaySettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_display_settings_button_key'),
    name: (context) => S.of(context).display_settings,
    image: 'assets/images/eye_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.displaySettingsPage);
    },
  );

  static SettingActions otherSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_other_settings_button_key'),
    name: (context) => S.of(context).other_settings,
    image: 'assets/images/settings_menu.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.otherSettingsPage);
    },
  );

  static SettingActions supportSettingAction = SettingActions._(
    key: ValueKey('dashboard_page_menu_widget_support_settings_button_key'),
    name: (context) => S.of(context).settings_support,
    image: 'assets/images/question_mark.png',
    onTap: (BuildContext context) {
      Navigator.of(context).pushNamed(Routes.support);
    },
  );
}
