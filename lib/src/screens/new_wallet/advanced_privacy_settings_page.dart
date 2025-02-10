import 'package:cake_wallet/entities/default_settings_migration.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/seed_phrase_length.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_form.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_choices_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/advanced_privacy_settings_view_model.dart';
import 'package:cake_wallet/view_model/node_list/node_create_or_edit_view_model.dart';
import 'package:cake_wallet/view_model/seed_settings_view_model.dart';
import 'package:cake_wallet/view_model/settings/choices_list_item.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class AdvancedPrivacySettingsPage extends BasePage {
  AdvancedPrivacySettingsPage({
    required this.isFromRestore,
    required this.isChildWallet,
    required this.useTestnet,
    required this.toggleUseTestnet,
    required this.advancedPrivacySettingsViewModel,
    required this.nodeViewModel,
    required this.seedSettingsViewModel,
  });

  final AdvancedPrivacySettingsViewModel advancedPrivacySettingsViewModel;
  final NodeCreateOrEditViewModel nodeViewModel;
  final SeedSettingsViewModel seedSettingsViewModel;

  @override
  String get title => S.current.privacy_settings;

  final bool isFromRestore;
  final bool isChildWallet;
  final bool useTestnet;
  final Function(bool? val) toggleUseTestnet;

  @override
  Widget body(BuildContext context) => _AdvancedPrivacySettingsBody(
        isFromRestore,
        isChildWallet,
        useTestnet,
        toggleUseTestnet,
        advancedPrivacySettingsViewModel,
        nodeViewModel,
        seedSettingsViewModel,
      );
}

class _AdvancedPrivacySettingsBody extends StatefulWidget {
  const _AdvancedPrivacySettingsBody(
    this.isFromRestore,
    this.isChildWallet,
    this.useTestnet,
    this.toggleUseTestnet,
    this.privacySettingsViewModel,
    this.nodeViewModel,
    this.seedTypeViewModel, {
    Key? key,
  }) : super(key: key);

  final AdvancedPrivacySettingsViewModel privacySettingsViewModel;
  final NodeCreateOrEditViewModel nodeViewModel;
  final SeedSettingsViewModel seedTypeViewModel;

  final bool isFromRestore;
  final bool isChildWallet;
  final bool useTestnet;
  final Function(bool? val) toggleUseTestnet;

  @override
  _AdvancedPrivacySettingsBodyState createState() => _AdvancedPrivacySettingsBodyState();
}

class _AdvancedPrivacySettingsBodyState extends State<_AdvancedPrivacySettingsBody> {
  final TextEditingController passphraseController = TextEditingController();
  final TextEditingController confirmPassphraseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _passphraseFormKey = GlobalKey<FormState>();
  bool? testnetValue;

  bool obscurePassphrase = true;

