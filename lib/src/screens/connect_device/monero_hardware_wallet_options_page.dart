import 'package:cake_wallet/core/wallet_name_validator.dart';
import 'package:cake_wallet/entities/generate_name.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/blockchain_height_widget.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/new_wallet_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/wallet_hardware_restore_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';

class MoneroHardwareWalletOptionsPage extends BasePage {
  MoneroHardwareWalletOptionsPage(this._walletHardwareRestoreVM);

  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;

  @override
  String get title => S.current.restore_title_from_hardware_wallet;

  @override
  Widget body(BuildContext context) =>
      _MoneroHardwareWalletOptionsForm(_walletHardwareRestoreVM);
}

class _MoneroHardwareWalletOptionsForm extends StatefulWidget {
  const _MoneroHardwareWalletOptionsForm(this._walletHardwareRestoreVM);

  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;

  @override
  _MoneroHardwareWalletOptionsFormState createState() =>
      _MoneroHardwareWalletOptionsFormState(_walletHardwareRestoreVM);
}

class _MoneroHardwareWalletOptionsFormState
    extends State<_MoneroHardwareWalletOptionsForm> {
  _MoneroHardwareWalletOptionsFormState(this._walletHardwareRestoreVM)
      : _formKey = GlobalKey<FormState>(),
        _blockchainHeightKey = GlobalKey<BlockchainHeightState>(),
        _blockHeightFocusNode = FocusNode(),
        _controller = TextEditingController();

  final GlobalKey<FormState> _formKey;
  final GlobalKey<BlockchainHeightState> _blockchainHeightKey;
  final FocusNode _blockHeightFocusNode;
  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;
  final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _setEffects(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 24),
      child: ScrollableWithBottomSection(
        contentPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
        content: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: ResponsiveLayoutUtilBase.kDesktopMaxWidthConstraint),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 0),
                  child: Form(
                    key: _formKey,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextFormField(
                          onChanged: (value) =>
                              _walletHardwareRestoreVM.name = value,
                          controller: _controller,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .extension<CakeTextTheme>()!
                                .titleColor,
                          ),
                          decoration: InputDecoration(
                            hintStyle: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .extension<NewWalletTheme>()!
                                  .hintTextColor,
                            ),
                            hintText: S.of(context).wallet_name,
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
                            suffixIcon: Semantics(
                              label: S.of(context).generate_name,
                              child: IconButton(
                                onPressed: _onGenerateName,
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
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: BlockchainHeightWidget(
                    focusNode: _blockHeightFocusNode,
                    key: _blockchainHeightKey,
                    hasDatePicker: true,
                    walletType: WalletType.monero,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomSectionPadding: EdgeInsets.all(24),
        bottomSection: Observer(
          builder: (context) => LoadingPrimaryButton(
            onPressed: _confirmForm,
            text: S.of(context).seed_language_next,
            color: Colors.green,
            textColor: Colors.white,
            isDisabled: _walletHardwareRestoreVM.name.isEmpty,
          ),
        ),
      ),
    );
  }

  Future<void> _onGenerateName() async {
    final rName = await generateName();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _controller.text = rName;
      _walletHardwareRestoreVM.name = rName;
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length));
    });
  }

  Future<void> _confirmForm() async {
    showPopUp<void>(
      context: context,
      builder: (BuildContext context) => AlertWithOneAction(
        alertTitle: S.of(context).proceed_on_device,
        alertContent: S.of(context).proceed_on_device_description,
        buttonText: S.of(context).cancel,
        alertBarrierDismissible: false,
        buttonAction: () => Navigator.of(context).pop(),
      ),
    );

    final options = {'height': _blockchainHeightKey.currentState?.height ?? -1};
    await _walletHardwareRestoreVM.create(options: options);
  }

  bool _effectsInstalled = false;

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) return;

    reaction((_) => _walletHardwareRestoreVM.error, (String? error) {
      if (error != null) {
        if (error == S.current.ledger_connection_error)
          Navigator.of(context).pop();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showPopUp<void>(
            context: context,
            builder: (BuildContext context) => AlertWithOneAction(
              alertTitle: S.of(context).error,
              alertContent: error,
              buttonText: S.of(context).ok,
              buttonAction: () {
                _walletHardwareRestoreVM.error = null;
                Navigator.of(context).pop();
              },
            ),
          );
        });
      }
    });

    _effectsInstalled = true;
  }
}
