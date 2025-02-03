import 'dart:convert';

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/twitter/twitter_user.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:http/http.dart' as http;

class TwitterApi {
  static const twitterBearerToken = secrets.twitterBearerToken;
  static const httpsScheme = 'https';
  static const apiHost = 'api.twitter.com';
  static const userPath = '/2/users/by/username/';

  static Future<TwitterUser> lookupUserByName({required String userName}) async {
    final queryParams = {
      'user.fields': 'description,profile_image_url',
      'expansions': 'pinned_tweet_id',
      'tweet.fields': 'note_tweet'
    };
    final headers = {'authorization': 'Bearer $twitterBearerToken'};
    final uri = Uri(
        scheme: httpsScheme,
        host: apiHost,
        path: userPath + userName,
        queryParameters: queryParams);

    final response = await ProxyWrapper().get(clearnetUri: uri, headers: headers).catchError((error) {
      throw Exception('HTTP request failed: $error');
    });

    if (response.statusCode != 200) {
      throw Exception('Unexpected http status: ${response.statusCode}');
    }
    final responseString = await response.transform(utf8.decoder).join();

    final Map<String, dynamic> responseJSON = jsonDecode(responseString) as Map<String, dynamic>;
    if (responseJSON['errors'] != null &&
        !responseJSON['errors'][0]['detail']
            .toString()
            .contains("Could not find tweet with pinned_tweet_id")) {
      throw Exception(responseJSON['errors'][0]['detail']);
    }

    return TwitterUser.fromJson(responseJSON, _getPinnedTweet(responseJSON));
  }

  static Tweet? _getPinnedTweet(Map<String, dynamic> responseJSON) {
    try {
      final tweetId = responseJSON['data']['pinned_tweet_id'] as String?;
      if (tweetId == null || responseJSON['includes'] == null) return null;

      final tweetIncludes = List.from(responseJSON['includes']['tweets'] as List);
      final pinnedTweetData = tweetIncludes.firstWhere(
        (tweet) => tweet['id'] == tweetId,
        orElse: () => null,
      ) as Map<String, dynamic>?;

      if (pinnedTweetData == null) return null;

      final pinnedTweetText =
          (pinnedTweetData['note_tweet']?['text'] ?? pinnedTweetData['text']) as String;

      return Tweet(id: tweetId, text: pinnedTweetText);
    } catch (e) {
      return null;
    }
  }
}
