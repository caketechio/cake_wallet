import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/src/screens/wallet_keys/wallet_keys_page.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/monero_wallet_keys.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:cw_wownero/wownero_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyseed/polyseed.dart';

import '../components/common_test_cases.dart';

class WalletKeysAndSeedPageRobot {
  WalletKeysAndSeedPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  final CommonTestCases commonTestCases;

  Future<void> isWalletKeysAndSeedPage() async {
    await commonTestCases.isSpecificPage<WalletKeysPage>();
    await commonTestCases.takeScreenshots('wallet_keys_page');
  }

  void hasTitle() {
    final walletKeysPage = tester.widget<WalletKeysPage>(find.byType(WalletKeysPage));
    final walletKeysViewModel = walletKeysPage.walletKeysViewModel;
    commonTestCases.hasText(walletKeysViewModel.title);
  }

  void hasShareWarning() {
    commonTestCases.hasText(S.current.do_not_share_warning_text.toUpperCase());
  }

  Future<void> confirmWalletCredentials(WalletType walletType) async {
    final walletKeysPage = tester.widget<WalletKeysPage>(find.byType(WalletKeysPage));
    final walletKeysViewModel = walletKeysPage.walletKeysViewModel;

    final appStore = walletKeysViewModel.appStore;
    final walletName = walletType.name;
    bool hasSeed = appStore.wallet!.seed != null;
    bool hasHexSeed = appStore.wallet!.hexSeed != null;
    bool hasPrivateKey = appStore.wallet!.privateKey != null;

    if (walletType == WalletType.monero) {
      final moneroWallet = appStore.wallet as MoneroWalletBase;
      final lang = PolyseedLang.getByPhrase(moneroWallet.seed);
      final legacySeed = moneroWallet.seedLegacy(lang.nameEnglish);

      await _confirmMoneroWalletCredentials(
        appStore,
        walletName,
        moneroWallet.seed,
        legacySeed,
      );
    }

    if (walletType == WalletType.wownero) {
      final wowneroWallet = appStore.wallet as WowneroWallet;
      final lang = PolyseedLang.getByPhrase(wowneroWallet.seed);
      final legacySeed = wowneroWallet.seedLegacy(lang.nameEnglish);

      await _confirmMoneroWalletCredentials(
        appStore,
        walletName,
        wowneroWallet.seed,
        legacySeed,
      );
    }

    if (walletType == WalletType.bitcoin ||
        walletType == WalletType.litecoin ||
        walletType == WalletType.bitcoinCash) {
      commonTestCases.hasText(appStore.wallet!.seed!);
      tester.printToConsole('$walletName wallet has seeds properly displayed');
    }

    if (isEVMCompatibleChain(walletType) ||
        walletType == WalletType.solana ||
        walletType == WalletType.tron) {
      if (hasSeed) {
        commonTestCases.hasText(appStore.wallet!.seed!);
        tester.printToConsole('$walletName wallet has seeds properly displayed');
      }
      if (hasPrivateKey) {
        commonTestCases.hasText(appStore.wallet!.privateKey!);
        tester.printToConsole('$walletName wallet has private key properly displayed');
      }
    }

    if (walletType == WalletType.nano || walletType == WalletType.banano) {
      if (hasSeed) {
        commonTestCases.hasText(appStore.wallet!.seed!);
        tester.printToConsole('$walletName wallet has seeds properly displayed');
      }
      if (hasHexSeed) {
        commonTestCases.hasText(appStore.wallet!.hexSeed!);
        tester.printToConsole('$walletName wallet has hexSeed properly displayed');
      }
      if (hasPrivateKey) {
        commonTestCases.hasText(appStore.wallet!.privateKey!);
        tester.printToConsole('$walletName wallet has private key properly displayed');
      }
    }

    await commonTestCases.defaultSleepTime(seconds: 5);
  }

  Future<void> _confirmMoneroWalletCredentials(
    AppStore appStore,
    String walletName,
    String seed,
    String legacySeed,
  ) async {
    final keys = appStore.wallet!.keys as MoneroWalletKeys;

    final hasPublicSpendKey = commonTestCases.isKeyPresent(
      '${walletName}_wallet_public_spend_key_item_key',
    );
    final hasPrivateSpendKey = commonTestCases.isKeyPresent(
      '${walletName}_wallet_private_spend_key_item_key',
    );
    final hasPublicViewKey = commonTestCases.isKeyPresent(
      '${walletName}_wallet_public_view_key_item_key',
    );
    final hasPrivateViewKey = commonTestCases.isKeyPresent(
      '${walletName}_wallet_private_view_key_item_key',
    );
    final hasSeeds = seed.isNotEmpty;
    final hasSeedLegacy = Polyseed.isValidSeed(seed);

    if (hasPublicSpendKey) {
      commonTestCases.hasText(keys.publicSpendKey);
      tester.printToConsole('$walletName wallet has public spend key properly displayed');
    }
    if (hasPrivateSpendKey) {
      commonTestCases.hasText(keys.privateSpendKey);
      tester.printToConsole('$walletName wallet has private spend key properly displayed');
    }
    if (hasPublicViewKey) {
      commonTestCases.hasText(keys.publicViewKey);
      tester.printToConsole('$walletName wallet has public view key properly displayed');
    }
    if (hasPrivateViewKey) {
      commonTestCases.hasText(keys.privateViewKey);
      tester.printToConsole('$walletName wallet has private view key properly displayed');
    }
    if (hasSeeds) {
      await commonTestCases.dragUntilVisible(
        '${walletName}_wallet_seed_item_key',
        'wallet_keys_page_credentials_list_view_key',
      );
      commonTestCases.hasText(seed);
      tester.printToConsole('$walletName wallet has seeds properly displayed');
    }
    if (hasSeedLegacy) {
      await commonTestCases.dragUntilVisible(
        '${walletName}_wallet_seed_legacy_item_key',
        'wallet_keys_page_credentials_list_view_key',
      );
      commonTestCases.hasText(legacySeed);
      tester.printToConsole('$walletName wallet has legacy seeds properly displayed');
    }
  }

  Future<void> backToDashboard() async {
    tester.printToConsole('Going back to dashboard from credentials page');
    await commonTestCases.goBack();
    await commonTestCases.goBack();
  }
}
