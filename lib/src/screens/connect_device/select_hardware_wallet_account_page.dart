import 'package:cake_wallet/core/wallet_name_validator.dart';
import 'package:cake_wallet/entities/generate_name.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/new_wallet/widgets/select_button.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
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

class SelectHardwareWalletAccountPage extends BasePage {
  SelectHardwareWalletAccountPage(this._walletHardwareRestoreVM);

  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;

  @override
  String get title => S.current.restore_title_from_hardware_wallet;

  @override
  Widget body(BuildContext context) => SelectHardwareWalletAccountForm(_walletHardwareRestoreVM);
}

class SelectHardwareWalletAccountForm extends StatefulWidget {
  SelectHardwareWalletAccountForm(this._walletHardwareRestoreVM);

  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;

  @override
  _SelectHardwareWalletAccountFormState createState() =>
      _SelectHardwareWalletAccountFormState(_walletHardwareRestoreVM);
}

class _SelectHardwareWalletAccountFormState extends State<SelectHardwareWalletAccountForm> {
  _SelectHardwareWalletAccountFormState(this._walletHardwareRestoreVM)
      : _formKey = GlobalKey<FormState>(),
        _controller = TextEditingController();

  final GlobalKey<FormState> _formKey;
  final WalletHardwareRestoreViewModel _walletHardwareRestoreVM;
  final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _setEffects(context);
    if (_walletHardwareRestoreVM.availableAccounts.length == 0) _loadMoreAccounts();
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
                  padding: EdgeInsets.only(top: 0),
                  child: Form(
                    key: _formKey,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextFormField(
                          onChanged: (value) => _walletHardwareRestoreVM.name = value,
                          controller: _controller,
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                          ),
                          decoration: InputDecoration(
                            hintStyle: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).extension<NewWalletTheme>()!.hintTextColor,
                            ),
                            hintText: S.of(context).wallet_name,
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    Theme.of(context).extension<NewWalletTheme>()!.underlineColor,
                                width: 1.0,
                              ),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    Theme.of(context).extension<NewWalletTheme>()!.underlineColor,
                                width: 1.0,
                              ),
                            ),
                            suffixIcon: Semantics(
                              label: S.of(context).generate_name,
                              child: IconButton(
                                onPressed: () async {
                                  final rName = await generateName();
                                  FocusManager.instance.primaryFocus?.unfocus();

                                  setState(() {
                                    _controller.text = rName;
                                    _walletHardwareRestoreVM.name = rName;
                                    _controller.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _controller.text.length));
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
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Container(
                    width: double.infinity,
                    child: Text(
                      S.of(context).select_hw_account_below,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                      ),
                    ),
                  ),
                ),
                Observer(
                  builder: (context) => Column(
                    children: _walletHardwareRestoreVM.availableAccounts.map((acc) {

                      final address = acc.address;
                      return Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: SelectButton(
                          image: Image.asset(
                            walletTypeToCryptoCurrency(_walletHardwareRestoreVM.type).iconPath ??
                                '',
                            height: 24,
                            width: 24,
                          ),
                          text:
                          "${acc.accountIndex} - ${address.substring(0, 6)}...${address.substring(address.length - 6)}",
                          showTrailingIcon: false,
                          height: 54,
                          isSelected: _walletHardwareRestoreVM.selectedAccount == acc,
                          onTap: () =>
                              setState(() => _walletHardwareRestoreVM.selectedAccount = acc),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Observer(builder: (context) {
                    return LoadingPrimaryButton(
                      onPressed: _loadMoreAccounts,
                      text: S.of(context).load_more,
                      color: Theme.of(context).primaryColor,
                      textColor: Colors.white,
                      isLoading: _walletHardwareRestoreVM.isLoadingMoreAccounts,
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        bottomSectionPadding: EdgeInsets.all(24),
        bottomSection: Observer(
          builder: (context) {
            return LoadingPrimaryButton(
              onPressed: _confirmForm,
              text: S.of(context).seed_language_next,
              color: Colors.green,
              textColor: Colors.white,
              isDisabled: _walletHardwareRestoreVM.name.isEmpty,
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadMoreAccounts() async {
    _walletHardwareRestoreVM.isLoadingMoreAccounts = true;
    _walletHardwareRestoreVM.getNextAvailableAccounts(5);
  }

  Future<void> _confirmForm() async {
    await _walletHardwareRestoreVM.create();
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
              builder: (BuildContext context) {
                return AlertWithOneAction(
                    alertTitle: S.of(context).error,
                    alertContent: error,
                    buttonText: S.of(context).ok,
                    buttonAction: () {
                      _walletHardwareRestoreVM.error = null;
                      Navigator.of(context).pop();
                    });
              });
        });
      }
    });

    _effectsInstalled = true;
  }
}
