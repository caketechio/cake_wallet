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
import 'package:cake_wallet/view_model/seed_settings_view_model.dart';
import 'package:cake_wallet/view_model/wallet_restore_view_model.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:mobx/mobx.dart';

class WalletRestorePage extends BasePage {
  WalletRestorePage(this.walletRestoreViewModel, this.seedSettingsViewModel)
      : walletRestoreFromSeedFormKey = GlobalKey<WalletRestoreFromSeedFormState>(),
        walletRestoreFromKeysFormKey = GlobalKey<WalletRestoreFromKeysFromState>(),
        _blockHeightFocusNode = FocusNode();

  final WalletRestoreViewModel walletRestoreViewModel;
  final SeedSettingsViewModel seedSettingsViewModel;
  final GlobalKey<WalletRestoreFromSeedFormState> walletRestoreFromSeedFormKey;
  final GlobalKey<WalletRestoreFromKeysFromState> walletRestoreFromKeysFormKey;
  final FocusNode _blockHeightFocusNode;

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
              children: [
                Expanded(
                  child: _WalletRestorePageBody(
                    walletRestoreViewModel: walletRestoreViewModel,
                    seedSettingsViewModel: seedSettingsViewModel,
                    walletRestoreFromSeedFormKey: walletRestoreFromSeedFormKey,
                    walletRestoreFromKeysFormKey: walletRestoreFromKeysFormKey,
                    blockHeightFocusNode: _blockHeightFocusNode,
                    derivationInfo: derivationInfo,
                    onDerivationInfoChanged: (info) => derivationInfo = info,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 24, left: 24, right: 24),
                  child: Column(
                    children: [
                      Observer(
                        builder: (context) {
                          return LoadingPrimaryButton(
                            key: ValueKey('wallet_restore_seed_or_key_restore_button_key'),
                            onPressed: () async => await _confirmForm(context),
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
                        key: ValueKey('wallet_restore_advanced_settings_button_key'),
                        onTap: () {
                          Navigator.of(context)
                              .pushNamed(Routes.advancedPrivacySettings, arguments: {
                            'isFromRestore': true,
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

      credentials['passphrase'] = seedSettingsViewModel.passphrase;

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
      } else if (derivations.length == 1) {
        // we only return 1 derivation if we're pretty sure we know which one to use:
        dInfo = derivations.first;
      } else {
        // if we have multiple possible derivations, and none (or multiple) have histories
        // we just default to the most common one:
        dInfo = walletRestoreViewModel.getCommonRestoreDerivation();
      }

      this.derivationInfo = dInfo;

      await walletRestoreViewModel.create(options: _credentials());
      seedSettingsViewModel.setPassphrase(null);
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

class _WalletRestorePageBody extends StatefulWidget {
  const _WalletRestorePageBody({
    Key? key,
    required this.walletRestoreViewModel,
    required this.seedSettingsViewModel,
    required this.walletRestoreFromSeedFormKey,
    required this.walletRestoreFromKeysFormKey,
    required this.blockHeightFocusNode,
    required this.derivationInfo,
    required this.onDerivationInfoChanged,
  }) : super(key: key);

  final WalletRestoreViewModel walletRestoreViewModel;
  final SeedSettingsViewModel seedSettingsViewModel;
  final GlobalKey<WalletRestoreFromSeedFormState> walletRestoreFromSeedFormKey;
  final GlobalKey<WalletRestoreFromKeysFromState> walletRestoreFromKeysFormKey;
  final FocusNode blockHeightFocusNode;
  final DerivationInfo? derivationInfo;
  final void Function(DerivationInfo?) onDerivationInfoChanged;

  @override
  State<_WalletRestorePageBody> createState() => _WalletRestorePageBodyState(
      walletRestoreViewModel: walletRestoreViewModel,
      seedSettingsViewModel: seedSettingsViewModel,
      walletRestoreFromSeedFormKey: walletRestoreFromSeedFormKey,
      walletRestoreFromKeysFormKey: walletRestoreFromKeysFormKey,
      blockHeightFocusNode: blockHeightFocusNode,
      derivationInfo: derivationInfo);
}

class _WalletRestorePageBodyState extends State<_WalletRestorePageBody>
    with SingleTickerProviderStateMixin {
  _WalletRestorePageBodyState(
      {required this.walletRestoreViewModel,
      required this.seedSettingsViewModel,
      required this.walletRestoreFromSeedFormKey,
      required this.walletRestoreFromKeysFormKey,
      required this.blockHeightFocusNode,
      required this.derivationInfo});

  final WalletRestoreViewModel walletRestoreViewModel;
  final SeedSettingsViewModel seedSettingsViewModel;
  final GlobalKey<WalletRestoreFromSeedFormState> walletRestoreFromSeedFormKey;
  final GlobalKey<WalletRestoreFromKeysFromState> walletRestoreFromKeysFormKey;
  final FocusNode blockHeightFocusNode;
  DerivationInfo? derivationInfo;

  late TabController _tabController;

  late bool _hasKeysTab;

  @override
  void initState() {
    super.initState();

    _hasKeysTab = widget.walletRestoreViewModel.availableModes.contains(WalletRestoreMode.keys);
    final tabCount = _hasKeysTab ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.walletRestoreViewModel.mode =
            _tabController.index == 0 ? WalletRestoreMode.seed : WalletRestoreMode.keys;
      }
    });

    reaction<WalletRestoreMode>(
      (_) => widget.walletRestoreViewModel.mode,
      (mode) {
        final index = mode == WalletRestoreMode.seed ? 0 : 1;
        if (_tabController.index != index) {
          _tabController.animateTo(index);
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: TabBar(
              controller: _tabController,
              splashFactory: NoSplash.splashFactory,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              labelStyle: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appBarTheme.titleTextStyle!.color),
              unselectedLabelStyle: TextStyle(
                  fontSize: 18,
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appBarTheme.titleTextStyle!.color?.withOpacity(0.5)),
              labelColor: Theme.of(context).appBarTheme.titleTextStyle!.color,
              indicatorColor: Theme.of(context).appBarTheme.titleTextStyle!.color,
              indicatorPadding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(right: 24),
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              padding: EdgeInsets.zero,
              tabs: [
                Tab(text: S.of(context).widgets_seed),
                if (_hasKeysTab)  Tab(text: S.of(context).keys),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildWalletRestoreFromSeedTab(),
                ),
                if (_hasKeysTab)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _buildWalletRestoreFromKeysTab(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  WalletRestoreFromKeysFrom _buildWalletRestoreFromKeysTab() {
    return WalletRestoreFromKeysFrom(
      key: widget.walletRestoreFromKeysFormKey,
      walletRestoreViewModel: widget.walletRestoreViewModel,
      displayPrivateKeyField: widget.walletRestoreViewModel.hasRestoreFromPrivateKey,
      displayWalletPassword: widget.walletRestoreViewModel.hasWalletPassword,
      onPrivateKeyChange: (String seed) {
        // For nano/banano, set button state if valid seed key
        if (widget.walletRestoreViewModel.type == WalletType.nano ||
            widget.walletRestoreViewModel.type == WalletType.banano) {
          widget.walletRestoreViewModel.isButtonEnabled = _isValidSeedKey();
        }
      },
      onPasswordChange: (String password) =>
          widget.walletRestoreViewModel.walletPassword = password,
      onRepeatedPasswordChange: (String repeatedPassword) =>
          widget.walletRestoreViewModel.repeatedWalletPassword = repeatedPassword,
      onHeightOrDateEntered: (value) => widget.walletRestoreViewModel.isButtonEnabled = value,
    );
  }

  WalletRestoreFromSeedForm _buildWalletRestoreFromSeedTab() {
    return WalletRestoreFromSeedForm(
      key: widget.walletRestoreFromSeedFormKey,
      seedSettingsViewModel: widget.seedSettingsViewModel,
      displayBlockHeightSelector: widget.walletRestoreViewModel.hasBlockchainHeightLanguageSelector,
      displayLanguageSelector: widget.walletRestoreViewModel.hasSeedLanguageSelector,
      type: widget.walletRestoreViewModel.type,
      blockHeightFocusNode: widget.blockHeightFocusNode,
      onHeightOrDateEntered: (value) {
        // set button state
        if (_isValidSeed()) {
          widget.walletRestoreViewModel.isButtonEnabled = value;
        }
      },
      onSeedChange: (String seed) {
        final isPolyseed = widget.walletRestoreViewModel.isPolyseed(seed);
        _validateOnChange(isPolyseed: isPolyseed);
      },
      onLanguageChange: (String language) {
        final isPolyseed = language.startsWith("POLYSEED_");
        _validateOnChange(isPolyseed: isPolyseed);
      },
      displayWalletPassword: widget.walletRestoreViewModel.hasWalletPassword,
      onPasswordChange: (String password) =>
          widget.walletRestoreViewModel.walletPassword = password,
      onRepeatedPasswordChange: (String repeatedPassword) =>
          widget.walletRestoreViewModel.repeatedWalletPassword = repeatedPassword,
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
    if (seedWords.length == 26 && walletRestoreViewModel.type == WalletType.zano) return true;

    if ((walletRestoreViewModel.type == WalletType.monero ||
            walletRestoreViewModel.type == WalletType.wownero ||
            walletRestoreViewModel.type == WalletType.haven) &&
        seedWords.length != WalletRestoreViewModelBase.moneroSeedMnemonicLength) {
      return false;
    }

    // bip39:
    final validBip39SeedLengths = [12, 18, 24];
    final nonBip39WalletTypes = [WalletType.monero, WalletType.wownero, WalletType.haven];
    // if it's a bip39 wallet and the length is not valid return false
    if (!nonBip39WalletTypes.contains(walletRestoreViewModel.type) &&
        !(validBip39SeedLengths.contains(seedWords.length))) {
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
}
