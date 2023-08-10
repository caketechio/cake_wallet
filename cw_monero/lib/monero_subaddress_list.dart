import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_monero/api/coins_info.dart';
import 'package:cw_monero/api/subaddress_list.dart' as subaddress_list;
import 'package:cw_core/subaddress.dart';

part 'monero_subaddress_list.g.dart';

class MoneroSubaddressList = MoneroSubaddressListBase
    with _$MoneroSubaddressList;

abstract class MoneroSubaddressListBase with Store {
  MoneroSubaddressListBase()
    : _isRefreshing = false,
      _isUpdating = false,
      subaddresses = ObservableList<Subaddress>();

  @observable
  ObservableList<Subaddress> subaddresses;

  bool _isRefreshing;
  bool _isUpdating;

  void update({required int accountIndex}) {
    refreshCoins(accountIndex);
    final val = countOfCoins();

    for (var i = 0; i < val; i++) {
      final coin = getCoin(i);
      print(coin.getHash());
      print(coin.globalOutputIndex);
      print(coin.internalOutputIndex);
      print("Coin is frozen: ${coin.frozen}");
      print("Coin is spent: ${coin.spent}");
    }

    print(val);
    if (_isUpdating) {
      return;
    }

    try {
      _isUpdating = true;
      refresh(accountIndex: accountIndex);
      subaddresses.clear();
      subaddresses.addAll(getAll());
      _isUpdating = false;
    } catch (e) {
      _isUpdating = false;
      rethrow;
    }
  }

  List<Subaddress> getAll() {
    var subaddresses = subaddress_list.getAllSubaddresses();

    if (subaddresses.length > 2) {
      final primary = subaddresses.first;
      final rest = subaddresses.sublist(1).reversed;
      subaddresses = [primary] + rest.toList();
    }

    return subaddresses
        .map((subaddressRow) => Subaddress(
          id: subaddressRow.getId(),
          address: subaddressRow.getAddress(),
          label: subaddressRow.getId() == 0 &&
                subaddressRow.getLabel().toLowerCase() == 'Primary account'.toLowerCase()
            ? 'Primary address'
            : subaddressRow.getLabel()))
        .toList();
  }

  Future<void> addSubaddress({required int accountIndex, required String label}) async {
    await subaddress_list.addSubaddress(
        accountIndex: accountIndex, label: label);
    update(accountIndex: accountIndex);
  }

  Future<void> setLabelSubaddress(
      {required int accountIndex, required int addressIndex, required String label}) async {
    await subaddress_list.setLabelForSubaddress(
        accountIndex: accountIndex, addressIndex: addressIndex, label: label);
    update(accountIndex: accountIndex);
  }

  void refresh({required int accountIndex}) {
    if (_isRefreshing) {
      return;
    }

    try {
      _isRefreshing = true;
      subaddress_list.refreshSubaddresses(accountIndex: accountIndex);
      _isRefreshing = false;
    } on PlatformException catch (e) {
      _isRefreshing = false;
      print(e);
      rethrow;
    }
  }
}
