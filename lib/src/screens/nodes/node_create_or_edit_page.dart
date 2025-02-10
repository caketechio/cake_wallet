import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_form.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/view_model/node_list/node_create_or_edit_view_model.dart';

class NodeCreateOrEditPage extends BasePage {
  NodeCreateOrEditPage({required this.nodeCreateOrEditViewModel,this.editingNode, this.isSelected, this.type})
      : _formKey = GlobalKey<FormState>(),
        _addressController = TextEditingController(),
        _pathController = TextEditingController(),
        _portController = TextEditingController(),
        _loginController = TextEditingController(),
        _passwordController = TextEditingController() {
    reaction((_) => nodeCreateOrEditViewModel.address, (String address) {
      if (address != _addressController.text) {
        _addressController.text = address;
      }
    });

    reaction((_) => nodeCreateOrEditViewModel.port, (String port) {
      if (port != _portController.text) {
        _portController.text = port;
      }
    });

    if (nodeCreateOrEditViewModel.hasAuthCredentials) {
      reaction((_) => nodeCreateOrEditViewModel.login, (String login) {
        if (login != _loginController.text) {
          _loginController.text = login;
        }
      });

      reaction((_) => nodeCreateOrEditViewModel.password, (String password) {
        if (password != _passwordController.text) {
          _passwordController.text = password;
        }
      });
    }

    _addressController.addListener(
        () => nodeCreateOrEditViewModel.address = _addressController.text);
    _pathController.addListener(
        () => nodeCreateOrEditViewModel.path = _pathController.text);
    _portController.addListener(
        () => nodeCreateOrEditViewModel.port = _portController.text);
    _loginController.addListener(
        () => nodeCreateOrEditViewModel.login = _loginController.text);
    _passwordController.addListener(
        () => nodeCreateOrEditViewModel.password = _passwordController.text);
  }

  final GlobalKey<FormState> _formKey;
  final TextEditingController _addressController;
  final TextEditingController _pathController;
  final TextEditingController _portController;
  final TextEditingController _loginController;
  final TextEditingController _passwordController;

  @override
  String get title => editingNode != null ? S.current.edit_node : S.current.node_new;

  @override
  Widget trailing(BuildContext context) => IconButton(
        onPressed: () async {
          await nodeCreateOrEditViewModel.scanQRCodeForNewNode(context);
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        icon: Image.asset(
          'assets/images/qr_code_icon.png',
        ),
      );

  final NodeCreateOrEditViewModel nodeCreateOrEditViewModel;
  final Node? editingNode;
  final bool? isSelected;
  final WalletType? type;

  @override
  Widget body(BuildContext context) {

    reaction((_) => nodeCreateOrEditViewModel.connectionState,
            (ExecutionState state) {
          if (state is ExecutedSuccessfullyState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showPopUp<void>(
                  context: context,
                  builder: (BuildContext context) =>
                      AlertWithOneAction(
                          alertTitle: S.of(context).new_node_testing,
                          alertContent: state.payload as bool
                              ? S.of(context).node_connection_successful
                              : S.of(context).node_connection_failed,
                          buttonText: S.of(context).ok,
                          buttonAction: () => Navigator.of(context).pop()));
            });
          }

          if (state is FailureState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showPopUp<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertWithOneAction(
                        alertTitle: S.of(context).error,
                        alertContent: state.error,
                        buttonText: S.of(context).ok,
                        buttonAction: () => Navigator.of(context).pop());
                  });
            });
          }
        });

    return Container(
        padding: EdgeInsets.only(left: 24, right: 24),
        child: ScrollableWithBottomSection(
          contentPadding: EdgeInsets.only(bottom: 24.0),
          content: NodeForm(
            formKey: _formKey,
            nodeViewModel: nodeCreateOrEditViewModel,
            editingNode: editingNode,
            type: type,
          ),
          bottomSectionPadding: EdgeInsets.only(bottom: 24),
          bottomSection: Observer(
              builder: (_) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.only(right: 8.0),
                          child: LoadingPrimaryButton(
                            onPressed: () async {
                              final confirmed = await showPopUp<bool>(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertWithTwoActions(
                                            alertTitle: S.of(context).remove_node,
                                            alertContent: S.of(context).remove_node_message,
                                            rightButtonText: S.of(context).remove,
                                            leftButtonText: S.of(context).cancel,
                                            actionRightButton: () => Navigator.pop(context, true),
                                            actionLeftButton: () => Navigator.pop(context, false));
                                      }) ??
                                  false;

                              if (confirmed) {
                                await editingNode!.delete();
                                Navigator.of(context).pop();
                              }
                            },
                            text: S.of(context).delete,
                            isDisabled: editingNode == null ||
                                !nodeCreateOrEditViewModel.isReady ||
                                (isSelected ?? false),
                            color: Palette.red,
                            textColor: Colors.white,
                          ),
                        ),
                      ),
                      Flexible(
                          child: Container(
                        padding: EdgeInsets.only(left: 8.0),
                        child: PrimaryButton(
                          onPressed: () async {
                            if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
                              return;
                            }

                            await nodeCreateOrEditViewModel.save(
                                editingNode: editingNode, saveAsCurrent: isSelected ?? false);
                            Navigator.of(context).pop();
                          },
                          text: S.of(context).save,
                          color: Theme.of(context).primaryColor,
                          textColor: Colors.white,
                          isDisabled: (!nodeCreateOrEditViewModel.isReady)||
                              (nodeCreateOrEditViewModel
                              .connectionState is IsExecutingState),
                        ),
                      )),
                    ],
                  )),
        ));
  }
}
