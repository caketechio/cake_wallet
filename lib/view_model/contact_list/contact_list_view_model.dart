import 'dart:async';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/contact_base.dart';
import 'package:cake_wallet/entities/wallet_contact.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/entities/contact_record.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cake_wallet/utils/mobx.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:collection/collection.dart';

part 'contact_list_view_model.g.dart';

class ContactListViewModel = ContactListViewModelBase with _$ContactListViewModel;

abstract class ContactListViewModelBase with Store {
  ContactListViewModelBase(
      this.contactSource, this.walletInfoSource, this._currency, this.settingsStore)
      : contacts = ObservableList<ContactRecord>(),
        walletContacts = [],
        isAutoGenerateEnabled =
            settingsStore.autoGenerateSubaddressStatus == AutoGenerateSubaddressStatus.enabled {
    walletInfoSource.values.forEach((info) {
      if (isAutoGenerateEnabled && [WalletType.monero, WalletType.wownero, WalletType.haven].contains(info.type) && info.addressInfos != null) {
        for (var key in info.addressInfos!.keys) {
          final value = info.addressInfos![key];
          final address = value?.first;
          if (address != null) {
            final name = _createName(info.name, address.label, key: key);
            walletContacts.add(WalletContact(
              address.address,
              name,
              walletTypeToCryptoCurrency(info.type),
            ));
          }
        }
      } else if (info.addresses?.isNotEmpty == true && info.addresses!.length > 1) {
        if ([WalletType.monero, WalletType.wownero, WalletType.haven].contains(info.type)) {
          final address = info.address;
          final name = _createName(info.name, "");
          walletContacts.add(WalletContact(
            address,
            name,
            walletTypeToCryptoCurrency(info.type),
          ));
        } else {
          info.addresses!.forEach((address, label) {
            if (label.isEmpty) {
              return;
            }
            final name = _createName(info.name, label);
            walletContacts.add(WalletContact(
              address,
              name,
              walletTypeToCryptoCurrency(info.type,
                  isTestnet:
                      info.network == null ? false : info.network!.toLowerCase().contains("testnet")),
            ));
          });
        }
      } else {
        walletContacts.add(WalletContact(
          info.address,
          info.name,
          walletTypeToCryptoCurrency(info.type),
        ));
      }
    });

    _subscription = contactSource.bindToListWithTransform(
        contacts, (Contact contact) => ContactRecord(contactSource, contact),
        initialFire: true);
  }

  String _createName(String walletName, String label, {int? key = null}) {
    return label.isNotEmpty
        ? '$walletName${key == null ? "" : " [#${key}]"} (${label.replaceAll(RegExp(r'active', caseSensitive: false), S.current.active).replaceAll(RegExp(r'silent payments', caseSensitive: false), S.current.silent_payments)})'
        : walletName;
  }

  final bool isAutoGenerateEnabled;
  final Box<Contact> contactSource;
  final Box<WalletInfo> walletInfoSource;
  final ObservableList<ContactRecord> contacts;
  final List<WalletContact> walletContacts;
  final CryptoCurrency? _currency;
  StreamSubscription<BoxEvent>? _subscription;
  final SettingsStore settingsStore;

  bool get isEditable => _currency == null;

  @computed
  bool get shouldRequireTOTP2FAForAddingContacts =>
      settingsStore.shouldRequireTOTP2FAForAddingContacts;

  Future<void> delete(ContactRecord contact) async => contact.original.delete();

  @computed
  List<ContactRecord> get contactsToShow =>
      contacts.where((element) => _isValidForCurrency(element)).toList();

  @computed
  List<WalletContact> get walletContactsToShow =>
      walletContacts.where((element) => _isValidForCurrency(element)).toList();

  bool _isValidForCurrency(ContactBase element) {
    return _currency == null ||
        element.type == _currency ||
        element.type.title == _currency!.tag ||
        element.type.tag == _currency!.tag;
  }
}
