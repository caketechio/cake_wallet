import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/seedphrase_grid_widget.dart';
import 'package:cake_wallet/src/widgets/warning_box_widget.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/clipboard_util.dart';
import 'package:cake_wallet/utils/share_util.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/view_model/wallet_seed_view_model.dart';

class WalletSeedPage extends BasePage {
  WalletSeedPage(this.walletSeedViewModel, {required this.isNewWalletCreated});

  @override
  String get title => S.current.seed_title;

  final bool isNewWalletCreated;
  final WalletSeedViewModel walletSeedViewModel;

  @override
  Widget trailing(BuildContext context) {
    final copyImage = Image.asset(
      'assets/images/copy_address.png',
      color: Theme.of(context)
          .extension<CakeTextTheme>()!
          .buttonTextColor
    );

    return isNewWalletCreated
        ? GestureDetector(
            key: ValueKey('wallet_seed_page_copy_seeds_button_key'),
            onTap: () {
              ClipboardUtil.setSensitiveDataToClipboard(
                ClipboardData(text: walletSeedViewModel.seed),
              );
              showBar<void>(context, S.of(context).copied_to_clipboard);
            },
            child: Container(
              padding: EdgeInsets.all(8),
              width: 40,
              alignment: Alignment.center,
              margin: EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                color: Theme.of(context).cardColor,
              ),
              child: copyImage,
            ),
          )
        : Offstage();
  }

  @override
  Widget body(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Container(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Observer(
                builder: (_) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 22, right: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        WarningBox(
                            content: S.current.cake_seeds_save_disclaimer,
                            currentTheme: currentTheme),
                        SizedBox(height: 20),
                        Text(
                          key: ValueKey('wallet_seed_page_wallet_name_text_key'),
                          walletSeedViewModel.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                          ),
                        ),
                        SizedBox(height: 20),
                        Expanded(
                          child: SeedPhraseGridWidget(list: walletSeedViewModel.seedSplit),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
              Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.only(right: 8.0, top: 8.0),
                          child: PrimaryButton(
                            key: ValueKey('wallet_seed_page_save_seeds_button_key'),
                            onPressed: () {
                              ShareUtil.share(
                                text: walletSeedViewModel.seed,
                                context: context,
                              );
                            },
                            text: S.of(context).save,
                            color: Theme.of(context).cardColor,
                            textColor: currentTheme.type == ThemeType.dark
                                ? Theme.of(context).extension<DashboardPageTheme>()!.textColor
                                : Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.only(left: 8.0, top: 8.0),
                          child: Builder(
                            builder: (context) => PrimaryButton(
                              key: ValueKey('wallet_seed_page_verify_seed_button_key'),
                              onPressed: () =>
                                  Navigator.pushNamed(context, Routes.walletSeedVerificationPage),
                              text: S.current.verify_seed,
                              color: Theme.of(context).primaryColor,
                              textColor: Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  ),
                  SizedBox(height: 12),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
