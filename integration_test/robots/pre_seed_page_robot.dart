import 'package:cake_wallet/src/screens/seed/pre_seed_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class PreSeedPageRobot {
  PreSeedPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isPreSeedPage() async {
    await commonTestCases.isSpecificPage<PreSeedPage>();
    await commonTestCases.takeScreenshots('pre_seed_page');
  }

  Future<void> onConfirmButtonPressed() async {
    await commonTestCases.tapItemByKey('pre_seed_page_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
