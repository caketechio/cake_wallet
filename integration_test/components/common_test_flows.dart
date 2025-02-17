import 'dart:io';

import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/reactions/bip39_wallet_utils.dart';
import 'package:cake_wallet/wallet_types.g.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cake_wallet/main.dart' as app;

import '../robots/create_pin_welcome_page_robot.dart';
import '../robots/dashboard_page_robot.dart';
import '../robots/disclaimer_page_robot.dart';
import '../robots/new_wallet_page_robot.dart';
import '../robots/new_wallet_type_page_robot.dart';
import '../robots/pre_seed_page_robot.dart';
import '../robots/restore_from_seed_or_key_robot.dart';
import '../robots/restore_options_page_robot.dart';
import '../robots/seed_verification_page_robot.dart';
import '../robots/setup_pin_code_robot.dart';
import '../robots/wallet_group_description_page_robot.dart';
import '../robots/wallet_list_page_robot.dart';
import '../robots/wallet_seed_page_robot.dart';
import '../robots/welcome_page_robot.dart';
import 'common_test_cases.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

import 'common_test_constants.dart';

class CommonTestFlows {
  CommonTestFlows(this._tester)
      : _commonTestCases = CommonTestCases(_tester),
        _welcomePageRobot = WelcomePageRobot(_tester),
        _preSeedPageRobot = PreSeedPageRobot(_tester),
        _setupPinCodeRobot = SetupPinCodeRobot(_tester),
        _dashboardPageRobot = DashboardPageRobot(_tester),
        _newWalletPageRobot = NewWalletPageRobot(_tester),
        _disclaimerPageRobot = DisclaimerPageRobot(_tester),
        _walletSeedPageRobot = WalletSeedPageRobot(_tester),
        _walletListPageRobot = WalletListPageRobot(_tester),
        _newWalletTypePageRobot = NewWalletTypePageRobot(_tester),
        _restoreOptionsPageRobot = RestoreOptionsPageRobot(_tester),
        _seedVerificationPageRobot = SeedVerificationPageRobot(_tester),
        _createPinWelcomePageRobot = CreatePinWelcomePageRobot(_tester),
        _restoreFromSeedOrKeysPageRobot = RestoreFromSeedOrKeysPageRobot(_tester),
        _walletGroupDescriptionPageRobot = WalletGroupDescriptionPageRobot(_tester);

  final WidgetTester _tester;
  final CommonTestCases _commonTestCases;

  final WelcomePageRobot _welcomePageRobot;
  final PreSeedPageRobot _preSeedPageRobot;
  final SetupPinCodeRobot _setupPinCodeRobot;
  final NewWalletPageRobot _newWalletPageRobot;
  final DashboardPageRobot _dashboardPageRobot;
  final DisclaimerPageRobot _disclaimerPageRobot;
  final WalletSeedPageRobot _walletSeedPageRobot;
  final WalletListPageRobot _walletListPageRobot;
  final NewWalletTypePageRobot _newWalletTypePageRobot;
  final RestoreOptionsPageRobot _restoreOptionsPageRobot;
  final CreatePinWelcomePageRobot _createPinWelcomePageRobot;
  final SeedVerificationPageRobot _seedVerificationPageRobot;
  final RestoreFromSeedOrKeysPageRobot _restoreFromSeedOrKeysPageRobot;
  final WalletGroupDescriptionPageRobot _walletGroupDescriptionPageRobot;

  //* ========== Handles flow to start the app afresh and accept disclaimer =============
  Future<void> startAppFlow(Key key) async {
    await app.main(topLevelKey: ValueKey('send_flow_test_app_key'));

    await _tester.pumpAndSettle();

    // --------- Disclaimer Page ------------
    // Tap checkbox to accept disclaimer
    await _disclaimerPageRobot.tapDisclaimerCheckbox();

    // Tap accept button
    await _disclaimerPageRobot.tapAcceptButton();
  }

