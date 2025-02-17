import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/new_wallet/new_wallet_type_page.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class NewWalletTypePageRobot {
  NewWalletTypePageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isNewWalletTypePage() async {
    await commonTestCases.isSpecificPage<NewWalletTypePage>();
    await commonTestCases.takeScreenshots('new_wallet_type_page');
  }

  void displaysCorrectTitle(bool isCreate) {
    commonTestCases.hasText(
      isCreate ? S.current.wallet_list_create_new_wallet : S.current.wallet_list_restore_wallet,
    );
  }

  void hasWalletTypeForm() {
    commonTestCases.hasType<WalletTypeForm>();
  }

  void displaysCorrectImage(ThemeType type) {
    final walletTypeImage = Image.asset('assets/images/wallet_type.png').image;
    final walletTypeLightImage = Image.asset('assets/images/wallet_type_light.png').image;

    find.image(
      type == ThemeType.dark ? walletTypeImage : walletTypeLightImage,
    );
  }

  Future<void> findParticularWalletTypeInScrollableList(WalletType type) async {
    final scrollableWidget = find.descendant(
      of: find.byKey(Key('new_wallet_type_scrollable_key')),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      find.byKey(ValueKey('new_wallet_type_${type.name}_button_key')),
      300,
      scrollable: scrollableWidget,
    );
  }

  Future<void> selectWalletType(WalletType type) async {
    await commonTestCases.tapItemByKey('new_wallet_type_${type.name}_button_key');
  }

  Future<void> onNextButtonPressed() async {
    await commonTestCases.tapItemByKey('new_wallet_type_next_button_key');
  }
}
