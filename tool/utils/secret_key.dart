import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:convert/convert.dart';

class SecretKey {
  const SecretKey(this.name, this.generate);

  static final base = [
    SecretKey('salt', () => hex.encode(encrypt.Key.fromSecureRandom(16).bytes)),
    SecretKey('keychainSalt', () => hex.encode(encrypt.Key.fromSecureRandom(12).bytes)),
    SecretKey('key', () => hex.encode(encrypt.Key.fromSecureRandom(16).bytes)),
    SecretKey('walletSalt', () => hex.encode(encrypt.Key.fromSecureRandom(4).bytes)),
    SecretKey('shortKey', () => hex.encode(encrypt.Key.fromSecureRandom(12).bytes)),
    SecretKey('backupSalt', () => hex.encode(encrypt.Key.fromSecureRandom(8).bytes)),
    SecretKey('backupKeychainSalt', () => hex.encode(encrypt.Key.fromSecureRandom(12).bytes)),
    SecretKey('changeNowApiKey', () => ''),
    SecretKey('changeNowApiKeyDesktop', () => ''),
    SecretKey('wyreSecretKey', () => ''),
    SecretKey('wyreApiKey', () => ''),
    SecretKey('wyreAccountId', () => ''),
    SecretKey('moonPayApiKey', () => ''),
    SecretKey('moonPaySecretKey', () => ''),
    SecretKey('sideShiftAffiliateId', () => ''),
    SecretKey('simpleSwapApiKey', () => ''),
    SecretKey('simpleSwapApiKeyDesktop', () => ''),
    SecretKey('anypayToken', () => ''),
    SecretKey('onramperApiKey', () => ''),
    SecretKey('ioniaClientId', () => ''),
    SecretKey('trocadorApiKey', () => ''),
    SecretKey('trocadorExchangeMarkup', () => ''),
    SecretKey('twitterBearerToken', () => ''),
    SecretKey('anonPayReferralCode', () => ''),
    SecretKey('fiatApiKey', () => ''),
    SecretKey('payfuraApiKey', () => ''),
    SecretKey('chatwootWebsiteToken', () => ''),
    SecretKey('exolixApiKey', () => ''),
    SecretKey('robinhoodApplicationId', () => ''),
    SecretKey('exchangeHelperApiKey', () => ''),
    SecretKey('walletConnectProjectId', () => ''),
    SecretKey('moralisApiKey', () => ''),
    SecretKey('ankrApiKey', () => ''),
    SecretKey('quantexExchangeMarkup', () => ''),
    SecretKey('testCakePayApiKey', () => ''),
    SecretKey('cakePayApiKey', () => ''),
    SecretKey('CSRFToken', () => ''),
    SecretKey('authorization', () => ''),
  ];

  static final evmChainsSecrets = [
    SecretKey('etherScanApiKey', () => ''),
    SecretKey('polygonScanApiKey', () => ''),
    SecretKey('moralisApiKey', () => ''),
  ];

  static final bitcoinSecrets = [
    SecretKey('breezApiKey', () => ''),
    SecretKey('greenlightCert', () => ''),
    SecretKey('greenlightKey', () => ''),
  ];
  
  static final solanaSecrets = [
    SecretKey('ankrApiKey', () => ''),
  ];

  static final nanoSecrets = [
    SecretKey('nano2ApiKey', () => ''),
    SecretKey('nanoNowNodesApiKey', () => ''),
  ];

  static final tronSecrets = [
    SecretKey('tronGridApiKey', () => ''),
    SecretKey('tronNowNodesApiKey', () => ''),
  ];

  final String name;
  final String Function() generate;
}
