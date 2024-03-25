import 'package:cake_wallet/entities/default_settings_migration.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/seed_phrase_length.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_form.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_choices_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_picker_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_tor_status.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/node_list/node_create_or_edit_view_model.dart';
import 'package:cake_wallet/view_model/advanced_privacy_settings_view_model.dart';
import 'package:cake_wallet/view_model/seed_type_view_model.dart';
import 'package:cake_wallet/view_model/settings/choices_list_item.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';

class AdvancedPrivacySettingsPage extends BasePage {
  AdvancedPrivacySettingsPage(
    this.useTestnet,
    this.toggleUseTestnet,
    this.advancedPrivacySettingsViewModel,
    this.nodeViewModel,
    this.seedTypeViewModel,
    this.torViewModel,
  );

  final AdvancedPrivacySettingsViewModel advancedPrivacySettingsViewModel;
  final NodeCreateOrEditViewModel nodeViewModel;
  final SeedTypeViewModel seedTypeViewModel;
  final TorViewModel torViewModel;

  @override
  String get title => S.current.privacy_settings;

  final bool useTestnet;
  final Function(bool? val) toggleUseTestnet;

  @override
  Widget body(BuildContext context) => AdvancedPrivacySettingsBody(
        useTestnet,
        toggleUseTestnet,
        advancedPrivacySettingsViewModel,
        nodeViewModel,
        seedTypeViewModel,
        torViewModel,
      );
}

class AdvancedPrivacySettingsBody extends StatefulWidget {
  const AdvancedPrivacySettingsBody(this.useTestnet, this.toggleUseTestnet,
      this.privacySettingsViewModel, this.nodeViewModel, this.seedTypeViewModel, this.torViewModel,
      {Key? key})
      : super(key: key);

  final AdvancedPrivacySettingsViewModel privacySettingsViewModel;
  final NodeCreateOrEditViewModel nodeViewModel;
  final SeedTypeViewModel seedTypeViewModel;
  final TorViewModel torViewModel;

  final bool useTestnet;
  final Function(bool? val) toggleUseTestnet;

  @override
  _AdvancedPrivacySettingsBodyState createState() => _AdvancedPrivacySettingsBodyState();
}

class _AdvancedPrivacySettingsBodyState extends State<AdvancedPrivacySettingsBody> {
  _AdvancedPrivacySettingsBodyState();

  final _formKey = GlobalKey<FormState>();
  bool? testnetValue;

  @override
  Widget build(BuildContext context) {
    if (testnetValue == null && widget.useTestnet != null) {
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
            Observer(builder: (_) {
              return Column(
                children: [
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
            if (widget.privacySettingsViewModel.hasSeedPhraseLengthOption)
              Observer(builder: (_) {
                return SettingsPickerCell<SeedPhraseLength>(
                  title: S.current.seed_phrase_length,
                  items: SeedPhraseLength.values,
                  selectedItem: widget.privacySettingsViewModel.seedPhraseLength,
                  onItemSelected: (SeedPhraseLength length) {
                    widget.privacySettingsViewModel.setSeedPhraseLength(length);
                  },
                );
              }),
            if (widget.privacySettingsViewModel.hasSeedTypeOption)
              Observer(builder: (_) {
                return SettingsChoicesCell(
                  ChoicesListItem<SeedType>(
                    title: S.current.seedtype,
                    items: SeedType.all,
                    selectedItem: widget.seedTypeViewModel.moneroSeedType,
                    onItemSelected: widget.seedTypeViewModel.setMoneroSeedType,
                  ),
                );
              }),
            if (widget.privacySettingsViewModel.type == WalletType.bitcoin)
              Builder(builder: (_) {
                final val = testnetValue!;
                return SettingsSwitcherCell(
                    title: S.current.use_testnet,
                    value: val,
                    onValueChange: (_, __) {
                      setState(() {
                        testnetValue = !val;
                      });
                      widget.toggleUseTestnet!.call(testnetValue);
                    });
              }),
            if (FeatureFlag.isInAppTorEnabled && DeviceInfo.instance.isMobile) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(children: [
                  Observer(builder: (context) {
                    return SettingsPickerCell<TorConnectionMode>(
                      title: S.current.tor_connection,
                      items: TorConnectionMode.enabledDisabled,
                      displayItem: (TorConnectionMode mode) => mode.title,
                      selectedItem: widget.torViewModel.torConnectionMode,
                      onItemSelected: (TorConnectionMode mode) async {
                        if (mode == TorConnectionMode.enabled) {
                          await showPopUp<void>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertWithOneAction(
                                alertTitle: S.of(context).warning,
                                alertContent: S.of(context).tor_enabled_warning,
                                buttonText: S.of(context).ok,
                                buttonAction: () => Navigator.of(context).pop(),
                              );
                            },
                          );
                        }
                        widget.torViewModel.setTorConnectionMode(mode);
                      },
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                        color: Theme.of(context)
                            .extension<SyncIndicatorTheme>()!
                            .notSyncedBackgroundColor,
                      ),
                    );
                  }),
                  TorStatus(
                    torViewModel: widget.torViewModel,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
                      color: Theme.of(context)
                          .extension<SyncIndicatorTheme>()!
                          .notSyncedBackgroundColor,
                    ),
                    title: S.current.tor_status,
                    isSelected: false,
                  ),
                ]),
              ),
            ],
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
                } else if (testnetValue == true) {
                  // TODO: add type (mainnet/testnet) to Node class so when switching wallets the node can be switched to a matching type
                  // Currently this is so you can create a working testnet wallet but you need to keep switching back the node if you use multiple wallets at once
                  widget.nodeViewModel.address = publicBitcoinTestnetElectrumAddress;
                  widget.nodeViewModel.port = publicBitcoinTestnetElectrumPort;

                  widget.nodeViewModel.save();
                }

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
}
