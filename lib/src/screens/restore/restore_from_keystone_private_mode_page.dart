import 'dart:convert';
import 'dart:typed_data';

import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/pin_code/pin_code_widget.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:eth_sig_util/util/keccak.dart';
import 'package:flutter/material.dart';
import 'package:hex/hex.dart' as Hex;
import 'package:cryptography/cryptography.dart';

class RestoreFromKeystonePrivateModePage extends BasePage {
  @override
  String get title => '';

  RestoreFromKeystonePrivateModePage(this.code)
      : pinCodeStateKey = GlobalKey<PinCodeState>();

  final GlobalKey<PinCodeState> pinCodeStateKey;
  final String code;
  static const sixPinLength = 6;

  Future<SecretKey> _deriveKeyFromPin(Uint8List pin) async {
    final hash = keccak256(pin);
    return SecretKey(hash.buffer.asUint8List());
  }

  Future<String> _decryptData(Uint8List cipherText, SecretKey secretKey) async {
    final algorithm = Chacha20(macAlgorithm: MacAlgorithm.empty);
    final secretBox = SecretBox(
      cipherText,
      nonce: Uint8List(12),
      mac: Mac.empty,
    );
    final text = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(text);
  }

  @override
  Widget body(BuildContext context) {
    return PinCodeWidget(
      key: pinCodeStateKey,
      title: S.of(context).restore_from_private_mode_title,
      onFullPin: (pin, state) async {
        try {
          Uint8List pinDigits = Uint8List.fromList(
              pin.split('').map((char) => int.parse(char)).toList());
          final secretKey = await _deriveKeyFromPin(pinDigits);

          final restoreJson = json.decode(code);

          restoreJson['primaryAddress'] = await _decryptData(
              Uint8List.fromList(
                  Hex.HEX.decode(restoreJson['primaryAddress'] as String)),
              secretKey);

          restoreJson['privateViewKey'] = await _decryptData(
              Uint8List.fromList(
                  Hex.HEX.decode(restoreJson['privateViewKey'] as String)),
              secretKey);

          final res = json.encode(restoreJson);
          Navigator.of(context).pop(res);
        } catch (_) {
          pinCodeStateKey.currentState?.reset();
          showBar<void>(
              context,
              S
                  .of(context)
                  .error_text_failed_to_resotre_from_keystone_private_mode);
        }
      },
      initialPinLength: sixPinLength,
      onChangedPin: (String pin) {},
      hasLengthSwitcher: false,
    );
  }
}
