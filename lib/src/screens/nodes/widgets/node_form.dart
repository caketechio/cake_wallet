import 'package:cake_wallet/core/node_address_validator.dart';
import 'package:cake_wallet/core/node_port_validator.dart';
import 'package:cake_wallet/core/socks_proxy_node_address_validator.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/src/widgets/standard_checkbox.dart';
import 'package:cake_wallet/view_model/node_list/node_create_or_edit_view_model.dart';
import 'package:cw_core/node.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:mobx/mobx.dart';
import 'package:tor/tor.dart';

class NodeForm extends StatelessWidget {
  NodeForm({
    required this.nodeViewModel,
    required this.formKey,
    this.editingNode,
  })  : _addressController = TextEditingController(text: editingNode?.uri.host.toString()),
        _pathController = TextEditingController(text: editingNode?.path.toString()),
        _portController = TextEditingController(text: editingNode?.uri.port.toString()),
        _loginController = TextEditingController(text: editingNode?.login),
        _passwordController = TextEditingController(text: editingNode?.password),
        _socksAddressController = TextEditingController(text: editingNode?.socksProxyAddress) {
    if (editingNode != null) {
      nodeViewModel
        ..setAddress((editingNode!.uri.host.toString()))
        ..setPath((editingNode!.path.toString()))
        ..setPort((editingNode!.uri.port.toString()))
        ..setPassword((editingNode!.password ?? ''))
        ..setLogin((editingNode!.login ?? ''))
        ..setSSL((editingNode!.isSSL))
        ..setTrusted((editingNode!.trusted))
        ..setSocksProxy((editingNode!.useSocksProxy))
        ..setSocksProxyAddress((editingNode!.socksProxyAddress ?? ''));
    }
    if (nodeViewModel.hasAuthCredentials) {
      reaction((_) => nodeViewModel.login, (String login) {
        if (login != _loginController.text) {
          _loginController.text = login;
        }
      });

      reaction((_) => nodeViewModel.password, (String password) {
        if (password != _passwordController.text) {
          _passwordController.text = password;
        }
      });
    }
    reaction((_) => nodeViewModel.address, (String address) {
      if (address != _addressController.text) {
        _addressController.text = address;
      }
    });

    reaction((_) => nodeViewModel.port, (String port) {
      if (port != _portController.text) {
        _portController.text = port;
      }
    });

    reaction((_) => nodeViewModel.path, (String path) {
      if (path != _pathController.text) {
        _pathController.text = path;
      }
    });

    _addressController.addListener(() => nodeViewModel.address = _addressController.text);
    _pathController.addListener(() => nodeViewModel.path = _pathController.text);
    _portController.addListener(() => nodeViewModel.port = _portController.text);
    _loginController.addListener(() => nodeViewModel.login = _loginController.text);
    _passwordController.addListener(() => nodeViewModel.password = _passwordController.text);
    _socksAddressController
        .addListener(() => nodeViewModel.socksProxyAddress = _socksAddressController.text);
  }

  final NodeCreateOrEditViewModel nodeViewModel;
  final GlobalKey<FormState> formKey;
  final Node? editingNode;

  final TextEditingController _addressController;
  final TextEditingController _pathController;
  final TextEditingController _portController;
  final TextEditingController _loginController;
  final TextEditingController _passwordController;
  final TextEditingController _socksAddressController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: BaseTextFormField(
                  controller: _addressController,
                  hintText: S.of(context).node_address,
                  validator: NodeAddressValidator(),
                ),
              )
            ],
          ),
          SizedBox(height: 10.0),
          if (nodeViewModel.hasPathSupport) ...[
            Row(
              children: <Widget>[
                Expanded(
                  child: BaseTextFormField(
                    controller: _pathController,
                    hintText: "/path",
                    validator: NodePathValidator(),
                  ),
                )
              ],
            ),
            SizedBox(height: 10.0),
          ],
          Row(
            children: <Widget>[
              Expanded(
                  child: BaseTextFormField(
                controller: _portController,
                hintText: S.of(context).node_port,
                keyboardType: TextInputType.numberWithOptions(signed: false, decimal: false),
                validator: NodePortValidator(),
              ))
            ],
          ),
          SizedBox(height: 10.0),
          Padding(
            padding: EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Observer(
                  builder: (_) => StandardCheckbox(
                    value: nodeViewModel.useSSL,
                    gradientBackground: true,
                    borderColor: Theme.of(context).dividerColor,
                    iconColor: Colors.white,
                    onChanged: (value) => nodeViewModel.useSSL = value,
                    caption: S.of(context).use_ssl,
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 10.0),
          if (nodeViewModel.hasAuthCredentials) ...[
            Row(
              children: <Widget>[
                Expanded(
                    child: BaseTextFormField(
                  controller: _loginController,
                  hintText: S.of(context).login,
                ))
              ],
            ),
            SizedBox(height: 10.0),
            Row(
              children: <Widget>[
                Expanded(
                    child: BaseTextFormField(
                  controller: _passwordController,
                  hintText: S.of(context).password,
                ))
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Observer(
                    builder: (_) => StandardCheckbox(
                      value: nodeViewModel.trusted,
                      gradientBackground: true,
                      borderColor: Theme.of(context).dividerColor,
                      iconColor: Colors.white,
                      onChanged: (value) => nodeViewModel.trusted = value,
                      caption: S.of(context).trusted,
                    ),
                  ),
                ],
              ),
            ),
            Observer(
                builder: (_) => Column(
                      children: [
                        if (nodeViewModel.usesEmbeddedProxy) ...[
                          Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                StandardCheckbox(
                                  value: nodeViewModel.usesEmbeddedProxy,
                                  gradientBackground: false,
                                  borderColor: Theme.of(context).dividerColor,
                                  iconColor: Theme.of(context).colorScheme.primary,
                                  onChanged: null,
                                  caption: 'Embedded Tor SOCKS Proxy',
                                ),
                              ],
                            ),
                          ),
                        ],
                        Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              StandardCheckbox(
                                value: nodeViewModel.useSocksProxy,
                                gradientBackground: true,
                                borderColor: Theme.of(context).dividerColor,
                                iconColor: Colors.white,
                                onChanged: (value) {
                                  if (!value) {
                                    _socksAddressController.text = '';
                                  }
                                  nodeViewModel.useSocksProxy = value;
                                },
                                caption: 'SOCKS Proxy',
                              ),
                            ],
                          ),
                        ),
                        if (nodeViewModel.useSocksProxy) ...[
                          SizedBox(height: 10.0),
                          Row(
                            children: <Widget>[
                              Expanded(
                                  child: BaseTextFormField(
                                controller: _socksAddressController,
                                hintText: '[<ip>:]<port>',
                                validator: SocksProxyNodeAddressValidator(),
                              ))
                            ],
                          ),
                        ]
                      ],
                    )),
          ]
        ],
      ),
    );
  }
}
