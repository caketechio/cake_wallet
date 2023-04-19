import 'package:cake_wallet/entities/generate_name.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/view_model/wallet_restore_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/src/screens/seed_language/widgets/seed_language_picker.dart';
import 'package:cake_wallet/src/widgets/seed_widget.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/blockchain_height_widget.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/core/wallet_name_validator.dart';

class WalletRestoreFromSeedForm extends StatefulWidget {
  WalletRestoreFromSeedForm(
      {Key? key,
      required this.displayLanguageSelector,
      required this.displayBlockHeightSelector,
      required this.type,
      required this.displayWalletPassword,
      this.blockHeightFocusNode,
      this.onHeightOrDateEntered,
      this.onSeedChange,
      this.onLanguageChange,
      this.onPasswordChange,
      this.onRepeatedPasswordChange})
      : super(key: key);

  final WalletType type;
  final bool displayLanguageSelector;
  final bool displayBlockHeightSelector;
  final bool displayWalletPassword;
  final FocusNode? blockHeightFocusNode;
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
        repeatedPasswordTextEditingController = displayWalletPassword ? TextEditingController() : null;

  final GlobalKey<SeedWidgetState> seedWidgetStateKey;
  final GlobalKey<BlockchainHeightState> blockchainHeightKey;
  final TextEditingController languageController;
  final TextEditingController nameTextEditingController;
  final TextEditingController? passwordTextEditingController;
  final TextEditingController? repeatedPasswordTextEditingController;
  final GlobalKey<FormState> formKey;
  String language;
  void Function()? passwordListener;
  void Function()? repeatedPasswordListener;

  @override
  void initState() {
    _setLanguageLabel(language);
    if (passwordTextEditingController != null) {
      passwordListener = () => widget.onPasswordChange?.call(passwordTextEditingController!.text);
      passwordTextEditingController?.addListener(passwordListener!);
    }

    if (repeatedPasswordTextEditingController != null) {
      repeatedPasswordListener = () => widget.onRepeatedPasswordChange?.call(repeatedPasswordTextEditingController!.text);
      repeatedPasswordTextEditingController?.addListener(repeatedPasswordListener!);
    }
    super.initState();
  }

  @override
  void dispose() {
    if (passwordListener != null) {
      passwordTextEditingController?.removeListener(passwordListener!);
    }

    if (repeatedPasswordListener != null) {
      repeatedPasswordTextEditingController?.removeListener(repeatedPasswordListener!);
    }
    super.dispose();
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
                controller: nameTextEditingController,
                hintText: S.of(context).wallet_name,
                suffixIcon: IconButton(
                  onPressed: () async {
                    final rName = await generateName();
                    FocusManager.instance.primaryFocus?.unfocus();

                    setState(() {
                      nameTextEditingController.text = rName;
                      nameTextEditingController.selection =
                          TextSelection.fromPosition(TextPosition(
                              offset: nameTextEditingController.text.length));
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
                          .primaryTextTheme!
                          .headline4!
                          .decorationColor!,
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
              language: language,
              type: widget.type,
              onSeedChange: widget.onSeedChange),
          if (widget.displayWalletPassword)
            ...[BaseTextFormField(
              controller: passwordTextEditingController,
              hintText: S.of(context).password,
              obscureText: true),
            BaseTextFormField(
              controller: repeatedPasswordTextEditingController,
              hintText: S.of(context).repeate_wallet_password,
              obscureText: true)],
          if (widget.displayLanguageSelector)
            GestureDetector(
                onTap: () async {
                  await showPopUp<void>(
                      context: context,
                      builder: (_) => SeedLanguagePicker(
                          selected: language, onItemSelected: _changeLanguage));
                },
                child: Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.only(top: 20.0),
                    child: IgnorePointer(
                        child: BaseTextFormField(
                            controller: languageController,
                            enableInteractiveSelection: false,
                            readOnly: true)))),
          if (widget.displayBlockHeightSelector)
            BlockchainHeightWidget(
                focusNode: widget.blockHeightFocusNode,
                key: blockchainHeightKey,
                onHeightOrDateEntered: widget.onHeightOrDateEntered,
                hasDatePicker: widget.type == WalletType.monero),
        ]));
  }

  void _changeLanguage(String language) {
    setState(() {
      this.language = language;
      seedWidgetStateKey.currentState!.changeSeedLanguage(language);
      _setLanguageLabel(language);
      widget.onLanguageChange?.call(language);
    });
  }

  void _setLanguageLabel(String language) =>
      languageController.text = '$language (Seed language)';
}
