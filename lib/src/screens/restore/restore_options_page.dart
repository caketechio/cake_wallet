import 'dart:io';

import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/option_tile.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/permission_handler.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/restore/wallet_restore_from_qr_code.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/hardware/device_connection_type.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/info_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';

class RestoreOptionsPage extends BasePage {
  RestoreOptionsPage({required this.isNewInstall});

  @override
  String get title => S.current.restore_restore_wallet;

  final bool isNewInstall;

  @override
  Widget body(BuildContext context) {
    return _RestoreOptionsBody(isNewInstall: isNewInstall, themeType: currentTheme.type);
  }
}

class _RestoreOptionsBody extends StatefulWidget {
  const _RestoreOptionsBody({required this.isNewInstall, required this.themeType});

  final bool isNewInstall;
  final ThemeType themeType;

  @override
  _RestoreOptionsBodyState createState() => _RestoreOptionsBodyState();
}

class _RestoreOptionsBodyState extends State<_RestoreOptionsBody> {
  bool isRestoring = false;

  bool get _doesSupportHardwareWallets {
    if (!DeviceInfo.instance.isMobile) {
      return false;
    }

    if (isMoneroOnly) {
      return DeviceConnectionType.supportedConnectionTypes(WalletType.monero, Platform.isIOS)
          .isNotEmpty;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final mainImageColor = Theme.of(context).extension<DashboardPageTheme>()!.pageTitleTextColor;
    final brightImageColor = Theme.of(context).extension<InfoTheme>()!.textColor;
    final imageColor = widget.themeType == ThemeType.bright ? brightImageColor : mainImageColor;
    final imageLedger = Image.asset('assets/images/hardware_wallet/ledger_nano_x.png', width: 40, color: imageColor);
    final imageSeedKeys = Image.asset('assets/images/restore_wallet_image.png', color: imageColor);
    final imageBackup = Image.asset('assets/images/backup.png', color: imageColor);

    return Center(
      child: Container(
          width: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint,
          height: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                OptionTile(
                  key: ValueKey('restore_options_from_seeds_or_keys_button_key'),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    Routes.restoreWalletFromSeedKeys),
                  image: imageSeedKeys,
                  title: S.of(context).restore_title_from_seed_keys,
                  description: S.of(context).restore_description_from_seed_keys,
                ),
                if (widget.isNewInstall)
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: OptionTile(
                      key: ValueKey('restore_options_from_backup_button_key'),
                      onPressed: () => Navigator.pushNamed(context, Routes.restoreFromBackup),
                      image: imageBackup,
                      title: S.of(context).restore_title_from_backup,
                      description: S.of(context).restore_description_from_backup,
                    ),
                  ),
                if (_doesSupportHardwareWallets)
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: OptionTile(
                      key: ValueKey('restore_options_from_hardware_wallet_button_key'),
                      onPressed: () => Navigator.pushNamed(
                          context, Routes.restoreWalletFromHardwareWallet),
                      image: imageLedger,
                      title: S.of(context).restore_title_from_hardware_wallet,
                      description: S.of(context).restore_description_from_hardware_wallet,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: OptionTile(
                      key: ValueKey('restore_options_from_qr_button_key'),
                      onPressed: () => _onScanQRCode(context),
                      icon: Icon(
                        Icons.qr_code_rounded,
                        color: imageColor,
                        size: 50,
                      ),
                      title: S.of(context).scan_qr_code,
                      description: S.of(context).cold_or_recover_wallet),
                )
              ],
            ),
          )),
    );
  }

  void _showQRScanError(BuildContext context, String error) {
    setState(() => isRestoring = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showPopUp<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertWithOneAction(
                alertTitle: S.current.error,
                alertContent: error,
                buttonText: S.of(context).ok,
                buttonAction: () => Navigator.of(context).pop());
          });
    });
  }

  Future<void> _onScanQRCode(BuildContext context) async {
    final isCameraPermissionGranted =
    await PermissionHandler.checkPermission(Permission.camera, context);

    if (!isCameraPermissionGranted) return;
    try {
      if (isRestoring) return;

      setState(() => isRestoring = true);

      final restoredWallet = await WalletRestoreFromQRCode.scanQRCodeForRestoring(context);

      final params = {'walletType': restoredWallet.type, 'restoredWallet': restoredWallet};

      Navigator.pushNamed(context, Routes.restoreWallet, arguments: params).then((_) {
        if (mounted) setState(() => isRestoring = false);
      });
    } catch (e) {
      _showQRScanError(context, e.toString());
    }
  }
}
