import 'package:cake_wallet/core/address_validator.dart';
import 'package:cake_wallet/core/yat_service.dart';
import 'package:cake_wallet/entities/ens_record.dart';
import 'package:cake_wallet/entities/openalias_record.dart';
import 'package:cake_wallet/entities/parsed_address.dart';
import 'package:cake_wallet/entities/unstoppable_domain_address.dart';
import 'package:cake_wallet/entities/emoji_string_extension.dart';
import 'package:cake_wallet/entities/wellknown_record.dart';
import 'package:cake_wallet/entities/zano_alias.dart';
import 'package:cake_wallet/exchange/provider/thorchain_exchange.provider.dart';
import 'package:cake_wallet/mastodon/mastodon_api.dart';
import 'package:cake_wallet/nostr/nostr_api.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/twitter/twitter_api.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/entities/fio_address_provider.dart';
import 'package:flutter/cupertino.dart';

class AddressResolver {
  AddressResolver({required this.yatService, required this.wallet, required this.settingsStore})
      : walletType = wallet.type;

  final YatService yatService;
  final WalletType walletType;
  final WalletBase wallet;
  final SettingsStore settingsStore;

  static const unstoppableDomains = [
    "888",
    "altimist",
    "anime",
    "austin",
    "bald",
    "benji",
    "bet",
    "binanceus",
    "bitcoin",
    "bitget",
    "blockchain",
    "ca",
    "chomp",
    "clay",
    "co",
    "com",
    "crypto",
    "dao",
    "dfz",
    "digital",
    "dream",
    "eth",
    "ethermail",
    "farms",
    "fun",
    "go",
    "group",
    "hi",
    "host",
    "info",
    "io",
    "klever",
    "kresus",
    "kryptic",
    "lfg",
    "life",
    "live",
    "ltd",
    "manga",
    "metropolis",
    "moon",
    "mumu",
    "net",
    "nft",
    "online",
    "org",
    "pog",
    "polygon",
    "press",
    "pro",
    "propykeys",
    "pudgy",
    "pw",
    "raiin",
    "secret",
    "site",
    "smobler",
    "space",
    "stepn",
    "store",
    "tball",
    "tech",
    "ubu",
    "uno",
    "unstoppable",
    "wallet",
    "website",
    "wifi",
    "witg",
    "wrkx",
    "x",
    "xmr",
    "xyz",
    "zil",
  ];

  static String? extractAddressByType({required String raw, required CryptoCurrency type}) {
    final addressPattern = AddressValidator.getAddressFromStringPattern(type);

    if (addressPattern == null) {
      throw Exception('Unexpected token: $type for getAddressFromStringPattern');
    }

    final match = RegExp(addressPattern, multiLine: true).firstMatch(raw);
    return match?.group(0)?.replaceAllMapped(RegExp('[^0-9a-zA-Z]|bitcoincash:|nano_|ban_'),
        (Match match) {
      String group = match.group(0)!;
      if (group.startsWith('bitcoincash:') ||
          group.startsWith('nano_') ||
          group.startsWith('ban_')) {
        return group;
      }
      return '';
    });
  }

