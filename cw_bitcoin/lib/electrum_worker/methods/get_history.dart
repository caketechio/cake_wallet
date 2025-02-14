part of 'methods.dart';

class ElectrumWorkerGetHistoryRequest implements ElectrumWorkerRequest {
  ElectrumWorkerGetHistoryRequest({
    required this.addresses,
    required this.storedTxs,
    required this.walletType,
    required this.chainTip,
    required this.network,
    this.mempoolAPIEnabled = false,
    this.id,
    this.completed = false,
  });

  final List<BitcoinAddressRecord> addresses;
  final List<ElectrumTransactionInfo> storedTxs;
  final WalletType walletType;
  final int chainTip;
  final BasedUtxoNetwork network;
  final bool mempoolAPIEnabled;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.getHistory.method;

  @override
  factory ElectrumWorkerGetHistoryRequest.fromJson(Map<String, dynamic> m) {
    final walletType = WalletType.values[m['walletType'] as int];

    return ElectrumWorkerGetHistoryRequest(
      addresses:
          (m['addresses'] as List).map((e) => BitcoinAddressRecord.fromJSON(e as String)).toList(),
      storedTxs: (m['storedTxIds'] as List)
          .map((e) => ElectrumTransactionInfo.fromJson(e as Map<String, dynamic>, walletType))
          .toList(),
      walletType: walletType,
      chainTip: m['chainTip'] as int,
      network: BasedUtxoNetwork.fromName(m['network'] as String),
      mempoolAPIEnabled: m['mempoolAPIEnabled'] as bool,
      id: m['id'] as int?,
      completed: m['completed'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'id': id,
      'completed': completed,
      'addresses': addresses.map((e) => e.toJSON()).toList(),
      'storedTxIds': storedTxs.map((e) => e.toJson()).toList(),
      'walletType': walletType.index,
      'chainTip': chainTip,
      'network': network.value,
      'mempoolAPIEnabled': mempoolAPIEnabled,
    };
  }
}

class ElectrumWorkerGetHistoryError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerGetHistoryError({
    required super.error,
    super.id,
  }) : super();

  @override
  final String method = ElectrumRequestMethods.getHistory.method;
}

class AddressHistoriesResponse {
  final BitcoinAddressRecord addressRecord;
  final List<ElectrumTransactionInfo> txs;
  final WalletType walletType;

  AddressHistoriesResponse(
      {required this.addressRecord, required this.txs, required this.walletType});

  factory AddressHistoriesResponse.fromJson(Map<String, dynamic> json) {
    final walletType = WalletType.values[json['walletType'] as int];

    return AddressHistoriesResponse(
      addressRecord: BitcoinAddressRecord.fromJSON(json['address'] as String),
      txs: (json['txs'] as List)
          .map((e) => ElectrumTransactionInfo.fromJson(e as Map<String, dynamic>, walletType))
          .toList(),
      walletType: walletType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': addressRecord.toJSON(),
      'txs': txs.map((e) => e.toJson()).toList(),
      'walletType': walletType.index,
    };
  }
}

class ElectrumWorkerGetHistoryResponse
    extends ElectrumWorkerResponse<List<AddressHistoriesResponse>, List<Map<String, dynamic>>> {
  ElectrumWorkerGetHistoryResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumRequestMethods.getHistory.method);

  @override
  List<Map<String, dynamic>> resultJson(result) {
    return result.map((e) => e.toJson()).toList();
  }

  @override
  factory ElectrumWorkerGetHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerGetHistoryResponse(
      result: (json['result'] as List)
          .map((e) => AddressHistoriesResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
