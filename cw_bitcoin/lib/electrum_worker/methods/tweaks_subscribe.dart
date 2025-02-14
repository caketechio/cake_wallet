part of 'methods.dart';

class ScanData {
  final List<SilentPaymentOwner> silentPaymentsWallets;
  final int height;
  final BasedUtxoNetwork network;
  final int chainTip;
  final List<String> transactionHistoryIds;
  final Map<String, int> labels;
  final List<int> labelIndexes;
  final bool isSingleScan;
  final bool shouldSwitchNodes;

  ScanData({
    required this.silentPaymentsWallets,
    required this.height,
    required this.network,
    required this.chainTip,
    required this.transactionHistoryIds,
    required this.labels,
    required this.labelIndexes,
    required this.isSingleScan,
    required this.shouldSwitchNodes,
  });

  factory ScanData.fromHeight(ScanData scanData, int newHeight) {
    return ScanData(
      silentPaymentsWallets: scanData.silentPaymentsWallets,
      height: newHeight,
      network: scanData.network,
      chainTip: scanData.chainTip,
      transactionHistoryIds: scanData.transactionHistoryIds,
      labels: scanData.labels,
      labelIndexes: scanData.labelIndexes,
      isSingleScan: scanData.isSingleScan,
      shouldSwitchNodes: scanData.shouldSwitchNodes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'silentAddress': silentPaymentsWallets.map((e) => e.toJson()).toList(),
      'height': height,
      'network': network.value,
      'chainTip': chainTip,
      'transactionHistoryIds': transactionHistoryIds,
      'labels': labels,
      'labelIndexes': labelIndexes,
      'isSingleScan': isSingleScan,
      'shouldSwitchNodes': shouldSwitchNodes,
    };
  }

  static ScanData fromJson(Map<String, dynamic> json) {
    return ScanData(
      silentPaymentsWallets: (json['silentAddress'] as List)
          .map((e) => SilentPaymentOwner.fromJson(e as Map<String, dynamic>))
          .toList(),
      height: json['height'] as int,
      network: BasedUtxoNetwork.fromName(json['network'] as String),
      chainTip: json['chainTip'] as int,
      transactionHistoryIds:
          (json['transactionHistoryIds'] as List).map((e) => e as String).toList(),
      labels: json['labels'] as Map<String, int>,
      labelIndexes: (json['labelIndexes'] as List).map((e) => e as int).toList(),
      isSingleScan: json['isSingleScan'] as bool,
      shouldSwitchNodes: json['shouldSwitchNodes'] as bool,
    );
  }
}

class ElectrumWorkerTweaksSubscribeRequest implements ElectrumWorkerRequest {
  ElectrumWorkerTweaksSubscribeRequest({
    required this.scanData,
    this.id,
    this.completed = false,
  });

  final ScanData scanData;
  final int? id;
  final bool completed;

  @override
  final String method = ElectrumRequestMethods.tweaksSubscribe.method;

  @override
  factory ElectrumWorkerTweaksSubscribeRequest.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTweaksSubscribeRequest(
      scanData: ScanData.fromJson(json['scanData'] as Map<String, dynamic>),
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
      'scanData': scanData.toJson(),
    };
  }
}

class ElectrumWorkerTweaksSubscribeError extends ElectrumWorkerErrorResponse {
  ElectrumWorkerTweaksSubscribeError({
    required super.error,
    super.id,
  }) : super();

  @override
  final String method = ElectrumRequestMethods.tweaksSubscribe.method;
}

class TweakResponseData {
  final ElectrumTransactionInfo txInfo;
  final List<BitcoinUnspent> unspents;

  TweakResponseData({required this.txInfo, required this.unspents});

  Map<String, dynamic> toJson() {
    return {
      'txInfo': txInfo.toJson(),
      'unspent': unspents.map((e) => e.toJson()).toList(),
    };
  }

  static TweakResponseData fromJson(Map<String, dynamic> json) {
    return TweakResponseData(
      txInfo: ElectrumTransactionInfo.fromJson(
        json['txInfo'] as Map<String, dynamic>,
        WalletType.bitcoin,
      ),
      unspents: (json['unspent'] as List)
          .map((e) => BitcoinUnspent.fromJSON(null, e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TweaksSyncResponse {
  int? height;
  SyncStatus? syncStatus;
  Map<String, TweakResponseData>? transactions = {};
  final bool wasSingleBlock;

  TweaksSyncResponse({
    required this.wasSingleBlock,
    this.height,
    this.syncStatus,
    this.transactions,
  });

  Map<String, dynamic> toJson() {
    return {
      'height': height,
      'syncStatus': syncStatus == null ? null : syncStatusToJson(syncStatus!),
      'transactions': transactions?.map((key, value) => MapEntry(key, value.toJson())),
      'wasSingleBlock': wasSingleBlock,
    };
  }

  static TweaksSyncResponse fromJson(Map<String, dynamic> json) {
    return TweaksSyncResponse(
      height: json['height'] as int?,
      syncStatus: json['syncStatus'] == null
          ? null
          : syncStatusFromJson(json['syncStatus'] as Map<String, dynamic>),
      transactions: json['transactions'] == null
          ? null
          : (json['transactions'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                TweakResponseData.fromJson(value as Map<String, dynamic>),
              ),
            ),
      wasSingleBlock: json['wasSingleBlock'] as bool? ?? false,
    );
  }
}

class ElectrumWorkerTweaksSubscribeResponse
    extends ElectrumWorkerResponse<TweaksSyncResponse, Map<String, dynamic>> {
  ElectrumWorkerTweaksSubscribeResponse({
    required super.result,
    super.error,
    super.id,
    super.completed,
  }) : super(method: ElectrumRequestMethods.tweaksSubscribe.method);

  @override
  Map<String, dynamic> resultJson(result) {
    return result.toJson();
  }

  @override
  factory ElectrumWorkerTweaksSubscribeResponse.fromJson(Map<String, dynamic> json) {
    return ElectrumWorkerTweaksSubscribeResponse(
      result: TweaksSyncResponse.fromJson(json['result'] as Map<String, dynamic>),
      error: json['error'] as String?,
      id: json['id'] as int?,
      completed: json['completed'] as bool? ?? false,
    );
  }
}
