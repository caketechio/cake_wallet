import 'dart:convert';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_address_record.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/format_amount.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hex/hex.dart';

class ElectrumTransactionBundle {
  ElectrumTransactionBundle(
    this.originalTransaction, {
    required this.ins,
    required this.confirmations,
    this.time,
    this.isDateValidated,
  });

  final BtcTransaction originalTransaction;
  final List<BtcTransaction> ins;
  final int? time;
  final bool? isDateValidated;
  final int confirmations;

  Map<String, dynamic> toJson() {
    return {
      'originalTransaction': originalTransaction.toHex(),
      'ins': ins.map((e) => e.toHex()).toList(),
      'confirmations': confirmations,
      'time': time,
    };
  }

  static ElectrumTransactionBundle fromJson(Map<String, dynamic> data) {
    return ElectrumTransactionBundle(
      BtcTransaction.fromRaw(data['originalTransaction'] as String),
      ins: (data['ins'] as List<Object>).map((e) => BtcTransaction.fromRaw(e as String)).toList(),
      confirmations: data['confirmations'] as int,
      time: data['time'] as int?,
      isDateValidated: data['isDateValidated'] as bool?,
    );
  }
}

class ElectrumTransactionInfo extends TransactionInfo {
  bool isReceivedSilentPayment;
  int? time;
  List<BtcTransaction>? ins;
  BtcTransaction? original;

  ElectrumTransactionInfo(
    this.type, {
    required String id,
    int? height,
    required int amount,
    int? fee,
    List<String>? inputAddresses,
    List<String>? outputAddresses,
    required TransactionDirection direction,
    required bool isPending,
    bool isReplaced = false,
    required DateTime date,
    int? time,
    bool? isDateValidated,
    required int confirmations,
    String? to,
    this.isReceivedSilentPayment = false,
    Map<String, dynamic>? additionalInfo,
    this.ins,
    this.original,
  }) {
    this.id = id;
    this.height = height;
    this.amount = amount;
    this.inputAddresses = inputAddresses;
    this.outputAddresses = outputAddresses;
    this.fee = fee;
    this.direction = direction;
    this.date = date;
    this.time = time;
    this.isPending = isPending;
    this.isReplaced = isReplaced;
    this.confirmations = confirmations;
    this.isDateValidated = isDateValidated;
    this.to = to;
    this.additionalInfo = additionalInfo ?? {};
  }

  factory ElectrumTransactionInfo.fromElectrumVerbose(Map<String, Object> obj, WalletType type,
      {required List<BitcoinAddressRecord> addresses, required int height}) {
    final addressesSet = addresses.map((addr) => addr.address).toSet();
    final id = obj['txid'] as String;
    final vins = obj['vin'] as List<Object>? ?? [];
    final vout = (obj['vout'] as List<Object>? ?? []);
    final time = obj['time'] as int?;
    final date = time != null ? DateTime.fromMillisecondsSinceEpoch(time * 1000) : DateTime.now();
    final confirmations = obj['confirmations'] as int? ?? 0;
    var direction = TransactionDirection.incoming;
    var inputsAmount = 0;
    var amount = 0;
    var totalOutAmount = 0;

    for (dynamic vin in vins) {
      final vout = vin['vout'] as int;
      final out = vin['tx']['vout'][vout] as Map;
      final outAddresses = (out['scriptPubKey']['addresses'] as List<Object>?)?.toSet();
      inputsAmount +=
          BitcoinAmountUtils.stringDoubleToBitcoinAmount((out['value'] as double? ?? 0).toString());

      if (outAddresses?.intersection(addressesSet).isNotEmpty ?? false) {
        direction = TransactionDirection.outgoing;
      }
    }

    for (dynamic out in vout) {
      final outAddresses = out['scriptPubKey']['addresses'] as List<Object>? ?? [];
      final ntrs = outAddresses.toSet().intersection(addressesSet);
      final value = BitcoinAmountUtils.stringDoubleToBitcoinAmount(
          (out['value'] as double? ?? 0.0).toString());
      totalOutAmount += value;

      if ((direction == TransactionDirection.incoming && ntrs.isNotEmpty) ||
          (direction == TransactionDirection.outgoing && ntrs.isEmpty)) {
        amount += value;
      }
    }

    final fee = inputsAmount - totalOutAmount;

    return ElectrumTransactionInfo(
      type,
      id: id,
      height: height,
      isPending: false,
      isReplaced: false,
      fee: fee,
      direction: direction,
      amount: amount,
      date: date,
      confirmations: confirmations,
      time: time,
    );
  }