  bool isEmailFormat(String address) {
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );
    return emailRegex.hasMatch(address);
  }

  Future<ParsedAddress> resolve(BuildContext context, String text, CryptoCurrency currency) async {
    final ticker = currency.title;
    try {
      // twitter handle example: @username
      if (text.startsWith('@') && !text.substring(1).contains('@')) {
        if (currency == CryptoCurrency.zano && settingsStore.lookupsZanoAlias) {
          final formattedName = text.substring(1);
          final zanoAddress = await ZanoAlias.fetchZanoAliasAddress(formattedName);
          if (zanoAddress != null && zanoAddress.isNotEmpty) {
            return ParsedAddress.zanoAddress(
              address: zanoAddress,
              name: text,
            );
          }
        }
        if (settingsStore.lookupsTwitter) {
          final formattedName = text.substring(1);
          final twitterUser = await TwitterApi.lookupUserByName(userName: formattedName);
          final addressFromBio = extractAddressByType(
              raw: twitterUser.description,
              type: CryptoCurrency.fromString(ticker, walletCurrency: wallet.currency));
          if (addressFromBio != null && addressFromBio.isNotEmpty) {
            return ParsedAddress.fetchTwitterAddress(
                address: addressFromBio,
                name: text,
                profileImageUrl: twitterUser.profileImageUrl,
                profileName: twitterUser.name);
          }

          final pinnedTweet = twitterUser.pinnedTweet?.text;
          if (pinnedTweet != null) {
            final addressFromPinnedTweet = extractAddressByType(
                raw: pinnedTweet,
                type: CryptoCurrency.fromString(ticker, walletCurrency: wallet.currency));
            if (addressFromPinnedTweet != null) {
              return ParsedAddress.fetchTwitterAddress(
                  address: addressFromPinnedTweet,
                  name: text,
                  profileImageUrl: twitterUser.profileImageUrl,
                  profileName: twitterUser.name);
            }
          }
        }
      }

      // Mastodon example: @username@hostname.xxx
      if (text.startsWith('@') && text.contains('@', 1) && text.contains('.', 1)) {
        if (settingsStore.lookupsMastodon) {
          final subText = text.substring(1);
          final hostNameIndex = subText.indexOf('@');
          final hostName = subText.substring(hostNameIndex + 1);
          final userName = subText.substring(0, hostNameIndex);

          final mastodonUser =
              await MastodonAPI.lookupUserByUserName(userName: userName, apiHost: hostName);

          if (mastodonUser != null) {
            String? addressFromBio = extractAddressByType(raw: mastodonUser.note, type: currency);

            if (addressFromBio != null && addressFromBio.isNotEmpty) {
              return ParsedAddress.fetchMastodonAddress(
                  address: addressFromBio,
                  name: text,
                  profileImageUrl: mastodonUser.profileImageUrl,
                  profileName: mastodonUser.username);
            } else {
              final pinnedPosts =
                  await MastodonAPI.getPinnedPosts(userId: mastodonUser.id, apiHost: hostName);

              if (pinnedPosts.isNotEmpty) {
                final userPinnedPostsText = pinnedPosts.map((item) => item.content).join('\n');
                String? addressFromPinnedPost =
                    extractAddressByType(raw: userPinnedPostsText, type: currency);

                if (addressFromPinnedPost != null && addressFromPinnedPost.isNotEmpty) {
                  return ParsedAddress.fetchMastodonAddress(
                      address: addressFromPinnedPost,
                      name: text,
                      profileImageUrl: mastodonUser.profileImageUrl,
                      profileName: mastodonUser.username);
                }
              }
            }
          }
        }
      }

      // .well-known scheme:
      if (text.contains('.') && text.contains('@')) {
        if (settingsStore.lookupsWellKnown) {
          final record =
              await WellKnownRecord.fetchAddressAndName(formattedName: text, currency: currency);
          if (record != null) {
            return ParsedAddress.fetchWellKnownAddress(address: record.address, name: text);
          }
        }
      }

      if (!text.startsWith('@') && text.contains('@') && !text.contains('.')) {
        final bool isFioRegistered = await FioAddressProvider.checkAvail(text);
        if (isFioRegistered) {
          final address = await FioAddressProvider.getPubAddress(text, ticker);
          return ParsedAddress.fetchFioAddress(address: address, name: text);
        }
      }
      if (text.hasOnlyEmojis) {
        if (settingsStore.lookupsYatService) {
          if (walletType != WalletType.haven) {
            final addresses = await yatService.fetchYatAddress(text, ticker);
            return ParsedAddress.fetchEmojiAddress(addresses: addresses, name: text);
          }
        }
      }

      final thorChainAddress = await ThorChainExchangeProvider.lookupAddressByName(text);
      if (thorChainAddress != null && thorChainAddress.isNotEmpty) {
        String? address =
            thorChainAddress[ticker] ?? (ticker == 'RUNE' ? thorChainAddress['THOR'] : null);
        if (address != null) {
          return ParsedAddress.thorChainAddress(address: address, name: text);
        }
      }

      final formattedName = OpenaliasRecord.formatDomainName(text);
      final domainParts = formattedName.split('.');
      final name = domainParts.last;

      if (domainParts.length <= 1 || domainParts.first.isEmpty || name.isEmpty) {
        return ParsedAddress(addresses: [text]);
      }

      if (unstoppableDomains.any((domain) => name.trim() == domain)) {
        if (settingsStore.lookupsUnstoppableDomains) {
          final address = await fetchUnstoppableDomainAddress(text, ticker);
          if (address.isNotEmpty) {
            return ParsedAddress.fetchUnstoppableDomainAddress(address: address, name: text);
          }
        }
      }

      if (text.endsWith(".eth")) {
        if (settingsStore.lookupsENS) {
          final address = await EnsRecord.fetchEnsAddress(text, wallet: wallet);
          if (address.isNotEmpty && address != "0x0000000000000000000000000000000000000000") {
            return ParsedAddress.fetchEnsAddress(name: text, address: address);
          }
        }
      }

      if (formattedName.contains(".")) {
        if (settingsStore.lookupsOpenAlias) {
          final txtRecord = await OpenaliasRecord.lookupOpenAliasRecord(formattedName);

          if (txtRecord != null) {
            final record = await OpenaliasRecord.fetchAddressAndName(
                formattedName: formattedName, ticker: ticker.toLowerCase(), txtRecord: txtRecord);
            return ParsedAddress.fetchOpenAliasAddress(record: record, name: text);
          }
        }
      }
      if (isEmailFormat(text)) {
        final nostrProfile = await NostrProfileHandler.queryProfile(context, text);
        if (nostrProfile?.relays != null) {
          final nostrUserData =
              await NostrProfileHandler.processRelays(context, nostrProfile!, text);

          if (nostrUserData != null) {
            String? addressFromBio = extractAddressByType(raw: nostrUserData.about, type: currency);
            if (addressFromBio != null && addressFromBio.isNotEmpty) {
              return ParsedAddress.nostrAddress(
                  address: addressFromBio,
                  name: text,
                  profileImageUrl: nostrUserData.picture,
                  profileName: nostrUserData.name);
            }
          }
        }
      }
    } catch (e) {
      printV(e.toString());
    }

    return ParsedAddress(addresses: [text]);
  }
}
