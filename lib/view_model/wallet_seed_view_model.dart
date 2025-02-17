import 'dart:math';

import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_base.dart';

part 'wallet_seed_view_model.g.dart';

class WalletSeedViewModel = WalletSeedViewModelBase with _$WalletSeedViewModel;

abstract class WalletSeedViewModelBase with Store {
  WalletSeedViewModelBase(WalletBase wallet)
      : name = wallet.name,
        seed = wallet.seed!,
        currentOptions = ObservableList<String>(),
        verificationIndices = ObservableList<int>() {
    setupSeedVerification();
  }

  @observable
  String name;

  @observable
  String seed;

  /// The Regex split the words based on any whitespace character.
  ///
  /// Either standard ASCII space (U+0020) or the full-width space character (U+3000) used by the Japanese.
  List<String> get seedSplit => seed.split(RegExp(r'\s+'));

  int get columnCount => seedSplit.length <= 16 ? 2 : 3;

  double get columnAspectRatio => seedSplit.length <= 16 ? 1.8 : 2.8;

  /// The indices of the seed to be verified.
  ObservableList<int> verificationIndices;

  /// The index of the word in verificationIndices being verified.
  @observable
  int currentStepIndex = 0;

  /// The options to be displayed on the page for the current seed step.
  ///
  /// The user has to choose from these.
  ObservableList<String> currentOptions;

  /// The number of words to be verified, linked to a Feature Flag so we can easily modify it.
  int get verificationWordCount {
    final shouldVerify = shouldPerformVerification();

    return shouldVerify ? FeatureFlag.verificationWordsCount : 0;
  }

  /// Then number of wrong entries the user has selected;
  ///
  /// Routes the view to the seed screen if it's up to two.
  @observable
  int wrongEntries = 0;

  int get currentWordIndex => verificationIndices[currentStepIndex];

  String get currentCorrectWord => seedSplit[currentWordIndex];

  @observable
  bool isVerificationComplete = false;

  bool shouldPerformVerification() {
    bool isCI = bool.fromEnvironment('CI_BUILD', defaultValue: false);
    bool isDebug = kDebugMode;

    if (isDebug && !isCI) {
      printV("Skipping verification in debug mode (and when it's not in CI).");
      return false;
    }

    return true;
  }

  void setupSeedVerification() {
    if (verificationWordCount != 0) {
      generateRandomIndices();
      generateOptions();
    }
  }

  /// Generate the indices of the seeds to be verified.
  ///
  /// Structured to be as random as possible.
  @action
  void generateRandomIndices() {
    verificationIndices.clear();
    final random = Random();
    final indices = <int>[];
    while (indices.length < verificationWordCount) {
      final i = random.nextInt(seedSplit.length);
      if (!indices.contains(i)) {
        indices.add(i);
      }
    }

    verificationIndices.addAll(indices);
  }

  /// Generates the options for each index being verified.
  @action
  void generateOptions() {
    currentOptions.clear();

    final correctWord = currentCorrectWord;
    final incorrectWords = seedSplit.where((word) => word != correctWord).toList();
    incorrectWords.shuffle();

    final options = [correctWord, ...incorrectWords.take(5)];
    options.shuffle();

    currentOptions.addAll(options);
  }

  bool isChosenWordCorrect(String chosenWord) {
    if (chosenWord == currentCorrectWord) {
      wrongEntries = 0;

      if (currentStepIndex + 1 < verificationWordCount) {
        currentStepIndex++;
        generateOptions();
      } else {
        // All verification steps completed
        isVerificationComplete = true;
      }

      return true;
    } else {
      wrongEntries++;
      return false;
    }
  }
}
