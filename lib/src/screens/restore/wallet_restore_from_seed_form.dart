import 'package:cake_wallet/core/wallet_name_validator.dart';
import 'package:cake_wallet/entities/generate_name.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/blockchain_height_widget.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/src/widgets/seed_language_picker.dart';
import 'package:cake_wallet/src/widgets/seed_widget.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/restore/restore_wallet.dart';
import 'package:cake_wallet/view_model/seed_settings_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:polyseed/polyseed.dart';

class WalletRestoreFromSeedForm extends StatefulWidget {
  WalletRestoreFromSeedForm({Key? key,
    required this.displayLanguageSelector,
    required this.displayBlockHeightSelector,
    required this.type,
    required this.displayWalletPassword,
    required this.seedSettingsViewModel,
    this.blockHeightFocusNode,
    this.restoredWallet,
    this.onHeightOrDateEntered,
    this.onSeedChange,
    this.onLanguageChange,
    this.onPasswordChange,
    this.onRepeatedPasswordChange,
  }) : super(key: key);

  final WalletType type;
  final bool displayLanguageSelector;
  final bool displayBlockHeightSelector;
  final bool displayWalletPassword;
  final SeedSettingsViewModel seedSettingsViewModel;
  final FocusNode? blockHeightFocusNode;
  final RestoredWallet? restoredWallet;
  final Function(bool)? onHeightOrDateEntered;
  final void Function(String)? onSeedChange;
  final void Function(String)? onLanguageChange;
  final void Function(String)? onPasswordChange;
  final void Function(String)? onRepeatedPasswordChange;

  @override
  WalletRestoreFromSeedFormState createState() =>
      WalletRestoreFromSeedFormState('English', displayWalletPassword: displayWalletPassword);
}

class WalletRestoreFromSeedFormState extends State<WalletRestoreFromSeedForm> {
  WalletRestoreFromSeedFormState(this.language, {required bool displayWalletPassword})
      : seedWidgetStateKey = GlobalKey<SeedWidgetState>(),
        blockchainHeightKey = GlobalKey<BlockchainHeightState>(),
        formKey = GlobalKey<FormState>(),
        languageController = TextEditingController(),
        nameTextEditingController = TextEditingController(),
        passwordTextEditingController = displayWalletPassword ? TextEditingController() : null,
        repeatedPasswordTextEditingController = displayWalletPassword
            ? TextEditingController()
            : null,
      seedTypeController = TextEditingController();

  final GlobalKey<SeedWidgetState> seedWidgetStateKey;
  final GlobalKey<BlockchainHeightState> blockchainHeightKey;
  final TextEditingController languageController;
  final TextEditingController nameTextEditingController;
  final TextEditingController? passwordTextEditingController;
  final TextEditingController? repeatedPasswordTextEditingController;
  final TextEditingController seedTypeController;
  final GlobalKey<FormState> formKey;
  late ReactionDisposer moneroSeedTypeReaction;
  String language;
  void Function()? passwordListener;
  void Function()? repeatedPasswordListener;

  @override
  void initState() {
    // _setSeedType(widget.seedTypeViewModel.moneroSeedType);
    _setSeedType(MoneroSeedType.defaultSeedType);
    _setLanguageLabel(language);

    if (passwordTextEditingController != null) {
      passwordListener = () => widget.onPasswordChange?.call(passwordTextEditingController!.text);
      passwordTextEditingController?.addListener(passwordListener!);
    }

    if (repeatedPasswordTextEditingController != null) {
      repeatedPasswordListener =
          () => widget.onRepeatedPasswordChange?.call(repeatedPasswordTextEditingController!.text);
      repeatedPasswordTextEditingController?.addListener(repeatedPasswordListener!);
    }

    moneroSeedTypeReaction =
        reaction((_) => widget.seedSettingsViewModel.moneroSeedType, (MoneroSeedType item) {
          _setSeedType(item);
          _changeLanguage('English');
        });

    super.initState();
  }

  @override
  void dispose() {    
    moneroSeedTypeReaction();

    if (passwordListener != null) {
      passwordTextEditingController?.removeListener(passwordListener!);
    }

    if (repeatedPasswordListener != null) {
      repeatedPasswordTextEditingController?.removeListener(repeatedPasswordListener!);
    }

    super.dispose();
  }

