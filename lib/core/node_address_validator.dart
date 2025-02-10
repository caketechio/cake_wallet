import 'package:cake_wallet/core/validator.dart';
import 'package:cake_wallet/generated/i18n.dart';

class NodeAddressValidator extends TextValidator {
  NodeAddressValidator()
      : super(
            errorMessage: S.current.error_text_node_address,
            pattern:
                '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\$|^[0-9a-zA-Z.\-]+\$');
}

class NodePathValidator extends TextValidator {
  NodePathValidator()
      : super(
          errorMessage: S.current.error_text_node_address,
          pattern: '^([/0-9a-zA-Z.\-]+)?\$',
          isAutovalidate: true,
        );
}

// NodeAddressValidatorDecredBlankException allows decred to send a blank ip
// address which effectively clears the current set persistant peer.
class NodeAddressValidatorDecredBlankException extends TextValidator {
  NodeAddressValidatorDecredBlankException()
      : super(
            errorMessage: S.current.error_text_node_address,
            isAutovalidate: true,
            pattern:
                '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\$|^[0-9a-zA-Z.\-]+\$');
}
