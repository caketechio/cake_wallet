import 'package:cw_zano/api/model/transfer.dart';

class GetRecentTxsAndInfoResult {
  final List<Transfer> transfers;
  final int lastItemIndex;
  final int totalTransfers;

  GetRecentTxsAndInfoResult({required this.transfers, required this.lastItemIndex, required this.totalTransfers});
  
  GetRecentTxsAndInfoResult.empty(): this.transfers = [], this.lastItemIndex = 0, this.totalTransfers = 0;

}