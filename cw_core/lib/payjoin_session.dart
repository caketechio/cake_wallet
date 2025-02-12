import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'payjoin_session.g.dart';

@HiveType(typeId: PAYJOIN_SESSION_TYPE_ID)
class PayjoinSession extends HiveObject {
  PayjoinSession({
    required this.walletId,
    this.receiver,
    this.sender,
    this.pjUri,
    this.status = "created",
    this.inProgressSince,
    this.rawAmount,
  }) {
    if (receiver == null) {
      assert(sender != null);
      assert(pjUri != null);
    } else {
      assert(receiver != null);
    }
  }

  static const typeId = PAYJOIN_SESSION_TYPE_ID;
  static const boxName = 'PayjoinSessions';

  @HiveField(0)
  final String walletId;

  @HiveField(1)
  final String? sender;

  @HiveField(2)
  final String? receiver;

  @HiveField(3)
  final String? pjUri;

  @HiveField(4)
  String status;

  @HiveField(5)
  DateTime? inProgressSince;

  @HiveField(6)
  String? txId;
  
  @HiveField(7)
  String? rawAmount;

  bool get isSenderSession => sender != null;

  BigInt get amount => BigInt.parse(rawAmount ?? "0");
  set amount(BigInt amount) => rawAmount = amount.toString();

}

enum PayjoinSessionStatus {
  created,
  inProgress,
  success,
  unrecoverable,
}
