part of 'methods.dart';

class ElectrumWorkerBroadcastRequest implements ElectrumWorkerRequest {
  ElectrumWorkerBroadcastRequest({
    required this.transactionRaw,
    this.id,
    this.completed = false,
  });

  final String transactionRaw;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.broadcast.method;

  @override
  factory ElectrumWorkerBroadcastRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerBroadcastRequest(
      transactionRaw: json['transactionRaw'] as String,
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
      'transactionRaw': transactionRaw,
    };
  }
}

class ElectrumWorkerBroadcastError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerBroadcastError({
    required super.error,
    super.id,
  }) : super();

  @override
  String get method => ElectrumRequestMethods.broadcast.method;
}

class ElectrumWorkerBroadcastResponse extends ElectrumWorkerResponse<String, String> {
  ElectrumWorkerBroadcastResponse({
    required String txHash,
    super.error,
    super.id,
    super.completed,
  }) : super(result: txHash, method: ElectrumRequestMethods.broadcast.method);

  @override
  String resultJson(result) {
    return result;
  }

  @override
  factory ElectrumWorkerBroadcastResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerBroadcastResponse(
      txHash: json['result'] as String,
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
