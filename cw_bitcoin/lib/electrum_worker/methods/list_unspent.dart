part of 'methods.dart';

class ElectrumWorkerListUnspentRequest implements ElectrumWorkerRequest {
  ElectrumWorkerListUnspentRequest({
    required this.scripthashes,
    this.id,
    this.completed = false,
  });

  final List<String> scripthashes;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.listunspent.method;

  @override
  factory ElectrumWorkerListUnspentRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerListUnspentRequest(
      scripthashes: json['scripthashes'] as List<String>,
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
      'scripthashes': scripthashes,
    };
  }
}

class ElectrumWorkerListUnspentError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerListUnspentError({
    required super.error,
    super.id,
  }) : super();

  @override
  String get method => ElectrumRequestMethods.listunspent.method;
}

class ElectrumWorkerListUnspentResponse
    extends ElectrumWorkerResponse<Map<String, List<ElectrumUtxo>>, Map<String, dynamic>> {
  ElectrumWorkerListUnspentResponse({
    required Map<String, List<ElectrumUtxo>> utxos,
    super.error,
    super.id,
    super.completed,
  }) : super(result: utxos, method: ElectrumRequestMethods.listunspent.method);

  @override
  Map<String, dynamic> resultJson(result) {
    return result.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()));
  }

  @override
  factory ElectrumWorkerListUnspentResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerListUnspentResponse(
      utxos: (json['result'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key,
            (value as List).map((e) => ElectrumUtxo.fromJson(e as Map<String, dynamic>)).toList()),
      ),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
