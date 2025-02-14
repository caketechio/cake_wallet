import 'package:cw_core/unspent_comparable_mixin.dart';

class Unspent with UnspentComparable {
  Unspent(
    this.address,
    this.hash,
    this.value,
    this.vout,
    this.keyImage, {
    this.height,
  })  : isSending = true,
        isFrozen = false,
        isChange = false,
        note = '';

  final String address;
  final String hash;
  final int value;
  final int vout;
  final String? keyImage;

  bool isChange;
  bool isSending;
  bool isFrozen;
  int? height;
  int? confirmations;
  String note;

  bool get isP2wpkh =>
      address.startsWith('bc') || address.startsWith('tb') || address.startsWith('ltc');
}