  @override
  void initState() {
    passphraseController.text = widget.seedTypeViewModel.passphrase ?? '';
    confirmPassphraseController.text = widget.seedTypeViewModel.passphrase ?? '';

    if (widget.isChildWallet) {
      if (widget.privacySettingsViewModel.type == WalletType.bitcoin) {
        widget.seedTypeViewModel.setBitcoinSeedType(BitcoinSeedType.bip39);
      }

      if (widget.privacySettingsViewModel.type == WalletType.nano) {
        widget.seedTypeViewModel.setNanoSeedType(NanoSeedType.bip39);
      }
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (testnetValue == null && widget.useTestnet) {
      testnetValue = widget.useTestnet;
    }

    return Container(
      padding: EdgeInsets.only(top: 24),
      child: ScrollableWithBottomSection(
        contentPadding: EdgeInsets.only(bottom: 24),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Observer(builder: (_) {
              return SettingsChoicesCell(
                ChoicesListItem<FiatApiMode>(
                  title: S.current.fiat_api,
                  items: FiatApiMode.all,
                  selectedItem: widget.privacySettingsViewModel.fiatApiMode,
                  onItemSelected: (FiatApiMode mode) =>
                      widget.privacySettingsViewModel.setFiatApiMode(mode),
                ),
              );
            }),
            Observer(builder: (_) {
              return SettingsChoicesCell(
                ChoicesListItem<ExchangeApiMode>(
                  title: S.current.exchange,
                  items: ExchangeApiMode.all,
                  selectedItem: widget.privacySettingsViewModel.exchangeStatus,
                  onItemSelected: (ExchangeApiMode mode) =>
                      widget.privacySettingsViewModel.setExchangeApiMode(mode),
                ),
              );
            }),
            if (widget.privacySettingsViewModel.isMoneroSeedTypeOptionsEnabled)
              Observer(builder: (_) {
                return SettingsChoicesCell(
                  ChoicesListItem<MoneroSeedType>(
                    title: S.current.seedtype,
                    items: MoneroSeedType.all,
                    selectedItem: widget.seedTypeViewModel.moneroSeedType,
                    onItemSelected: widget.seedTypeViewModel.setMoneroSeedType,
                  ),
                );
              }),
            if (widget.privacySettingsViewModel.isBitcoinSeedTypeOptionsEnabled)
              Observer(builder: (_) {
                return SettingsChoicesCell(
                  ChoicesListItem<BitcoinSeedType>(
                    title: S.current.seedtype,
                    items: BitcoinSeedType.all,
                    selectedItem: widget.seedTypeViewModel.bitcoinSeedType,
                    onItemSelected: (type) {
                      if (widget.isChildWallet && type != BitcoinSeedType.bip39) {
                        showAlertForSelectingNonBIP39DerivationTypeForChildWallets();
                      } else {
                        widget.seedTypeViewModel.setBitcoinSeedType(type);
                      }
                    },
                  ),
                );
              }),
            if (widget.privacySettingsViewModel.isNanoSeedTypeOptionsEnabled)
              Observer(builder: (_) {
                return SettingsChoicesCell(
                  ChoicesListItem<NanoSeedType>(
                    title: S.current.seedtype,
                    items: NanoSeedType.all,
                    selectedItem: widget.seedTypeViewModel.nanoSeedType,
                    onItemSelected: (type) {
                      if (widget.isChildWallet && type != NanoSeedType.bip39) {
                        showAlertForSelectingNonBIP39DerivationTypeForChildWallets();
                      } else {
                        widget.seedTypeViewModel.setNanoSeedType(type);
                      }
                    },
                  ),
                );
              }),
            if (!widget.isFromRestore)
              Observer(builder: (_) {
                if (widget.privacySettingsViewModel.hasSeedPhraseLengthOption)
                  return SettingsPickerCell<SeedPhraseLength>(
                    title: S.current.seed_phrase_length,
                    items: SeedPhraseLength.values,
                    selectedItem: widget.privacySettingsViewModel.seedPhraseLength,
                    onItemSelected: (SeedPhraseLength length) {
                      widget.privacySettingsViewModel.setSeedPhraseLength(length);
                    },
                  );
                return Container();
              }),
            if (widget.privacySettingsViewModel.hasPassphraseOption(widget.isFromRestore))
              Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _passphraseFormKey,
                  child: Column(
                    children: [
                      BaseTextFormField(
                        hintText: S.of(context).passphrase,
                        controller: passphraseController,
                        obscureText: obscurePassphrase,
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() {
                            obscurePassphrase = !obscurePassphrase;
                          }),
                          child: Icon(
                            Icons.remove_red_eye,
                            // color: obscurePassphrase ? Colors.black54 : Colors.black26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      BaseTextFormField(
                        hintText: S.of(context).confirm_passphrase,
                        controller: confirmPassphraseController,
                        obscureText: obscurePassphrase,
                        validator: (text) {
                          if (text == passphraseController.text) {
                            return null;
                          }

                          return S.of(context).passphrases_doesnt_match;
                        },
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() {
                            obscurePassphrase = !obscurePassphrase;
                          }),
                          child: Icon(
                            Icons.remove_red_eye,
                            // color: obscurePassphrase ? Colors.black54 : Colors.black26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Observer(builder: (_) {
              return Column(
                children: [
                  SettingsSwitcherCell(
                      title: S.current.disable_bulletin,
                      value: widget.privacySettingsViewModel.disableBulletin,
                      onValueChange: (BuildContext _, bool value) {
                        widget.privacySettingsViewModel.setDisableBulletin(value);
                      }),
                  SettingsSwitcherCell(
                    title: S.current.add_custom_node,
                    value: widget.privacySettingsViewModel.addCustomNode,
                    onValueChange: (_, __) => widget.privacySettingsViewModel.toggleAddCustomNode(),
                  ),
                  if (widget.privacySettingsViewModel.addCustomNode)
                    Padding(
                      padding: EdgeInsets.only(left: 24, right: 24, top: 24),
                      child: NodeForm(
                        formKey: _formKey,
                        nodeViewModel: widget.nodeViewModel,
                      ),
                    )
                ],
              );
            }),
            if (widget.privacySettingsViewModel.type == WalletType.bitcoin ||
                widget.privacySettingsViewModel.type == WalletType.decred)
              Builder(builder: (_) {
                final val = testnetValue ?? false;
                return SettingsSwitcherCell(
                    title: S.current.use_testnet,
                    value: val,
                    onValueChange: (_, __) {
                      setState(() {
                        testnetValue = !val;
                      });
                      widget.toggleUseTestnet.call(testnetValue);
                    });
              }),
          ],
        ),
        bottomSectionPadding: EdgeInsets.all(24),
        bottomSection: Column(
          children: [
            LoadingPrimaryButton(
              onPressed: () {
                if (widget.privacySettingsViewModel.addCustomNode) {
                  if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                    return;
                  }

                  widget.nodeViewModel.save();
                }
                if (testnetValue == true &&
                    widget.privacySettingsViewModel.type ==
                        WalletType.bitcoin) {
                  // TODO: add type (mainnet/testnet) to Node class so when switching wallets the node can be switched to a matching type
                  // Currently this is so you can create a working testnet wallet but you need to keep switching back the node if you use multiple wallets at once
                  widget.nodeViewModel.address = publicBitcoinTestnetElectrumAddress;
                  widget.nodeViewModel.port = publicBitcoinTestnetElectrumPort;

                  widget.nodeViewModel.save();
                }
                if (passphraseController.text.isNotEmpty) {
                  if (_passphraseFormKey.currentState != null &&
                      !_passphraseFormKey.currentState!.validate()) {
                    return;
                  }
                }

                widget.seedTypeViewModel.setPassphrase(passphraseController.text);

                Navigator.pop(context);
              },
              text: S.of(context).continue_text,
              color: Theme.of(context).primaryColor,
              textColor: Colors.white,
            ),
            const SizedBox(height: 25),
            LayoutBuilder(
              builder: (_, constraints) => SizedBox(
                width: constraints.maxWidth * 0.8,
                child: Text(
                  S.of(context).settings_can_be_changed_later,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void showAlertForSelectingNonBIP39DerivationTypeForChildWallets() {
    showPopUp<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertWithOneAction(
            alertTitle: S.current.seedtype_alert_title,
            alertContent: S.current.seedtype_alert_content,
            buttonText: S.of(context).ok,
            buttonAction: () => Navigator.of(context).pop(),
          );
        });
  }
}
