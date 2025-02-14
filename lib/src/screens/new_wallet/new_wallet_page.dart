import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/core/wallet_name_validator.dart';
import 'package:cake_wallet/entities/generate_name.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/new_wallet/widgets/select_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/seed_language_picker.dart';
import 'package:cake_wallet/src/widgets/seed_language_selector.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/seed_settings_view_model.dart';
import 'package:cake_wallet/view_model/wallet_new_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

class NewWalletPage extends BasePage {
  NewWalletPage(
    this._walletNewVM,
    this._seedSettingsViewModel, {
    this.isChildWallet = false,
  });

  final WalletNewVM _walletNewVM;
  final SeedSettingsViewModel _seedSettingsViewModel;
  final bool isChildWallet;

  final walletNameImage = Image.asset('assets/images/wallet_name.png');

  final walletNameLightImage = Image.asset('assets/images/wallet_name_light.png');

  @override
  String get title => S.current.new_wallet;

  @override
  Function(BuildContext)? get pushToNextWidget => (context) {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.focusedChild?.unfocus();
        }
      };

  @override
  Widget body(BuildContext context) => WalletNameForm(
        _walletNewVM,
        currentTheme.type == ThemeType.dark ? walletNameImage : walletNameLightImage,
        _seedSettingsViewModel,
        isChildWallet,
      );
}

class WalletNameForm extends StatefulWidget {
  WalletNameForm(
    this._walletNewVM,
    this.walletImage,
    this._seedSettingsViewModel,
    this.isChildWallet,
  );

  final WalletNewVM _walletNewVM;
  final bool isChildWallet;
  final Image walletImage;
  final SeedSettingsViewModel _seedSettingsViewModel;

  @override
  _WalletNameFormState createState() => _WalletNameFormState(_walletNewVM);
}

class _WalletNameFormState extends State<WalletNameForm> {
  _WalletNameFormState(this._walletNewVM)
      : _formKey = GlobalKey<FormState>(),
        _languageSelectorKey = GlobalKey<SeedLanguageSelectorState>(),
        _nameController = TextEditingController(),
        _passwordController = _walletNewVM.hasWalletPassword ? TextEditingController() : null,
        _repeatedPasswordController =
            _walletNewVM.hasWalletPassword ? TextEditingController() : null;

  static const aspectRatioImage = 1.22;
  bool _formProcessing = false;

  final GlobalKey<FormState> _formKey;
  final GlobalKey<SeedLanguageSelectorState> _languageSelectorKey;
  final WalletNewVM _walletNewVM;
  final TextEditingController _nameController;
  final TextEditingController? _passwordController;
  final TextEditingController? _repeatedPasswordController;
  ReactionDisposer? _stateReaction;

