import 'package:cw_core/receive_page_option.dart';

class LightningReceivePageOption implements ReceivePageOption {
  static const lightningOnchain = LightningReceivePageOption._('Receive Lightning Onchain');
  static const lightningInvoice = LightningReceivePageOption._('Create Lightning Invoice');

  const LightningReceivePageOption._(this.value);

  final String value;

  String toString() {
    // TODO: translate these values:
    return value;
  }

  static const all = [
    LightningReceivePageOption.lightningInvoice,
    LightningReceivePageOption.lightningOnchain
  ];
}