  //* ========== Handles flow from welcome to creating a new wallet ===============
  Future<void> welcomePageToCreateNewWalletFlow(
    WalletType walletTypeToCreate,
    List<int> walletPin,
  ) async {
    await _welcomeToCreateWalletPath(walletTypeToCreate, walletPin);

    await _generateNewWalletDetails();

    await _confirmPreSeedInfo();

    await _confirmWalletDetails();

    await _verifyWalletSeed();
  }

  //* ========== Handles flow from welcome to restoring wallet from seeds ===============
  Future<void> welcomePageToRestoreWalletThroughSeedsFlow(
    WalletType walletTypeToRestore,
    String walletSeed,
    List<int> walletPin,
  ) async {
    await _welcomeToRestoreFromSeedsOrKeysPath(walletTypeToRestore, walletPin);
    await _restoreFromSeeds(walletTypeToRestore, walletSeed);
  }

  //* ========== Handles flow from welcome to restoring wallet from keys ===============
  Future<void> welcomePageToRestoreWalletThroughKeysFlow(
    WalletType walletTypeToRestore,
    List<int> walletPin,
  ) async {
    await _welcomeToRestoreFromSeedsOrKeysPath(walletTypeToRestore, walletPin);
    await _restoreFromKeys();
  }

  //* ========== Handles switching to wallet list or menu from dashboard ===============
  Future<void> switchToWalletMenuFromDashboardPage() async {
    _tester.printToConsole('Switching to Wallet Menu');
    await _dashboardPageRobot.openDrawerMenu();

    await _dashboardPageRobot.dashboardMenuWidgetRobot.navigateToWalletMenu();
  }

  void confirmAllAvailableWalletTypeIconsDisplayCorrectly() {
    for (var walletType in availableWalletTypes) {
      final imageUrl = walletTypeToCryptoCurrency(walletType).iconPath;

      final walletIconFinder = find.image(
        Image.asset(
          imageUrl!,
          width: 32,
          height: 32,
        ).image,
      );

      expect(walletIconFinder, findsAny);
    }
  }

  //* ========== Handles creating new wallet flow from wallet list/menu ===============
  Future<void> createNewWalletFromWalletMenu(WalletType walletTypeToCreate) async {
    _tester.printToConsole('Creating ${walletTypeToCreate.name} Wallet');
    await _walletListPageRobot.navigateToCreateNewWalletPage();
    await _commonTestCases.defaultSleepTime();

    await _selectWalletTypeForWallet(walletTypeToCreate);
    await _commonTestCases.defaultSleepTime();

    // ---- Wallet Group/New Seed Implementation Comes here
    await _walletGroupDescriptionPageFlow(true, walletTypeToCreate);

    await _generateNewWalletDetails();

    await _confirmPreSeedInfo();

    await _confirmWalletDetails();

    await _verifyWalletSeed();

    await _commonTestCases.defaultSleepTime();
  }

  Future<void> _walletGroupDescriptionPageFlow(bool isNewSeed, WalletType walletType) async {
    if (!isBIP39Wallet(walletType)) return;

    await _walletGroupDescriptionPageRobot.isWalletGroupDescriptionPage();

    if (isNewSeed) {
      await _walletGroupDescriptionPageRobot.navigateToCreateNewSeedPage();
    } else {
      await _walletGroupDescriptionPageRobot.navigateToChooseWalletGroup();
    }
  }

  //* ========== Handles restore wallet flow from wallet list/menu ===============
  Future<void> restoreWalletFromWalletMenu(WalletType walletType, String walletSeed) async {
    _tester.printToConsole('Restoring ${walletType.name} Wallet');
    await _walletListPageRobot.navigateToRestoreWalletOptionsPage();
    await _commonTestCases.defaultSleepTime();

    if (!Platform.isLinux) await _restoreOptionsPageRobot.navigateToRestoreFromSeedsOrKeysPage();
    if (!Platform.isLinux) await _commonTestCases.defaultSleepTime();

    await _selectWalletTypeForWallet(walletType);
    await _commonTestCases.defaultSleepTime();

    await _restoreFromSeeds(walletType, walletSeed);
    await _commonTestCases.defaultSleepTime();
  }

