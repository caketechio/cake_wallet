import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/wallet_seed_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class SeedVerificationStepView extends StatelessWidget {
  const SeedVerificationStepView({
    required this.walletSeedViewModel,
    required this.questionTextColor,
    super.key,
  });

  final WalletSeedViewModel walletSeedViewModel;
  final Color questionTextColor;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 48),
              Align(
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${S.current.seed_position_question_one} ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: questionTextColor,
                        ),
                      ),
                      TextSpan(
                        text: '${getOrdinal(walletSeedViewModel.currentWordIndex + 1)} ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: questionTextColor,
                        ),
                      ),
                      TextSpan(
                        text: S.current.seed_position_question_two,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: questionTextColor,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: walletSeedViewModel.currentOptions.map(
                    (option) {
                      return GestureDetector(
                        key: ValueKey('seed_verification_option_${option}_button_key'),
                        onTap: () async {
                          if (walletSeedViewModel.wrongEntries > 2) return;

                          final isCorrectWord = walletSeedViewModel.isChosenWordCorrect(option);
                          final isSecondWrongEntry = walletSeedViewModel.wrongEntries >= 2;
                          if (!isCorrectWord) {
                            await showBar<void>(
                              context,
                              isSecondWrongEntry
                                  ? S.current.incorrect_seed_option_back
                                  : S.current.incorrect_seed_option,
                            );

                            if (isSecondWrongEntry) {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).cardColor,
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String getOrdinal(int number) {
    // Handle special cases for 11th, 12th, 13th
    final lastTwoDigits = number % 100;
    if (lastTwoDigits >= 11 && lastTwoDigits <= 13) {
      return '${number}th';
    }

    // Check the last digit for st, nd, rd, or default th
    final lastDigit = number % 10;
    switch (lastDigit) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }
}
