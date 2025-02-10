import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/decred/decred.dart';
import 'package:cw_core/wallet_type.dart';

part 'wallet_address_edit_or_create_view_model.g.dart';

class WalletAddressEditOrCreateViewModel = WalletAddressEditOrCreateViewModelBase
    with _$WalletAddressEditOrCreateViewModel;

abstract class AddressEditOrCreateState {}

class AddressEditOrCreateStateInitial extends AddressEditOrCreateState {}

class AddressIsSaving extends AddressEditOrCreateState {}

class AddressSavedSuccessfully extends AddressEditOrCreateState {}

class AddressEditOrCreateStateFailure extends AddressEditOrCreateState {
  AddressEditOrCreateStateFailure({required this.error});

  String error;
}

abstract class WalletAddressEditOrCreateViewModelBase with Store {
  WalletAddressEditOrCreateViewModelBase({required WalletBase wallet, WalletAddressListItem? item})
      : isEdit = item != null,
        state = AddressEditOrCreateStateInitial(),
        label = item?.name ?? '',
        _item = item,
        _wallet = wallet;

  @observable
  AddressEditOrCreateState state;

  @observable
  String label;

  bool isEdit;

  final WalletAddressListItem? _item;
  final WalletBase _wallet;

  bool get isElectrum =>
      _wallet.type == WalletType.bitcoin ||
      _wallet.type == WalletType.bitcoinCash ||
      _wallet.type == WalletType.litecoin;

  Future<void> save() async {
    try {
      state = AddressIsSaving();

      if (isEdit) {
        await _update();
      } else {
        await _createNew();
      }

      state = AddressSavedSuccessfully();
    } catch (e) {
      state = AddressEditOrCreateStateFailure(error: e.toString());
    }
  }

  Future<void> _createNew() async {
    final wallet = _wallet;

    if (isElectrum) {
      await bitcoin!.generateNewAddress(wallet, label);
      await wallet.save();
    }

    if (wallet.type == WalletType.decred) {
      await decred!.generateNewAddress(wallet, label);
      await wallet.save();
    }

    if (wallet.type == WalletType.monero) {
      await monero!
          .getSubaddressList(wallet)
          .addSubaddress(wallet, accountIndex: monero!.getCurrentAccount(wallet).id, label: label);
      final addr = await monero!
          .getSubaddressList(wallet)
          .subaddresses
          .first
          .address; // first because the order is reversed
      wallet.walletAddresses.manualAddresses.add(addr);
      await wallet.save();
    }

    if (wallet.type == WalletType.wownero) {
      await wownero!
          .getSubaddressList(wallet)
          .addSubaddress(wallet, accountIndex: wownero!.getCurrentAccount(wallet).id, label: label);
      final addr = await wownero!
          .getSubaddressList(wallet)
          .subaddresses
          .first
          .address; // first because the order is reversed
      wallet.walletAddresses.manualAddresses.add(addr);
      await wallet.save();
    }

    if (wallet.type == WalletType.haven) {
      await haven!
          .getSubaddressList(wallet)
          .addSubaddress(wallet, accountIndex: haven!.getCurrentAccount(wallet).id, label: label);
      await wallet.save();
    }
  }

  Future<void> _update() async {
    final wallet = _wallet;

    if (isElectrum) await bitcoin!.updateAddress(wallet, _item!.address, label);

    if (wallet.type == WalletType.decred) {
      await decred!.updateAddress(wallet, _item!.address, label);
      await wallet.save();
      return;
    }

    final index = _item?.id;
    if (index != null) {
      if (wallet.type == WalletType.monero) {
        await monero!.getSubaddressList(wallet).setLabelSubaddress(wallet,
            accountIndex: monero!.getCurrentAccount(wallet).id, addressIndex: index, label: label);
        await wallet.save();
      }
      if (wallet.type == WalletType.wownero) {
        await wownero!.getSubaddressList(wallet).setLabelSubaddress(wallet,
            accountIndex: wownero!.getCurrentAccount(wallet).id, addressIndex: index, label: label);
        await wallet.save();
      }
      if (wallet.type == WalletType.haven) {
        await haven!.getSubaddressList(wallet).setLabelSubaddress(wallet,
            accountIndex: haven!.getCurrentAccount(wallet).id, addressIndex: index, label: label);
        await wallet.save();
      }
    }
  }
}
