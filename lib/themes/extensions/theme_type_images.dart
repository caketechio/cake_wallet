import 'package:cake_wallet/themes/theme_base.dart';

extension ThemeTypeImages on ThemeType {
  String get walletGroupImage {
    switch (this) {
      case ThemeType.bright:
        return 'assets/images/wallet_group_bright.png';
      case ThemeType.light:
        return 'assets/images/wallet_group_light.png';
      default:
        return 'assets/images/wallet_group_dark.png';
    }
  }
}