  //* ========== Handles setting up pin code for wallet on first install ===============
  Future<void> setupPinCodeForWallet(List<int> pin) async {
    if (Platform.isLinux) return;
    // ----------- SetupPinCode Page -------------
    // Confirm initial defaults - Widgets to be displayed etc
    await _setupPinCodeRobot.isSetupPinCodePage();

    await _setupPinCodeRobot.enterPinCode(pin);
    await _setupPinCodeRobot.enterPinCode(pin);
    await _setupPinCodeRobot.tapSuccessButton();
  }

  Future<void> _welcomeToCreateWalletPath(
    WalletType walletTypeToCreate,
    List<int> pin,
  ) async {
    await _createPinWelcomePageRobot.tapSetAPinButton();

    await setupPinCodeForWallet(pin);

    await _welcomePageRobot.navigateToCreateNewWalletPage();

    await _selectWalletTypeForWallet(walletTypeToCreate);
  }

  Future<void> _welcomeToRestoreFromSeedsOrKeysPath(
    WalletType walletTypeToRestore,
    List<int> pin,
  ) async {
    await _createPinWelcomePageRobot.tapSetAPinButton();

    await setupPinCodeForWallet(pin);

    await _welcomePageRobot.navigateToRestoreWalletPage();

    if (!Platform.isLinux) await _restoreOptionsPageRobot.navigateToRestoreFromSeedsOrKeysPage();

    await _selectWalletTypeForWallet(walletTypeToRestore);
  }

  //* ============ Handles New Wallet Type Page ==================
  Future<void> _selectWalletTypeForWallet(WalletType type) async {
    // ----------- NewWalletType Page -------------
    // Confirm scroll behaviour works properly
    await _newWalletTypePageRobot.findParticularWalletTypeInScrollableList(type);

    // Select a wallet and route to next page
    await _newWalletTypePageRobot.selectWalletType(type);
    await _newWalletTypePageRobot.onNextButtonPressed();
  }

  //* ============ Handles New Wallet Page ==================
  Future<void> _generateNewWalletDetails() async {
    await _newWalletPageRobot.isNewWalletPage();

    await _newWalletPageRobot.generateWalletName();

    if (Platform.isLinux) {
      // manual pin input
      await _restoreFromSeedOrKeysPageRobot
          .enterPasswordForWalletRestore(CommonTestConstants.pin.join(""));
      await _restoreFromSeedOrKeysPageRobot
          .enterPasswordRepeatForWalletRestore(CommonTestConstants.pin.join(""));
    }

    await _newWalletPageRobot.onNextButtonPressed();
  }

  //* ============ Handles Pre Seed Page =====================
  Future<void> _confirmPreSeedInfo() async {
    await _preSeedPageRobot.isPreSeedPage();

    await _preSeedPageRobot.onConfirmButtonPressed();
  }

  //* ============ Handles Wallet Seed Page ==================
  Future<void> _confirmWalletDetails() async {
    await _walletSeedPageRobot.isWalletSeedPage();

    _walletSeedPageRobot.confirmWalletDetailsDisplayCorrectly();

    _walletSeedPageRobot.confirmWalletSeedReminderDisplays();

    // await _walletSeedPageRobot.onCopySeedsButtonPressed();

    await _walletSeedPageRobot.onVerifySeedButtonPressed();
  }

  //* ============ Handles Wallet Seed Verification Page ==================

  Future<void> _verifyWalletSeed() async {
    await _seedVerificationPageRobot.isSeedVerificationPage();

    _seedVerificationPageRobot.hasTitle();

    await _seedVerificationPageRobot.verifyWalletSeeds();
  }

