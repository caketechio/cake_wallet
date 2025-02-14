part of 'methods.dart';

class ElectrumWorkerGetVersionRequest implements ElectrumWorkerRequest {
  ElectrumWorkerGetVersionRequest({
    this.id,
    this.completed = false,
  });

  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.version.method;

  @override
  factory ElectrumWorkerGetVersionRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerGetVersionRequest(
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

class ElectrumWorkerGetVersionError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerGetVersionError({
    required super.error,
    super.id,
  }) : super();

  @override
  String get method => ElectrumRequestMethods.version.method;
}

class ElectrumWorkerGetVersionResponse extends ElectrumWorkerResponse<String, String> {
  ElectrumWorkerGetVersionResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumRequestMethods.version.method);

  @override
  String resultJson(result) {
    return result.toString();
  }

  @override
  factory ElectrumWorkerGetVersionResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerGetVersionResponse(
      result: json['result'] as String,
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
