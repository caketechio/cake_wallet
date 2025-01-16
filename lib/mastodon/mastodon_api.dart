import 'dart:convert';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart' as http;
import 'package:cake_wallet/mastodon/mastodon_user.dart';

class MastodonAPI {
  static const httpsScheme = 'https';
  static const userPath = '/api/v1/accounts/lookup';
  static const statusesPath = '/api/v1/accounts/:id/statuses';

  static Future<MastodonUser?> lookupUserByUserName(
      {required String userName, required String apiHost}) async {
    try {
      final queryParams = {'acct': userName};

      final uri = Uri(
        scheme: httpsScheme,
        host: apiHost,
        path: userPath,
        queryParameters: queryParams,
      );

      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> responseJSON = json.decode(responseString) as Map<String, dynamic>;

      return MastodonUser.fromJson(responseJSON);
    } catch (e) {
      printV('Error in lookupUserByUserName: $e');
      return null;
    }
  }

  static Future<List<PinnedPost>> getPinnedPosts({
    required String userId,
    required String apiHost,
  }) async {
    try {
      final queryParams = {'pinned': 'true'};

      final uri = Uri(
        scheme: httpsScheme,
        host: apiHost,
        path: statusesPath.replaceAll(':id', userId),
        queryParameters: queryParams,
      );

      final response = await ProxyWrapper().get(clearnetUri: uri);
      final responseString = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('Unexpected HTTP status: ${response.statusCode}');
      }

      final List<dynamic> responseJSON = json.decode(responseString) as List<dynamic>;

      return responseJSON.map((json) => PinnedPost.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      printV('Error in getPinnedPosts: $e');
      throw e;
    }
  }
}
