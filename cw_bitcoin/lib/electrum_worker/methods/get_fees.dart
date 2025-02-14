part of 'methods.dart';

class ElectrumWorkerGetFeesRequest implements ElectrumWorkerRequest {
  ElectrumWorkerGetFeesRequest({
    this.mempoolAPIEnabled = false,
    this.id,
    this.completed = false,
  });

  final bool mempoolAPIEnabled;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.estimateFee.method;

  @override
  factory ElectrumWorkerGetFeesRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerGetFeesRequest(
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
      'mempoolAPIEnabled': mempoolAPIEnabled,
    };
  }
}

class ElectrumWorkerGetFeesError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerGetFeesError({
    required super.error,
    super.id,
  }) : super();

  @override
  String get method => ElectrumRequestMethods.estimateFee.method;
}

class ElectrumWorkerGetFeesResponse
    extends ElectrumWorkerResponse<TransactionPriorities?, Map<String, int>> {
  ElectrumWorkerGetFeesResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumRequestMethods.estimateFee.method);

  @override
  Map<String, int> resultJson(result) {
    return result?.toJson() ?? {};
  }

  @override
  factory ElectrumWorkerGetFeesResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerGetFeesResponse(
      result: json['result'] == null
          ? null
          : deserializeTransactionPriorities(json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
