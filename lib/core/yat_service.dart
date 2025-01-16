import 'dart:convert';

import 'package:cake_wallet/entities/yat_record.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:http/http.dart';

class YatService {
  static bool isDevMode = false;

  static String get apiUrl =>
      YatService.isDevMode ? YatService.apiDevUrl : YatService.apiReleaseUrl;
  static const apiReleaseUrl = "https://a.y.at";
  static const apiDevUrl = 'https://a.yat.fyi';

  static String lookupEmojiUrl(String emojiId) =>
      "$apiUrl/emoji_id/$emojiId/payment";
  
  static const String MONERO_SUB_ADDRESS = '0x1002';
  static const String MONERO_STD_ADDRESS = '0x1001';
  static const tags = {
    'XMR': "$MONERO_STD_ADDRESS,$MONERO_SUB_ADDRESS",
    'BTC': '0x1003',
    'LTC': '0x1019'
  };

  Future<List<YatRecord>> fetchYatAddress(String emojiId, String ticker) async {
    final formattedTicker = ticker.toUpperCase();
    final formattedEmojiId = emojiId.replaceAll(' ', '');
    final tag = tags[formattedTicker];
    final uri = Uri.parse(lookupEmojiUrl(formattedEmojiId)).replace(
        queryParameters: <String, dynamic>{
          "tags": tag
        });
    final yatRecords = <YatRecord>[];

    try {
      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();
      final resBody = json.decode(responseString) as Map<String, dynamic>;
      final results = resBody["result"] as Map<dynamic, dynamic>;
      // Favour a subaddress over a standard address.
      final yatRecord = (
        results[MONERO_SUB_ADDRESS] ??
        results[MONERO_STD_ADDRESS] ??
        results[tag]) as Map<String, dynamic>;

      if (yatRecord != null) {
        yatRecords.add(YatRecord.fromJson(yatRecord));
      }

      return yatRecords;
    } catch (_) {
      return yatRecords;
    }
  }
}
