import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/seed/seed_verification/seed_verification_step_view.dart';
import 'package:cake_wallet/src/screens/seed/seed_verification/seed_verification_success_view.dart';
import 'package:cake_wallet/view_model/wallet_seed_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class SeedVerificationPage extends BasePage {
  final WalletSeedViewModel walletSeedViewModel;

  SeedVerificationPage(this.walletSeedViewModel);

  @override
  String? get title => S.current.verify_seed;

  @override
  Widget body(BuildContext context) {
    return Observer(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: walletSeedViewModel.isVerificationComplete ||
                  walletSeedViewModel.verificationIndices.isEmpty
              ? SeedVerificationSuccessView(
                  key: ValueKey('seed_verification_success_view_page'),
                  imageColor: titleColor(context),
                )
              : SeedVerificationStepView(
                  key: ValueKey('seed_verification_step_view_page'),
                  walletSeedViewModel: walletSeedViewModel,
                  questionTextColor: titleColor(context),
                ),
        );
      },
    );
  }
}
