import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/restore/wallet_restore_from_keys_form.dart';
import 'package:cake_wallet/src/screens/restore/wallet_restore_from_seed_form.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/keyboard_done_button.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/themes/extensions/keyboard_theme.dart';
import 'package:cake_wallet/themes/extensions/wallet_list_theme.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/restore/restore_mode.dart';
import 'package:cake_wallet/view_model/seed_type_view_model.dart';
import 'package:cake_wallet/view_model/wallet_restore_view_model.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:mobx/mobx.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WalletRestorePage extends BasePage {
  WalletRestorePage(this.walletRestoreViewModel, this.seedTypeViewModel)
      : walletRestoreFromSeedFormKey = GlobalKey<WalletRestoreFromSeedFormState>(),
        walletRestoreFromKeysFormKey = GlobalKey<WalletRestoreFromKeysFromState>(),
        _pages = [],
        _blockHeightFocusNode = FocusNode(),
        _controller = PageController(initialPage: 0) {
    walletRestoreViewModel.availableModes.forEach((mode) {
      switch (mode) {
        case WalletRestoreMode.seed:
          _pages.add(WalletRestoreFromSeedForm(
              seedTypeViewModel: seedTypeViewModel,
              displayBlockHeightSelector:
                  walletRestoreViewModel.hasBlockchainHeightLanguageSelector,
              displayLanguageSelector: walletRestoreViewModel.hasSeedLanguageSelector,
              displayPassphrase: walletRestoreViewModel.hasPassphrase,
              type: walletRestoreViewModel.type,
              key: walletRestoreFromSeedFormKey,
              blockHeightFocusNode: _blockHeightFocusNode,
              onHeightOrDateEntered: (value) {
                if (_isValidSeed()) {
                  walletRestoreViewModel.isButtonEnabled = value;
                }
              },
              onSeedChange: (String seed) {
                final isPolyseed = walletRestoreViewModel.isPolyseed(seed);
                _validateOnChange(isPolyseed: isPolyseed);
              },
              onLanguageChange: (String language) {
                final isPolyseed = language.startsWith("POLYSEED_");
                _validateOnChange(isPolyseed: isPolyseed);
              },
              displayWalletPassword: walletRestoreViewModel.hasWalletPassword,
              onPasswordChange: (String password) => walletRestoreViewModel.walletPassword = password,
              onRepeatedPasswordChange: (String repeatedPassword) => walletRestoreViewModel.repeatedWalletPassword = repeatedPassword));
          break;
        case WalletRestoreMode.keys:
          _pages.add(WalletRestoreFromKeysFrom(
              key: walletRestoreFromKeysFormKey,
              walletRestoreViewModel: walletRestoreViewModel,
              onPrivateKeyChange: (String seed) {
                if (walletRestoreViewModel.type == WalletType.nano ||
                    walletRestoreViewModel.type == WalletType.banano) {
                  walletRestoreViewModel.isButtonEnabled = _isValidSeedKey();
                }
              },
              displayPrivateKeyField: walletRestoreViewModel.hasRestoreFromPrivateKey,
              displayWalletPassword: walletRestoreViewModel.hasWalletPassword,
              onPasswordChange: (String password) => walletRestoreViewModel.walletPassword = password,
              onRepeatedPasswordChange: (String repeatedPassword) => walletRestoreViewModel.repeatedWalletPassword = repeatedPassword,
              onHeightOrDateEntered: (value) => walletRestoreViewModel.isButtonEnabled = value));
          break;
        default:
          break;
      }
    });
  }

  bool _formProcessing = false;

  @override
  Widget middle(BuildContext context) => Observer(
      builder: (_) => Text(
            walletRestoreViewModel.mode == WalletRestoreMode.seed
                ? S.current.restore_title_from_seed
                : S.current.restore_title_from_keys,
            style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Lato',
                color: titleColor(context)),
          ));

  final WalletRestoreViewModel walletRestoreViewModel;
  final SeedTypeViewModel seedTypeViewModel;
  final PageController _controller;
  final List<Widget> _pages;
  final GlobalKey<WalletRestoreFromSeedFormState> walletRestoreFromSeedFormKey;
  final GlobalKey<WalletRestoreFromKeysFromState> walletRestoreFromKeysFormKey;
  final FocusNode _blockHeightFocusNode;

  // DerivationType derivationType = DerivationType.unknown;
  // String? derivationPath = null;
  DerivationInfo? derivationInfo;

  @override
  Function(BuildContext)? get pushToNextWidget => (context) {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.focusedChild?.unfocus();
        }
      };

  @override
  Widget body(BuildContext context) {
    reaction((_) => walletRestoreViewModel.state, (ExecutionState state) {
      if (state is FailureState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showPopUp<void>(
              context: context,
              builder: (_) {
                return AlertWithOneAction(
                    alertTitle: S.current.new_wallet,
                    alertContent: state.error,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop());
              });
        });
      }
    });

    reaction((_) => walletRestoreViewModel.mode, (WalletRestoreMode mode) {
      walletRestoreViewModel.isButtonEnabled = false;
      walletRestoreViewModel.walletPassword = null;
      walletRestoreViewModel.repeatedWalletPassword = null;

      walletRestoreFromSeedFormKey
          .currentState!.blockchainHeightKey.currentState!.restoreHeightController.text = '';
      walletRestoreFromSeedFormKey
          .currentState!.blockchainHeightKey.currentState!.dateController.text = '';
      walletRestoreFromSeedFormKey.currentState!.nameTextEditingController.text = '';

      walletRestoreFromKeysFormKey
          .currentState!.blockchainHeightKey.currentState!.restoreHeightController.text = '';
      walletRestoreFromKeysFormKey
          .currentState!.blockchainHeightKey.currentState!.dateController.text = '';
      walletRestoreFromKeysFormKey.currentState!.nameTextEditingController.text = '';
    });

    return KeyboardActions(
      config: KeyboardActionsConfig(
        keyboardActionsPlatform: KeyboardActionsPlatform.IOS,
        keyboardBarColor: Theme.of(context).extension<KeyboardTheme>()!.keyboardBarColor,
        nextFocus: false,
        actions: [
          KeyboardActionsItem(
            focusNode: _blockHeightFocusNode,
            toolbarButtons: [(_) => KeyboardDoneButton()],
          )
        ],
      ),
      child: Container(
        height: 0,
        color: Theme.of(context).colorScheme.background,
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: PageView.builder(
                    onPageChanged: (page) {
                      walletRestoreViewModel.mode =
                          page == 0 ? WalletRestoreMode.seed : WalletRestoreMode.keys;
                    },
                    controller: _controller,
                    itemCount: _pages.length,
                    itemBuilder: (_, index) => SingleChildScrollView(child: _pages[index]),
                  ),
                ),
                if (_pages.length > 1)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Semantics(
                      button: false,
                      label: 'Page Indicator',
                      hint: 'Swipe to change restore mode',
                      excludeSemantics: true,
                      child: SmoothPageIndicator(
                        controller: _controller,
                        count: _pages.length,
                        effect: ColorTransitionEffect(
                          spacing: 6.0,
                          radius: 6.0,
                          dotWidth: 6.0,
                          dotHeight: 6.0,
                          dotColor: Theme.of(context).hintColor.withOpacity(0.5),
                          activeDotColor: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 24, left: 24, right: 24),
                  child: Column(
                    children: [
                      Observer(
                        builder: (context) {
                          return LoadingPrimaryButton(
                            onPressed: () async {
                              await _confirmForm(context);
                            },
                            text: S.of(context).restore_recover,
                            color: Theme.of(context)
                                .extension<WalletListTheme>()!
                                .createNewWalletButtonBackgroundColor,
                            textColor: Theme.of(context)
                                .extension<WalletListTheme>()!
                                .restoreWalletButtonTextColor,
                            isLoading: walletRestoreViewModel.state is IsExecutingState,
                            isDisabled: !walletRestoreViewModel.isButtonEnabled,
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed(Routes.advancedPrivacySettings, arguments: {
                            'type': walletRestoreViewModel.type,
                            'useTestnet': walletRestoreViewModel.useTestnet,
                            'toggleTestnet': walletRestoreViewModel.toggleUseTestnet
                          });
                        },
                        child: Text(S.of(context).advanced_settings),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validateOnChange({bool isPolyseed = false}) {
    if (!isPolyseed && walletRestoreViewModel.hasBlockchainHeightLanguageSelector) {
      final hasHeight = walletRestoreFromSeedFormKey
          .currentState?.blockchainHeightKey.currentState?.restoreHeightController.text.isNotEmpty;

      if (hasHeight == true) {
        walletRestoreViewModel.isButtonEnabled = _isValidSeed();
      }
    } else {
      walletRestoreViewModel.isButtonEnabled = _isValidSeed();
    }
  }

  bool _isValidSeed() {
    final seedPhrase =
        walletRestoreFromSeedFormKey.currentState!.seedWidgetStateKey.currentState!.text;
    if (walletRestoreViewModel.isPolyseed(seedPhrase)) return true;

    final seedWords = seedPhrase.split(' ');

    if (seedWords.length == 14 && walletRestoreViewModel.type == WalletType.wownero) return true;

    if ((walletRestoreViewModel.type == WalletType.monero ||
            walletRestoreViewModel.type == WalletType.wownero ||
            walletRestoreViewModel.type == WalletType.haven) &&
        seedWords.length != WalletRestoreViewModelBase.moneroSeedMnemonicLength) {
      return false;
    }

    if ((walletRestoreViewModel.type == WalletType.litecoin) &&
        (seedWords.length != WalletRestoreViewModelBase.electrumSeedMnemonicLength &&
            seedWords.length != WalletRestoreViewModelBase.electrumShortSeedMnemonicLength)) {
      return false;
    }

    // bip39:
    const validSeedLengths = [12, 18, 24];
    final type = walletRestoreViewModel.type;
    if ((type == WalletType.bitcoin || type == WalletType.lightning) &&
        !(validSeedLengths.contains(seedWords.length))) {
      return false;
    }

    final words =
        walletRestoreFromSeedFormKey.currentState!.seedWidgetStateKey.currentState!.words.toSet();
    return seedWords.toSet().difference(words).toSet().isEmpty;
  }

  bool _isValidSeedKey() {
    final seedKey = walletRestoreFromKeysFormKey.currentState!.privateKeyController.text;

    if (seedKey.length != 64 && seedKey.length != 128) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> _credentials() {
    final credentials = <String, dynamic>{};

    if (walletRestoreViewModel.mode == WalletRestoreMode.seed) {
      credentials['seed'] =
          walletRestoreFromSeedFormKey.currentState!.seedWidgetStateKey.currentState!.text;

      if (walletRestoreViewModel.hasBlockchainHeightLanguageSelector) {
        credentials['height'] =
            walletRestoreFromSeedFormKey.currentState!.blockchainHeightKey.currentState?.height ??
                -1;
      }

      if (walletRestoreViewModel.hasPassphrase) {
        credentials['passphrase'] =
            walletRestoreFromSeedFormKey.currentState!.passphraseController.text;
      }

      credentials['name'] =
          walletRestoreFromSeedFormKey.currentState!.nameTextEditingController.text;
    } else if (walletRestoreViewModel.mode == WalletRestoreMode.keys) {
      if (walletRestoreViewModel.hasRestoreFromPrivateKey) {
        credentials['private_key'] =
            walletRestoreFromKeysFormKey.currentState!.privateKeyController.text;
        credentials['name'] =
            walletRestoreFromKeysFormKey.currentState!.nameTextEditingController.text;
      } else {
        credentials['address'] = walletRestoreFromKeysFormKey.currentState!.addressController.text;
        credentials['viewKey'] = walletRestoreFromKeysFormKey.currentState!.viewKeyController.text;
        credentials['spendKey'] =
            walletRestoreFromKeysFormKey.currentState!.spendKeyController.text;
        credentials['height'] =
            walletRestoreFromKeysFormKey.currentState!.blockchainHeightKey.currentState!.height;
        credentials['name'] =
            walletRestoreFromKeysFormKey.currentState!.nameTextEditingController.text;
      }
    }

    credentials['derivationInfo'] = this.derivationInfo;
    credentials['walletType'] = walletRestoreViewModel.type;
    return credentials;
  }

  Future<void> _confirmForm(BuildContext context) async {
    if (_formProcessing) return;
    _formProcessing = true;
    try {
      // Dismissing all visible keyboard to provide context for navigation
      FocusManager.instance.primaryFocus?.unfocus();

      late BuildContext? formContext;
      late GlobalKey<FormState>? formKey;
      late String name;
      if (walletRestoreViewModel.mode == WalletRestoreMode.seed) {
        formContext = walletRestoreFromSeedFormKey.currentContext;
        formKey = walletRestoreFromSeedFormKey.currentState!.formKey;
        name = walletRestoreFromSeedFormKey.currentState!.nameTextEditingController.value.text;
      } else if (walletRestoreViewModel.mode == WalletRestoreMode.keys) {
        formContext = walletRestoreFromKeysFormKey.currentContext;
        formKey = walletRestoreFromKeysFormKey.currentState!.formKey;
        name = walletRestoreFromKeysFormKey.currentState!.nameTextEditingController.value.text;
      }

      if (!formKey!.currentState!.validate()) {
        _formProcessing = false;
        return;
      }

      if (walletRestoreViewModel.nameExists(name)) {
        showNameExistsAlert(formContext!);
        _formProcessing = false;
        return;
      }

      walletRestoreViewModel.state = IsExecutingState();

      DerivationInfo? dInfo;

      // get info about the different derivations:
      List<DerivationInfo> derivations =
          await walletRestoreViewModel.getDerivationInfo(_credentials());

      int derivationsWithHistory = 0;
      int derivationWithHistoryIndex = 0;
      for (int i = 0; i < derivations.length; i++) {
        if (derivations[i].transactionsCount > 0) {
          derivationsWithHistory++;
          derivationWithHistoryIndex = i;
        }
      }

      if (derivationsWithHistory > 1) {
        dInfo = await Navigator.of(context).pushNamed(
          Routes.restoreWalletChooseDerivation,
          arguments: derivations,
        ) as DerivationInfo?;
      } else if (derivationsWithHistory == 1) {
        dInfo = derivations[derivationWithHistoryIndex];
      }

      // get the default derivation for this wallet type:
      if (dInfo == null) {
        // we only return 1 derivation if we're pretty sure we know which one to use:
        if (derivations.length == 1) {
          dInfo = derivations.first;
        } else {
          // if we have multiple possible derivations, and none have histories
          // we just default to the most common one:
          dInfo = walletRestoreViewModel.getCommonRestoreDerivation();
        }
      }

      this.derivationInfo = dInfo;
      if (this.derivationInfo == null) {
        this.derivationInfo = walletRestoreViewModel.getDefaultDerivation();
      }

      await walletRestoreViewModel.create(options: _credentials());
    } catch (e) {
      _formProcessing = false;
      rethrow;
    }
    _formProcessing = false;
  }

  Future<void> showNameExistsAlert(BuildContext context) {
    return showPopUp<void>(
        context: context,
        builder: (_) {
          return AlertWithOneAction(
              alertTitle: '',
              alertContent: S.of(context).wallet_name_exists,
              buttonText: S.of(context).ok,
              buttonAction: () => Navigator.of(context).pop());
        });
  }
}
