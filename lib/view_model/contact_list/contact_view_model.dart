import 'package:cake_wallet/entities/contact_record.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/entities/contact.dart';
import 'package:cw_core/crypto_currency.dart';

part 'contact_view_model.g.dart';

class ContactViewModel = ContactViewModelBase with _$ContactViewModel;

abstract class ContactViewModelBase with Store {
  ContactViewModelBase(this._contacts,  {ContactRecord? contact})
      : state = InitialExecutionState(),
        currencies = CryptoCurrency.all,
        _contact = contact,
        name = contact?.name ?? '',
        address = contact?.address ?? '',
        currency = contact?.type,
        lastChange = contact?.lastChange;


  @observable
  ExecutionState state;

  @observable
  String name;

  @observable
  String address;

  @observable
  CryptoCurrency? currency;

  DateTime? lastChange;

  @computed
  bool get isReady =>
      name.isNotEmpty &&
      (currency?.toString().isNotEmpty ?? false) &&
      address.isNotEmpty;

  final List<CryptoCurrency> currencies;
  final Box<Contact> _contacts;
  final ContactRecord? _contact;

  @action
  void reset() {
    address = '';
    name = '';
    currency = null;
  }

  Future<void> save() async {
    try {
      state = IsExecutingState();
      final now = DateTime.now();

      if (doesContactNameExist(name)) {
        state = FailureState(S.current.contact_name_exists);
        return;
      }

      if (_contact != null && _contact.original.isInBox) {
        _contact.name = name;
        _contact.address = address;
        _contact.type = currency!;
        _contact.lastChange = now;
        await _contact.save();
      } else {
        await _contacts
            .add(Contact(name: name, address: address, type: currency!, lastChange: now));
      }

            lastChange = now;
      state = ExecutedSuccessfullyState();
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  bool doesContactNameExist(String name) {
    return _contacts.values.any((contact) => contact.name == name);
  }
}