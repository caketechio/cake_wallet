part of 'methods.dart';

class ElectrumWorkerTxHexRequest implements ElectrumWorkerRequest {
  ElectrumWorkerTxHexRequest({
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
  final String method = ElectrumWorkerMethods.txHex.method;

  @override
  factory ElectrumWorkerTxHexRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTxHexRequest(
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

class ElectrumWorkerTxHexError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerTxHexError({
    required String error,
    super.id,
  }) : super(error: error);

  @override
  String get method => ElectrumWorkerMethods.txHex.method;
}

class ElectrumWorkerTxHexResponse extends ElectrumWorkerResponse<String, String> {
  ElectrumWorkerTxHexResponse({
    required String hex,
    super.error,
    super.id,
    super.completed,
  }) : super(result: hex, method: ElectrumWorkerMethods.txHex.method);

  @override
  String resultJson(result) {
    return result;
  }

  @override
  factory ElectrumWorkerTxHexResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTxHexResponse(
      hex: json['result'] as String,
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
