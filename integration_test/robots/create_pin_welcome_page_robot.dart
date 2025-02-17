import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/welcome/create_pin_welcome_page.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class CreatePinWelcomePageRobot {
  CreatePinWelcomePageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isCreatePinWelcomePage() async {
    await commonTestCases.isSpecificPage<CreatePinWelcomePage>();
    await commonTestCases.takeScreenshots('create_pin_welcome_page');
  }

  void hasTitle() {
    String title;
    if (isMoneroOnly) {
      title = S.current.monero_com;
    }

    if (isHaven) {
      title = S.current.haven_app;
    }

    title = S.current.cake_wallet;

    commonTestCases.hasText(title);
  }

  void hasDescription() {
    String description;
    if (isMoneroOnly) {
      description = S.current.monero_com_wallet_text;
    }

    if (isHaven) {
      description = S.current.haven_app_wallet_text;
    }

    description = S.current.new_first_wallet_text;

    commonTestCases.hasText(description);
  }

  Future<void> tapSetAPinButton() async {
    await commonTestCases.tapItemByKey('create_pin_welcome_page_create_a_pin_button_key');

    await commonTestCases.defaultSleepTime();
  }
}
