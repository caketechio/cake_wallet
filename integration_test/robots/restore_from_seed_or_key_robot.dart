import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/restore/wallet_restore_page.dart';
import 'package:cake_wallet/src/widgets/validable_annotated_editable_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class RestoreFromSeedOrKeysPageRobot {
  RestoreFromSeedOrKeysPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isRestoreFromSeedKeyPage() async {
    await commonTestCases.isSpecificPage<WalletRestorePage>();
    await commonTestCases.takeScreenshots('wallet_restore_page');
  }

  Future<void> confirmViewComponentsDisplayProperlyPerPageView() async {
    commonTestCases.hasText(S.current.wallet_name);
    commonTestCases.hasText(S.current.enter_seed_phrase);
    commonTestCases.hasText(S.current.restore_title_from_seed);

    commonTestCases.hasValueKey('wallet_restore_from_seed_wallet_name_textfield_key');
    commonTestCases.hasValueKey('wallet_restore_from_seed_wallet_name_refresh_button_key');
    commonTestCases.hasValueKey('wallet_restore_from_seed_wallet_seeds_paste_button_key');
    commonTestCases.hasValueKey('wallet_restore_from_seed_wallet_seeds_textfield_key');

    commonTestCases.hasText(S.current.private_key, hasWidget: false);
    commonTestCases.hasText(S.current.restore_title_from_keys, hasWidget: false);

    await commonTestCases.swipePage();
    await commonTestCases.defaultSleepTime();

    commonTestCases.hasText(S.current.wallet_name);
    commonTestCases.hasText(S.current.private_key);
    commonTestCases.hasText(S.current.restore_title_from_keys);

    commonTestCases.hasText(S.current.enter_seed_phrase, hasWidget: false);
    commonTestCases.hasText(S.current.restore_title_from_seed, hasWidget: false);

    await commonTestCases.swipePage(swipeRight: false);
  }

  void confirmRestoreButtonDisplays() {
    commonTestCases.hasValueKey('wallet_restore_seed_or_key_restore_button_key');
  }

  void confirmAdvancedSettingButtonDisplays() {
    commonTestCases.hasValueKey('wallet_restore_advanced_settings_button_key');
  }

  Future<void> enterWalletNameText(String walletName, {bool isSeedFormEntry = true}) async {
    await commonTestCases.enterText(
      walletName,
      'wallet_restore_from_${isSeedFormEntry ? 'seed' : 'keys'}_wallet_name_textfield_key',
    );
  }

  Future<void> selectWalletNameFromAvailableOptions({bool isSeedFormEntry = true}) async {
    await commonTestCases.tapItemByKey(
      'wallet_restore_from_${isSeedFormEntry ? 'seed' : 'keys'}_wallet_name_refresh_button_key',
    );
  }

  Future<void> enterSeedPhraseForWalletRestore(String text) async {
    ValidatableAnnotatedEditableTextState seedTextState =
      await tester.state(find.byType(ValidatableAnnotatedEditableText));

    seedTextState.widget.controller.text = text;
    await tester.pumpAndSettle();
  }

  Future<void> enterPasswordForWalletRestore(String text) async {
    await commonTestCases.enterText(
      text,
      'password',
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterPasswordRepeatForWalletRestore(String text) async {
    await commonTestCases.enterText(
      text,
      'repeat_wallet_password',
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterBlockHeightForWalletRestore(String blockHeight) async {
    await commonTestCases.enterText(
      blockHeight,
      'wallet_restore_from_seed_blockheight_textfield_key',
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseSeedTypeForMoneroOrWowneroWallets(MoneroSeedType selectedType) async {
    await commonTestCases.tapItemByKey('wallet_restore_from_seed_seedtype_picker_button_key');

    await commonTestCases.defaultSleepTime();

    await commonTestCases.tapItemByKey('picker_items_index_${selectedType.title}_button_key');
  }

  Future<void> onPasteSeedPhraseButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_restore_from_seed_wallet_seeds_paste_button_key');
  }

  Future<void> enterPrivateKeyForWalletRestore(String privateKey) async {
    await commonTestCases.enterText(
      privateKey,
      'wallet_restore_from_key_private_key_textfield_key',
    );
    await tester.pumpAndSettle();
  }

  Future<void> onRestoreWalletButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_restore_seed_or_key_restore_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
