part of 'methods.dart';

class ElectrumWorkerTxExpandedRequest implements ElectrumWorkerRequest {
  ElectrumWorkerTxExpandedRequest({
    required this.txHash,
    required this.currentChainTip,
    this.mempoolAPIEnabled = false,
    this.id,
    this.completed = false,
  });

  final String txHash;
  final int currentChainTip;
  final bool mempoolAPIEnabled;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumWorkerMethods.txHash.method;

  @override
  factory ElectrumWorkerTxExpandedRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTxExpandedRequest(
      txHash: json['txHash'] as String,
      currentChainTip: json['currentChainTip'] as int,
      mempoolAPIEnabled: json['mempoolAPIEnabled'] as bool,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'id': id,
      'completed': completed,
      'txHash': txHash,
      'currentChainTip': currentChainTip,
      'mempoolAPIEnabled': mempoolAPIEnabled,
    };
  }
}

class ElectrumWorkerTxExpandedError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerTxExpandedError({
    required String error,
    super.id,
  }) : super(error: error);

  @override
  String get method => ElectrumWorkerMethods.txHash.method;
}

class ElectrumWorkerTxExpandedResponse
    extends ElectrumWorkerResponse<ElectrumTransactionBundle, Map<String, dynamic>> {
  ElectrumWorkerTxExpandedResponse({
    required ElectrumTransactionBundle expandedTx,
    super.error,
    super.id,
    super.completed,
  }) : super(result: expandedTx, method: ElectrumWorkerMethods.txHash.method);

  @override
  Map<String, dynamic> resultJson(result) {
    return result.toJson();
  }

  @override
  factory ElectrumWorkerTxExpandedResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTxExpandedResponse(
      expandedTx: ElectrumTransactionBundle.fromJson(json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
