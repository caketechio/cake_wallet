part of 'methods.dart';

class ElectrumWorkerConnectionRequest implements ElectrumWorkerRequest {
  ElectrumWorkerConnectionRequest({
    required this.uri,
    required this.network,
    required this.useSSL,
    required this.walletType,
    this.id,
    this.completed = false,
  });

  final Uri uri;
  final bool useSSL;
  final BasedUtxoNetwork network;
  final WalletType walletType;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumWorkerMethods.connect.method;

  @override
  factory ElectrumWorkerConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerConnectionRequest(
      uri: Uri.parse(json['uri'] as String),
      network: BasedUtxoNetwork.values.firstWhere(
        (e) => e.toString() == json['network'] as String,
      ),
      walletType: WalletType.values.firstWhere(
        (e) => e.toString() == json['walletType'] as String,
      ),
      useSSL: json['useSSL'] as bool,
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
      'uri': uri.toString(),
      'network': network.toString(),
      'walletType': walletType.toString(),
      'useSSL': useSSL,
    };
  }
}

class ElectrumWorkerConnectionError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerConnectionError({
    required super.error,
    super.id,
  }) : super();

  @override
  String get method => ElectrumWorkerMethods.connect.method;
}

class ElectrumWorkerConnectionResponse extends ElectrumWorkerResponse<ConnectionStatus, String> {
  ElectrumWorkerConnectionResponse({
    required ConnectionStatus status,
    super.error,
    super.id,
    super.completed,
  }) : super(
          result: status,
          method: ElectrumWorkerMethods.connect.method,
        );

  @override
  String resultJson(result) {
    return result.toString();
  }

  @override
  factory ElectrumWorkerConnectionResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerConnectionResponse(
      status: ConnectionStatus.values.firstWhere(
        (e) => e.toString() == json['result'] as String,
      ),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