  @override
  void initState() {
    _stateReaction ??= reaction((_) => _walletNewVM.state, (ExecutionState state) async {
      if (state is ExecutedSuccessfullyState) {
        if (widget.isChildWallet) {
          Navigator.of(navigatorKey.currentContext ?? context)
              .pushNamed(Routes.walletGroupExistingSeedDescriptionPage,
              arguments: _walletNewVM.seedPhraseWordsLength);
        } else {
          Navigator.of(navigatorKey.currentContext ?? context)
              .pushNamed(Routes.preSeedPage, arguments: _walletNewVM.seedPhraseWordsLength);
        }
      }

      if (state is FailureState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showPopUp<void>(
                context: context,
                builder: (_) {
                  return AlertWithOneAction(
                    key: ValueKey('new_wallet_page_failure_dialog_key'),
                    buttonKey: ValueKey('new_wallet_page_failure_dialog_button_key'),
                    alertTitle: S.current.new_wallet,
                    alertContent: state.error,
                    buttonText: S.of(context).ok,
                    buttonAction: () => Navigator.of(context).pop(),
                  );
                });
          }
        });
      }
    });

    _setSeedType(MoneroSeedType.defaultSeedType);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 24),
      child: ScrollableWithBottomSection(
          contentPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
          content: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 12, right: 12),
                    child: AspectRatio(
                        aspectRatio: aspectRatioImage,
                        child: FittedBox(child: widget.walletImage, fit: BoxFit.fill)),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            key: ValueKey('new_wallet_page_wallet_name_textformfield_key'),
                            onChanged: (value) => _walletNewVM.name = value,
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).extension<CakeTextTheme>()!.titleColor),
                            decoration: InputDecoration(
                              hintStyle: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).extension<NewWalletTheme>()!.hintTextColor),
                              hintText: S.of(context).wallet_name,
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .extension<NewWalletTheme>()!
                                          .underlineColor,
                                      width: 1.0)),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .extension<NewWalletTheme>()!
                                        .underlineColor,
                                    width: 1.0),
                              ),
                              suffixIcon: Semantics(
                                label: S.of(context).generate_name,
                                child: IconButton(
                                  key: ValueKey(
                                      'new_wallet_page_wallet_name_textformfield_generate_name_button_key'),
                                  onPressed: () async {
                                    final rName = await generateName();
                                    FocusManager.instance.primaryFocus?.unfocus();

                                    setState(() {
                                      _nameController.text = rName;
                                      _walletNewVM.name = rName;
                                      _nameController.selection = TextSelection.fromPosition(
                                          TextPosition(offset: _nameController.text.length));
                                    });
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6.0),
                                      color: Theme.of(context).hintColor,
                                    ),
                                    width: 34,
                                    height: 34,
                                    child: Image.asset(
                                      'assets/images/refresh_icon.png',
                                      color: Theme.of(context)
                                          .extension<SendPageTheme>()!
                                          .textFieldButtonIconColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            validator: WalletNameValidator(),
                          ),
                          if (_walletNewVM.hasWalletPassword) ...[
                            TextFormField(
                              key: ValueKey('password'),
                              onChanged: (value) => _walletNewVM.walletPassword = value,
                              controller: _passwordController,
                              textAlign: TextAlign.center,
                              obscureText: true,
                              style: TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                              ),
                              decoration: InputDecoration(
                                hintStyle: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                                ),
                                hintText: S.of(context).password,
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .extension<NewWalletTheme>()!
                                        .underlineColor,
                                    width: 1.0,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .extension<NewWalletTheme>()!
                                        .underlineColor,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            TextFormField(
                              key: ValueKey('repeat_wallet_password'),
                              onChanged: (value) => _walletNewVM.repeatedWalletPassword = value,
                              controller: _repeatedPasswordController,
                              textAlign: TextAlign.center,
                              obscureText: true,
                              style: TextStyle(
                                fontSize: 20.0,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                              ),
                              decoration: InputDecoration(
                                hintStyle: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                                ),
                                hintText: S.of(context).repeat_wallet_password,
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .extension<NewWalletTheme>()!
                                        .underlineColor,
                                    width: 1.0,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .extension<NewWalletTheme>()!
                                        .underlineColor,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_walletNewVM.hasLanguageSelector) ...[
                    if (_walletNewVM.hasSeedType) ...[
                      Observer(
                        builder: (BuildContext build) => Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: SelectButton(
                            key: ValueKey('new_wallet_page_monero_seed_type_button_key'),
                            text: widget._seedSettingsViewModel.moneroSeedType.title,
                            onTap: () async {
                              await showPopUp<void>(
                                context: context,
                                builder: (_) => Picker(
                                  items: MoneroSeedType.all,
                                  selectedAtIndex: isPolyseed ? 1 : 0,
                                  onItemSelected: _setSeedType,
                                  isSeparated: false,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    Observer(
                      builder: (BuildContext build) => Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: SeedLanguageSelector(
                          key: _languageSelectorKey,
                          buttonKey: ValueKey('new_wallet_page_seed_language_selector_button_key'),
                          initialSelected: defaultSeedLanguage,
                          seedType: _walletNewVM.hasSeedType
                              ? widget._seedSettingsViewModel.moneroSeedType
                              : MoneroSeedType.legacy,
                        ),
                      ),
                    )
                  ],
                ],
              ),
            ),
          ),
          bottomSectionPadding: EdgeInsets.all(24),
          bottomSection:
          SafeArea (
          child: Column(
            children: [
              Observer(
                builder: (context) {
                  return LoadingPrimaryButton(
                    key: ValueKey('new_wallet_page_confirm_button_key'),
                    onPressed: _confirmForm,
                    text: S.of(context).seed_language_next,
                    color: Theme.of(context).primaryColor,
                    textColor: Colors.white,
                    isLoading: _walletNewVM.state is IsExecutingState,
                    isDisabled: _walletNewVM.name.isEmpty,
                  );
                },
              ),
              const SizedBox(height: 25),
              GestureDetector(
                key: ValueKey('new_wallet_page_advanced_settings_button_key'),
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.advancedPrivacySettings, arguments: {
                    "type": _walletNewVM.type,
                    "useTestnet": _walletNewVM.useTestnet,
                    "toggleTestnet": _walletNewVM.toggleUseTestnet,
                    "isChildWallet": widget.isChildWallet,
                  });
                },
                child: Text(S.of(context).advanced_settings),
              ),
            ],
          )),
      )
    );
  }

  void _confirmForm() async {
    if (_formProcessing) return;
    _formProcessing = true;
    try {
      if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
        _formProcessing = false;
        return;
      }
      if (_walletNewVM.nameExists(_walletNewVM.name)) {
        await showPopUp<void>(
            context: context,
            builder: (_) {
              return AlertWithOneAction(
                  alertTitle: '',
                  alertContent: S.of(context).wallet_name_exists,
                  buttonText: S.of(context).ok,
                  buttonAction: () => Navigator.of(context).pop());
            });
      } else {
        await _walletNewVM.create(
            options: _walletNewVM.hasLanguageSelector
                ? [_languageSelectorKey.currentState!.selected, isPolyseed]
                : null);
      }
    } catch (e) {
      _formProcessing = false;
      rethrow;
    }
    _formProcessing = false;
  }

  bool get isPolyseed => widget._seedSettingsViewModel.moneroSeedType == MoneroSeedType.polyseed;

  void _setSeedType(MoneroSeedType item) {
    widget._seedSettingsViewModel.setMoneroSeedType(item);
    _languageSelectorKey.currentState?.selected = defaultSeedLanguage; // Reset Seed language
  }
}
