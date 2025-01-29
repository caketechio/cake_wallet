import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';

class CreatePinWelcomePage extends BasePage {
  CreatePinWelcomePage(this.isWalletPasswordDirectInput);

  final bool isWalletPasswordDirectInput;

  static const aspectRatioImage = 1.25;
  final welcomeImageLight = Image.asset('assets/images/welcome_light.png');
  final welcomeImageDark = Image.asset('assets/images/welcome.png');

  String appTitle(BuildContext context) {
    if (isMoneroOnly) {
      return S.of(context).monero_com;
    }

    if (isHaven) {
      return S.of(context).haven_app;
    }

    return S.of(context).cake_wallet;
  }

  String appDescription(BuildContext context) {
    if (isMoneroOnly) {
      return S.of(context).monero_com_wallet_text;
    }

    if (isHaven) {
      return S.of(context).haven_app_wallet_text;
    }

    return S.of(context).new_first_wallet_text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        resizeToAvoidBottomInset: false,
        body: body(context));
  }

  @override
  Widget body(BuildContext context) {
    final welcomeImage = currentTheme.type == ThemeType.dark ? welcomeImageDark : welcomeImageLight;

    final newWalletImage = Image.asset('assets/images/new_wallet.png',
        height: 12,
        width: 12,
        color: Theme.of(context).extension<WalletListTheme>()!.restoreWalletButtonTextColor);

    return PopScope(
      canPop: false,
      child: ScrollableWithBottomSection(
        content: Container(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints:
            BoxConstraints(maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    SizedBox(height: 70),
                    AspectRatio(
                      aspectRatio: aspectRatioImage,
                      child: FittedBox(child: welcomeImage, fit: BoxFit.contain),
                    ),
                    SizedBox(height: 50),
                    Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text(
                        S.of(context).welcome,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        appTitle(context),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        appDescription(context),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        bottomSection: Padding(
          padding: EdgeInsets.only(top: 24),
          child: PrimaryImageButton(
            key: ValueKey('create_pin_welcome_page_create_a_pin_button_key'),
            onPressed: () => Navigator.pushNamed(context, Routes.welcomeWallet),
            image: newWalletImage,
            text: isWalletPasswordDirectInput ? S.current.set_up_a_wallet : S.current.set_a_pin,
            color: Theme.of(context)
                .extension<WalletListTheme>()!
                .createNewWalletButtonBackgroundColor,
            textColor:
            Theme.of(context).extension<WalletListTheme>()!.restoreWalletButtonTextColor,
          ),
        ),
      ),
    );
  }
}
