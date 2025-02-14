part of 'methods.dart';

class ElectrumWorkerHeadersSubscribeRequest implements ElectrumWorkerRequest {
  ElectrumWorkerHeadersSubscribeRequest({
    this.id,
    this.completed = false,
  });

  @override
  final String method = ElectrumRequestMethods.headersSubscribe.method;
  final int? id;
  final bool completed;

  @override
  factory ElectrumWorkerHeadersSubscribeRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerHeadersSubscribeRequest(
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
    };
  }
}

class ElectrumWorkerHeadersSubscribeError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerHeadersSubscribeError({
    required super.error,
    super.id,
  }) : super();

  @override
  final String method = ElectrumRequestMethods.headersSubscribe.method;
}

class ElectrumWorkerHeadersSubscribeResponse
    extends ElectrumWorkerResponse<ElectrumHeaderResponse, Map<String, dynamic>> {
  ElectrumWorkerHeadersSubscribeResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumRequestMethods.headersSubscribe.method);

  @override
  Map<String, dynamic> resultJson(result) {
    return result.toJson();
  }

  @override
  factory ElectrumWorkerHeadersSubscribeResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerHeadersSubscribeResponse(
      result: ElectrumHeaderResponse.fromJson(json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
