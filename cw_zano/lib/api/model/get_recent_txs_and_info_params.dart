class GetRecentTxsAndInfoParams {
  final int offset;
  final int count;
  final bool updateProvisionInfo;

  GetRecentTxsAndInfoParams({required this.offset, required this.count, this.updateProvisionInfo = true});

  Map<String, dynamic> toJson() => {
    'offset': offset,
    'count': count,
    'update_provision_info': updateProvisionInfo,
    'order': 'FROM_BEGIN_TO_END',
  };
}