part of 'methods.dart';

class ElectrumWorkerStopScanningRequest implements ElectrumWorkerRequest {
  ElectrumWorkerStopScanningRequest({
    this.id,
    this.completed = false,
  });

  final int? id;
  final bool completed;

  @override
  final String method = ElectrumWorkerMethods.stopScanning.method;

  @override
  factory ElectrumWorkerStopScanningRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerStopScanningRequest(
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

class ElectrumWorkerStopScanningError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerStopScanningError({required super.error, super.id}) : super();

  @override
  final String method = ElectrumWorkerMethods.stopScanning.method;
}

class ElectrumWorkerStopScanningResponse extends ElectrumWorkerResponse<bool, String> {
  ElectrumWorkerStopScanningResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumWorkerMethods.stopScanning.method);

  @override
  String resultJson(result) {
    return result.toString();
  }

  @override
  factory ElectrumWorkerStopScanningResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerStopScanningResponse(
      result: json['result'] as bool,
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
