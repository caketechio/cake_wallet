import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_core/unspent_transaction_output.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_core/wallet_info.dart';

class BitcoinUnspent extends Unspent {
  BitcoinUnspent(
    BaseBitcoinAddressRecord addressRecord,
    String hash,
    int value,
    int vout,
    int? height,
  )   : bitcoinAddressRecord = addressRecord,
        super(addressRecord.address, hash, value, vout, null, height: height);

  factory BitcoinUnspent.fromUTXO(BaseBitcoinAddressRecord address, ElectrumUtxo utxo) =>
      BitcoinUnspent(address, utxo.txId, utxo.value.toInt(), utxo.vout, utxo.height);

  factory BitcoinUnspent.fromJSON(
    BaseBitcoinAddressRecord? address,
    Map<String, dynamic> json, [
    DerivationInfo? derivationInfo,
    BasedUtxoNetwork? network,
  ]) {
    return BitcoinUnspent(
      address ??
          BaseBitcoinAddressRecord.fromJSON(
            json['address_record'] as String,
            derivationInfo,
            network,
          ),
      json['tx_hash'] as String,
      int.parse(json['value'].toString()),
      int.parse(json['tx_pos'].toString()),
      json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'address_record': bitcoinAddressRecord.toJSON(),
      'tx_hash': hash,
      'value': value,
      'tx_pos': vout,
      'height': height,
    };
    return json;
  }

  final BaseBitcoinAddressRecord bitcoinAddressRecord;

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;
    return o is BitcoinUnspent && hash == o.hash && vout == o.vout;
  }

  @override
  int get hashCode => Object.hash(hash, vout);
}