  factory ElectrumTransactionInfo.fromElectrumBundle(
    ElectrumTransactionBundle bundle,
    WalletType type,
    BasedUtxoNetwork network, {
    required Set<String> addresses,
    int? height,
  }) {
    final date = bundle.time != null
        ? DateTime.fromMillisecondsSinceEpoch(bundle.time! * 1000)
        : DateTime.now();
    var direction = TransactionDirection.incoming;
    var amount = 0;
    var inputAmount = 0;
    var totalOutAmount = 0;
    List<String> inputAddresses = [];
    List<String> outputAddresses = [];

    final sentAmounts = <int>[];
    if (bundle.ins.length > 0) {
      for (var i = 0; i < bundle.originalTransaction.inputs.length; i++) {
        final input = bundle.originalTransaction.inputs[i];
        final inputTransaction = bundle.ins[i];
        final outTransaction = inputTransaction.outputs[input.txIndex];
        inputAmount += outTransaction.amount.toInt();
        if (addresses.contains(
          BitcoinAddressUtils.addressFromOutputScript(outTransaction.scriptPubKey, network),
        )) {
          direction = TransactionDirection.outgoing;
          inputAddresses.add(
            BitcoinAddressUtils.addressFromOutputScript(outTransaction.scriptPubKey, network),
          );
          sentAmounts.add(outTransaction.amount.toInt());
        }
      }
    }

    final receivedAmounts = <int>[];
    for (final out in bundle.originalTransaction.outputs) {
      totalOutAmount += out.amount.toInt();
      final addressExists = addresses
          .contains(BitcoinAddressUtils.addressFromOutputScript(out.scriptPubKey, network));
      final address = BitcoinAddressUtils.addressFromOutputScript(out.scriptPubKey, network);

      if (address.isNotEmpty) outputAddresses.add(address);

      // Check if the script contains OP_RETURN
      final script = out.scriptPubKey.script;
      if (script.contains('OP_RETURN')) {
        final index = script.indexOf('OP_RETURN');
        if (index + 1 <= script.length) {
          try {
            final opReturnData = script[index + 1].toString();
            final decodedString = utf8.decode(HEX.decode(opReturnData));
            outputAddresses.add('OP_RETURN:$decodedString');
          } catch (_) {
            outputAddresses.add('OP_RETURN:');
          }
        }
      }

      if (addressExists) {
        receivedAmounts.add(out.amount.toInt());
      }

      if ((direction == TransactionDirection.incoming && addressExists) ||
          (direction == TransactionDirection.outgoing && !addressExists)) {
        amount += out.amount.toInt();
      }
    }

    if (receivedAmounts.length == bundle.originalTransaction.outputs.length) {
      // Self-send
      direction = TransactionDirection.incoming;
      amount = receivedAmounts.reduce((a, b) => a + b);
    } else if (sentAmounts.length > 0) {
      amount = sentAmounts.reduce((a, b) => a + b);
    }

    final fee = inputAmount - totalOutAmount;
    return ElectrumTransactionInfo(
      type,
      id: bundle.originalTransaction.txId(),
      height: height,
      isPending: bundle.confirmations == 0,
      isReplaced: false,
      inputAddresses: inputAddresses,
      outputAddresses: outputAddresses,
      fee: fee,
      direction: direction,
      amount: amount,
      date: date,
      confirmations: bundle.confirmations,
      time: bundle.time,
      isDateValidated: bundle.isDateValidated,
      ins: bundle.ins,
      original: bundle.originalTransaction,
    );
  }