  //* Main Restore Actions - On the RestoreFromSeed/Keys Page - Restore from Seeds Action
  Future<void> _restoreFromSeeds(WalletType type, String walletSeed) async {
    // ----------- RestoreFromSeedOrKeys Page -------------

    await _restoreFromSeedOrKeysPageRobot.selectWalletNameFromAvailableOptions();
    await _restoreFromSeedOrKeysPageRobot.enterSeedPhraseForWalletRestore(walletSeed);

    final numberOfWords = walletSeed.split(' ').length;

    if (numberOfWords == 25 && (type == WalletType.monero)) {
      await _restoreFromSeedOrKeysPageRobot
          .chooseSeedTypeForMoneroOrWowneroWallets(MoneroSeedType.legacy);

      // Using a constant value of 2831400 for the blockheight as its the restore blockheight for our testing wallet
      await _restoreFromSeedOrKeysPageRobot
          .enterBlockHeightForWalletRestore(secrets.moneroTestWalletBlockHeight);
    }

    if (Platform.isLinux) {
      // manual pin input
      await _restoreFromSeedOrKeysPageRobot
          .enterPasswordForWalletRestore(CommonTestConstants.pin.join(""));
      await _restoreFromSeedOrKeysPageRobot
          .enterPasswordRepeatForWalletRestore(CommonTestConstants.pin.join(""));
    }

    await _restoreFromSeedOrKeysPageRobot.onRestoreWalletButtonPressed();
  }

  //* Main Restore Actions - On the RestoreFromSeed/Keys Page - Restore from Keys Action
  Future<void> _restoreFromKeys() async {
    await _commonTestCases.swipePage();
    await _commonTestCases.defaultSleepTime();

    await _restoreFromSeedOrKeysPageRobot.selectWalletNameFromAvailableOptions(
      isSeedFormEntry: false,
    );

    await _restoreFromSeedOrKeysPageRobot.enterSeedPhraseForWalletRestore('');
    await _restoreFromSeedOrKeysPageRobot.onRestoreWalletButtonPressed();
  }

  //* ====== Utility Function to get test wallet seeds for each wallet type ========
  String getWalletSeedsByWalletType(WalletType walletType) {
    switch (walletType) {
      case WalletType.monero:
        return secrets.moneroTestWalletSeeds;
      case WalletType.bitcoin:
        return secrets.bitcoinTestWalletSeeds;
      case WalletType.ethereum:
        return secrets.ethereumTestWalletSeeds;
      case WalletType.litecoin:
        return secrets.litecoinTestWalletSeeds;
      case WalletType.bitcoinCash:
        return secrets.bitcoinCashTestWalletSeeds;
      case WalletType.polygon:
        return secrets.polygonTestWalletSeeds;
      case WalletType.solana:
        return secrets.solanaTestWalletSeeds;
      case WalletType.tron:
        return secrets.tronTestWalletSeeds;
      case WalletType.nano:
        return secrets.nanoTestWalletSeeds;
      case WalletType.wownero:
        return secrets.wowneroTestWalletSeeds;
      default:
        return '';
    }
  }

  //* ====== Utility Function to get test receive address for each wallet type ========
  String getReceiveAddressByWalletType(WalletType walletType) {
    switch (walletType) {
      case WalletType.monero:
        return secrets.moneroTestWalletReceiveAddress;
      case WalletType.bitcoin:
        return secrets.bitcoinTestWalletReceiveAddress;
      case WalletType.ethereum:
        return secrets.ethereumTestWalletReceiveAddress;
      case WalletType.litecoin:
        return secrets.litecoinTestWalletReceiveAddress;
      case WalletType.bitcoinCash:
        return secrets.bitcoinCashTestWalletReceiveAddress;
      case WalletType.polygon:
        return secrets.polygonTestWalletReceiveAddress;
      case WalletType.solana:
        return secrets.solanaTestWalletReceiveAddress;
      case WalletType.tron:
        return secrets.tronTestWalletReceiveAddress;
      case WalletType.nano:
        return secrets.nanoTestWalletReceiveAddress;
      case WalletType.wownero:
        return secrets.wowneroTestWalletReceiveAddress;
      default:
        return '';
    }
  }
}
