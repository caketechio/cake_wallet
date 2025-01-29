import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_zano/zano_wallet_api.dart';
import 'package:mobx/mobx.dart';

part 'zano_wallet_addresses.g.dart';

class ZanoWalletAddresses = ZanoWalletAddressesBase with _$ZanoWalletAddresses;

abstract class ZanoWalletAddressesBase extends WalletAddresses with Store {
  ZanoWalletAddressesBase(WalletInfo walletInfo)
      : address = '',
        super(walletInfo);

  @override
  @observable
  String address;

  @override
  Future<void> init() async {
    address = walletInfo.address;
    await updateAddressesInBox();
  }

  Future<void> updateAddress(String address) async {
    this.address = address;
    await updateAddressesInBox();
  }

  @override
  Future<void> updateAddressesInBox() async {
    try {
      addressesMap.clear();
      addressesMap[address] = '';
      await saveAddressesInBox();
    } catch (e) {
      printV(e.toString());
    }
  }
}
