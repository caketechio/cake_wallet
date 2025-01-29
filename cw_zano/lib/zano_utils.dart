import 'dart:convert';

import 'package:monero/zano.dart' as zano;
import 'package:cw_zano/api/model/get_address_info_result.dart';

class ZanoUtils {
  static bool validateAddress(String address) {
    try {
      final result = GetAddressInfoResult.fromJson(
        jsonDecode(zano.PlainWallet_getAddressInfo(address)) as Map<String, dynamic>,
      );
      return result.valid;
    } catch (err) {
      return false;
    }
  }
}
