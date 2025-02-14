import 'package:cake_wallet/entities/openalias_record.dart';
import 'package:cake_wallet/entities/yat_record.dart';

enum ParseFrom {
  unstoppableDomains,
  openAlias,
  yatRecord,
  fio,
  notParsed,
  twitter,
  ens,
  contact,
  mastodon,
  nostr,
  thorChain,
  wellKnown,
  zanoAlias,
  bip353
}

class ParsedAddress {
  ParsedAddress({
    required this.addresses,
    this.name = '',
    this.description = '',
    this.profileImageUrl = '',
    this.profileName = '',
    this.parseFrom = ParseFrom.notParsed,
  });

  factory ParsedAddress.fetchEmojiAddress({
    List<YatRecord>? addresses,
    required String name,
  }) {
    if (addresses?.isEmpty ?? true) {
      return ParsedAddress(addresses: [name], parseFrom: ParseFrom.yatRecord);
    }
    return ParsedAddress(
      addresses: addresses!.map((e) => e.address).toList(),
      name: name,
      parseFrom: ParseFrom.yatRecord,
    );
  }

  factory ParsedAddress.fetchUnstoppableDomainAddress({
    String? address,
    required String name,
  }) {
    if (address?.isEmpty ?? true) {
      return ParsedAddress(addresses: [name]);
    }
    return ParsedAddress(
      addresses: [address!],
      name: name,
      parseFrom: ParseFrom.unstoppableDomains,
    );
  }

  factory ParsedAddress.fetchBip353AddressAddress ({
    required String address,
    required String name,
  }) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.bip353,
    );
  }

  factory ParsedAddress.fetchOpenAliasAddress(
      {required OpenaliasRecord record, required String name}) {
    if (record.address.isEmpty) {
      return ParsedAddress(addresses: [name]);
    }
    return ParsedAddress(
      addresses: [record.address],
      name: record.name,
      description: record.description,
      parseFrom: ParseFrom.openAlias,
    );
  }

  factory ParsedAddress.fetchFioAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.fio,
    );
  }

  factory ParsedAddress.fetchTwitterAddress(
      {required String address,
      required String name,
      required String profileImageUrl,
      required String profileName,
      String? description}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      description: description ?? '',
      profileImageUrl: profileImageUrl,
      profileName: profileName,
      parseFrom: ParseFrom.twitter,
    );
  }

  factory ParsedAddress.fetchMastodonAddress(
      {required String address,
      required String name,
      required String profileImageUrl,
      required String profileName}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.mastodon,
      profileImageUrl: profileImageUrl,
      profileName: profileName,
    );
  }

  factory ParsedAddress.fetchContactAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.contact,
    );
  }

  factory ParsedAddress.fetchEnsAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.ens,
    );
  }

  factory ParsedAddress.nostrAddress(
      {required String address,
      required String name,
      required String profileImageUrl,
      required String profileName}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.nostr,
      profileImageUrl: profileImageUrl,
      profileName: profileName,
    );
  }

  factory ParsedAddress.thorChainAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.thorChain,
    );
  }

  factory ParsedAddress.zanoAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.zanoAlias,
    );
  }

  factory ParsedAddress.fetchWellKnownAddress({required String address, required String name}) {
    return ParsedAddress(
      addresses: [address],
      name: name,
      parseFrom: ParseFrom.wellKnown,
    );
  }

  final List<String> addresses;
  final String name;
  final String description;
  final String profileImageUrl;
  final String profileName;
  final ParseFrom parseFrom;
}