  factory ElectrumTransactionInfo.fromJson(Map<String, dynamic> data, WalletType type) {
    final inputAddresses = data['inputAddresses'] as List<dynamic>? ?? [];
    final outputAddresses = data['outputAddresses'] as List<dynamic>? ?? [];

    return ElectrumTransactionInfo(
      type,
      id: data['id'] as String,
      height: data['height'] as int?,
      amount: data['amount'] as int,
      fee: data['fee'] as int,
      direction: parseTransactionDirectionFromInt(data['direction'] as int),
      date: DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
      isPending: data['isPending'] as bool,
      isReplaced: data['isReplaced'] as bool? ?? false,
      confirmations: data['confirmations'] as int,
      inputAddresses:
          inputAddresses.isEmpty ? [] : inputAddresses.map((e) => e.toString()).toList(),
      outputAddresses:
          outputAddresses.isEmpty ? [] : outputAddresses.map((e) => e.toString()).toList(),
      to: data['to'] as String?,
      isReceivedSilentPayment: data['isReceivedSilentPayment'] as bool? ?? false,
      time: data['time'] as int?,
      isDateValidated: data['isDateValidated'] as bool?,
      additionalInfo: data['additionalInfo'] as Map<String, dynamic>?,
      ins:
          (data['ins'] as List<dynamic>?)?.map((e) => BtcTransaction.fromRaw(e as String)).toList(),
      original:
          data['original'] != null ? BtcTransaction.fromRaw(data['original'] as String) : null,
    );
  }

  final WalletType type;

  String? _fiatAmount;

  @override
  String amountFormatted() =>
      '${formatAmount(BitcoinAmountUtils.bitcoinAmountToString(amount: amount))} ${walletTypeToCryptoCurrency(type).title}';

  @override
  String? feeFormatted() => fee != null
      ? '${formatAmount(BitcoinAmountUtils.bitcoinAmountToString(amount: fee!))} ${walletTypeToCryptoCurrency(type).title}'
      : '';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  ElectrumTransactionInfo updated(ElectrumTransactionInfo info) {
    return ElectrumTransactionInfo(
      info.type,
      id: id,
      height: info.height,
      amount: info.amount,
      fee: info.fee,
      direction: direction,
      date: date,
      isPending: isPending,
      isReplaced: isReplaced ?? false,
      inputAddresses: inputAddresses,
      outputAddresses: outputAddresses,
      confirmations: info.confirmations,
      additionalInfo: additionalInfo,
      time: info.time,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    m['id'] = id;
    m['height'] = height;
    m['amount'] = amount;
    m['direction'] = direction.index;
    m['date'] = date.millisecondsSinceEpoch;
    m['time'] = time;
    m['isPending'] = isPending;
    m['isReplaced'] = isReplaced;
    m['confirmations'] = confirmations;
    m['fee'] = fee;
    m['to'] = to;
    m['inputAddresses'] = inputAddresses;
    m['outputAddresses'] = outputAddresses;
    m['isReceivedSilentPayment'] = isReceivedSilentPayment;
    m['additionalInfo'] = additionalInfo;
    m['isDateValidated'] = isDateValidated;
    m['ins'] = ins?.map((e) => e.toHex()).toList();
    m['original'] = original?.toHex();
    return m;
  }

  String toString() {
    return 'ElectrumTransactionInfo(id: $id, height: $height, amount: $amount, fee: $fee, direction: $direction, date: $date, isPending: $isPending, isReplaced: $isReplaced, confirmations: $confirmations, to: $to, inputAddresses: $inputAddresses, outputAddresses: $outputAddresses, additionalInfo: $additionalInfo)';
  }
}