  void onSeedChange(String seed) {
    if ((widget.type == WalletType.monero || widget.type == WalletType.wownero) &&
        Polyseed.isValidSeed(seed)) {
      final lang = PolyseedLang.getByPhrase(seed);

      _changeSeedType(MoneroSeedType.polyseed);
      _changeLanguage(lang.nameEnglish);
    }
    if (widget.type == WalletType.wownero && seed
        .split(" ")
        .length == 14) {
      _changeSeedType(MoneroSeedType.wowneroSeed);
      _changeLanguage("English");
    }
    widget.onSeedChange?.call(seed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(left: 24, right: 24),
        child: Column(children: [
          Form(
              key: formKey,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  BaseTextFormField(
                    key: ValueKey('wallet_restore_from_seed_wallet_name_textfield_key'),
                    controller: nameTextEditingController,
                    hintText: S
                        .of(context)
                        .wallet_name,
                    suffixIcon: IconButton(
                      key: ValueKey('wallet_restore_from_seed_wallet_name_refresh_button_key'),
                      onPressed: () async {
                        final rName = await generateName();
                        FocusManager.instance.primaryFocus?.unfocus();

                        setState(() {
                          nameTextEditingController.text = rName;
                          nameTextEditingController.selection = TextSelection.fromPosition(
                              TextPosition(offset: nameTextEditingController.text.length));
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6.0),
                          color: Theme
                              .of(context)
                              .hintColor,
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
                    validator: WalletNameValidator(),
                  ),
                ],
              )),
          Container(height: 20),
          SeedWidget(
            key: seedWidgetStateKey,
            initialSeed: widget.restoredWallet?.mnemonicSeed,
            language: language,
            type: widget.type,
            onSeedChange: onSeedChange,
            seedTextFieldKey: ValueKey('wallet_restore_from_seed_wallet_seeds_textfield_key'),
            pasteButtonKey: ValueKey('wallet_restore_from_seed_wallet_seeds_paste_button_key'),
          ),
          if (widget.type == WalletType.monero || widget.type == WalletType.wownero)
            GestureDetector(
              key: ValueKey('wallet_restore_from_seed_seedtype_picker_button_key'),
              onTap: () async {
                await showPopUp<void>(
                    context: context,
                    builder: (_) =>
                        Picker(
                          items: _getItems(),
                          selectedAtIndex: isPolyseed
                              ? 1
                              : seedTypeController.value.text.contains("14") && widget.type == WalletType.wownero
                                  ? 2
                                  : 0,
                          mainAxisAlignment: MainAxisAlignment.start,
                          onItemSelected: _changeSeedType,
                          isSeparated: false,
                        ));
              },
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.only(top: 20.0),
                child: IgnorePointer(
                  child: BaseTextFormField(
                    controller: seedTypeController,
                    enableInteractiveSelection: false,
                    readOnly: true,
                    suffixIcon: expandIcon,
                  ),
                ),
              ),
            ),
          if (widget.displayWalletPassword)
            ...[BaseTextFormField(
                key: ValueKey('password'),
                controller: passwordTextEditingController,
                hintText: S
                    .of(context)
                    .password,
                obscureText: true),
              BaseTextFormField(
                  key: ValueKey('repeat_wallet_password'),
                  controller: repeatedPasswordTextEditingController,
                  hintText: S
                      .of(context)
                      .repeat_wallet_password,
                  obscureText: true)
            ],
          if (widget.displayLanguageSelector)
            if (!seedTypeController.value.text.contains("14") && widget.displayLanguageSelector)
              GestureDetector(
                onTap: () async {
                  await showPopUp<void>(
                      context: context,
                      builder: (_) =>
                          SeedLanguagePicker(
                            selected: language,
                            onItemSelected: _changeLanguage,
                            seedType: isPolyseed ? MoneroSeedType.polyseed : MoneroSeedType.legacy,
                          ));
                },
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.only(top: 20.0),
                  child: IgnorePointer(
                    child: BaseTextFormField(
                      controller: languageController,
                      enableInteractiveSelection: false,
                      readOnly: true,
                      suffixIcon: expandIcon,
                    ),
                  ),
                ),
              ),
          if ((!isPolyseed) && widget.displayBlockHeightSelector)
            BlockchainHeightWidget(
              focusNode: widget.blockHeightFocusNode,
              key: blockchainHeightKey,
              blockHeightTextFieldKey: ValueKey('wallet_restore_from_seed_blockheight_textfield_key'),
              onHeightOrDateEntered: widget.onHeightOrDateEntered,
              hasDatePicker: widget.type == WalletType.monero || widget.type == WalletType.wownero,
              walletType: widget.type,
            ),
        ]));
  }

  bool get isPolyseed =>
      widget.seedSettingsViewModel.moneroSeedType == MoneroSeedType.polyseed &&
          (widget.type == WalletType.monero || widget.type == WalletType.wownero);

  Widget get expandIcon =>
      Container(
        padding: EdgeInsets.all(18),
        width: 24,
        height: 24,
        child: Image.asset(
          'assets/images/arrow_bottom_purple_icon.png',
          height: 8,
          color: Theme
              .of(context)
              .hintColor,
        ),
      );

  void _changeLanguage(String language) {
    final setLang = isPolyseed
        ? "POLYSEED_$language"
        : seedTypeController.value.text.contains("14")
        ? "WOWSEED_" + language
        : language;
    setState(() {
      this.language = setLang;
      seedWidgetStateKey.currentState!.changeSeedLanguage(setLang);
      _setLanguageLabel(setLang);
      widget.onLanguageChange?.call(setLang);
    });
  }

  void _setLanguageLabel(String language) =>
      languageController.text = '${language.replaceAll("POLYSEED_", "")} (Seed language)';

  void _changeSeedType(MoneroSeedType item) {
    _setSeedType(item);
    _changeLanguage('English');
    widget.seedSettingsViewModel.setMoneroSeedType(item);
  }

  void _setSeedType(MoneroSeedType item) {
    seedTypeController.text = item.toString();
  }

  List<MoneroSeedType> _getItems() {
    switch (widget.type) {
      case WalletType.monero:
        return [MoneroSeedType.legacy, MoneroSeedType.polyseed];
      case WalletType.wownero:
        return [MoneroSeedType.legacy, MoneroSeedType.polyseed, MoneroSeedType.wowneroSeed];
      default:
        return [MoneroSeedType.legacy];
    }
  }
}
