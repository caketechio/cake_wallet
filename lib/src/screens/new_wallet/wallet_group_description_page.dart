import 'package:cake_wallet/core/new_wallet_arguments.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/themes/extensions/theme_type_images.dart';

class WalletGroupDescriptionPage extends BasePage {
  WalletGroupDescriptionPage({required this.selectedWalletType});

  final WalletType selectedWalletType;

  @override
  String get title => S.current.wallet_group;


  @override
  Widget body(BuildContext context) {

    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Image.asset(currentTheme.type.walletGroupImage, height: 200),
          SizedBox(height: 32),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${S.of(context).wallet_group_description_one} '),
                  TextSpan(
                    text: '${S.of(context).wallet_group.toLowerCase()} ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '${S.of(context).wallet_group_description_two} ',
                  ),
                  TextSpan(
                    text: '${S.of(context).choose_wallet_group} ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: '${S.of(context).wallet_group_description_three} ',
                  ),
                  TextSpan(
                    text: '${S.of(context).create_new_seed} ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: S.of(context).wallet_group_description_four),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.5,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).extension<CakeTextTheme>()!.secondaryTextColor,
              ),
            ),
          ),
          PrimaryButton(
            key: ValueKey('wallet_group_description_page_create_new_seed_button_key'),
            onPressed: () => Navigator.of(context).pushNamed(
              Routes.newWallet,
              arguments: NewWalletArguments(type: selectedWalletType),
            ),
            text: S.of(context).create_new_seed,
            color: Theme.of(context).cardColor,
            textColor: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
          ),
          SizedBox(height: 12),
          PrimaryButton(
            key: ValueKey('wallet_group_description_page_choose_wallet_group_button_key'),
            onPressed: () => Navigator.of(context).pushNamed(
              Routes.walletGroupsDisplayPage,
              arguments: selectedWalletType,
            ),
            text: S.of(context).choose_wallet_group,
            color: Theme.of(context).primaryColor,
            textColor: Colors.white,
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}
