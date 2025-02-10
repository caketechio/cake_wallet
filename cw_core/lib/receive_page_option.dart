import 'package:cw_core/enumerate.dart';

class ReceivePageOption implements Enumerate {
  static const mainnet = ReceivePageOption._('mainnet');
  static const testnet = ReceivePageOption._('testnet');
  static const anonPayInvoice = ReceivePageOption._('anonPayInvoice');
  static const anonPayDonationLink = ReceivePageOption._('anonPayDonationLink');

  const ReceivePageOption._(this.value);

  final String value;

  String toString() {
    return value;
  }
}

const ReceivePageOptions = [
  ReceivePageOption.mainnet,
  ReceivePageOption.anonPayInvoice,
  ReceivePageOption.anonPayDonationLink
];
