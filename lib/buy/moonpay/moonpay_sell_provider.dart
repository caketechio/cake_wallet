import 'dart:convert';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:crypto/crypto.dart';
import 'package:cake_wallet/buy/buy_exception.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:cake_wallet/buy/buy_amount.dart';
import 'package:cake_wallet/buy/buy_provider.dart';
import 'package:cake_wallet/buy/buy_provider_description.dart';
import 'package:cake_wallet/buy/order.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/exchange/trade_state.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cw_core/crypto_currency.dart';
import 'package:url_launcher/url_launcher.dart';

class MoonPaySellProvider {
  MoonPaySellProvider({this.isTest = false}) : baseUrl = isTest ? _baseTestUrl : _baseProductUrl;

  static const _baseTestUrl = 'sell-sandbox.moonpay.com';
  static const _baseProductUrl = 'sell.moonpay.com';
  static String themeToMoonPayTheme(ThemeBase theme) {
    switch (theme.type) {
      case ThemeType.bright:
        return 'light';
      case ThemeType.light:
        return 'light';
      case ThemeType.dark:
        return 'dark';
    }
  }

  static String get _apiKey => secrets.moonPayApiKey;
  static String get _secretKey => secrets.moonPaySecretKey;
  final bool isTest;
  final String baseUrl;

  Future<Uri> requestUrl(
      {required CryptoCurrency currency,
      required String refundWalletAddress,
      required SettingsStore settingsStore}) async {
    final customParams = {
      'theme': themeToMoonPayTheme(settingsStore.currentTheme),
      'language': settingsStore.languageCode,
      'colorCode': settingsStore.currentTheme.type == ThemeType.dark
          ? '#${Palette.blueCraiola.value.toRadixString(16).substring(2, 8)}'
          : '#${Palette.moderateSlateBlue.value.toRadixString(16).substring(2, 8)}',
    };

    final originalUri = Uri.https(
        baseUrl,
        '',
        <String, dynamic>{
          'apiKey': _apiKey,
          'defaultBaseCurrencyCode': currency.toString().toLowerCase(),
          'refundWalletAddress': refundWalletAddress
        }..addAll(customParams));
    final messageBytes = utf8.encode('?${originalUri.query}');
    final key = utf8.encode(_secretKey);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(messageBytes);
    final signature = base64.encode(digest.bytes);

    if (isTest) {
      return originalUri;
    }

    final query = Map<String, dynamic>.from(originalUri.queryParameters);
    query['signature'] = signature;
    final signedUri = originalUri.replace(queryParameters: query);
    return signedUri;
  }
}
