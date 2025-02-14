import 'package:cw_core/address_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';

abstract class WalletAddresses {
  WalletAddresses(this.walletInfo)
      : addressesMap = {},
        allAddressesMap = {},
        addressInfos = {},
        usedAddresses = {},
        hiddenAddresses = walletInfo.hiddenAddresses?.toSet() ?? {},
        manualAddresses = walletInfo.manualAddresses?.toSet() ?? {};

  final WalletInfo walletInfo;

  String get address;

  String get latestAddress {
    if (walletInfo.type == WalletType.monero || walletInfo.type == WalletType.wownero) {
      if (addressesMap.keys.length == 0) return address;
      return addressesMap[addressesMap.keys.last] ?? address;
    }
    return _localAddress ?? address;
  }

  String get primaryAddress => address;

  String? _localAddress;

  set address(String address) => _localAddress = address;

  String get addressForExchange => address;

  Map<String, String> addressesMap;
  Map<String, String> allAddressesMap;

  Map<String, String> get usableAddressesMap {
    final tmp = addressesMap.map((key, value) => MapEntry(key, value)); // copy address map
    tmp.removeWhere((key, value) => hiddenAddresses.contains(key) || manualAddresses.contains(key));
    return tmp;
  }

  Map<String, String> get usableAllAddressesMap {
    final tmp = allAddressesMap.map((key, value) => MapEntry(key, value)); // copy address map
    tmp.removeWhere((key, value) => hiddenAddresses.contains(key) || manualAddresses.contains(key));
    return tmp;
  }

  Map<int, List<AddressInfo>> addressInfos;

  Set<String> usedAddresses;

  Set<String> hiddenAddresses;

  Set<String> manualAddresses;

  Future<void> init();

  Future<void> updateAddressesInBox();

  Future<void> saveAddressesInBox() async {
    try {
      walletInfo.address = address;
      walletInfo.addresses = addressesMap;
      walletInfo.addressInfos = addressInfos;
      walletInfo.usedAddresses = usedAddresses.toList();
      walletInfo.hiddenAddresses = hiddenAddresses.toList();
      walletInfo.manualAddresses = manualAddresses.toList();

      if (walletInfo.isInBox) {
        await walletInfo.save();
      }
    } catch (e) {
      printV(e.toString());
    }
  }

  bool containsAddress(String address) =>
      addressesMap.containsKey(address) || allAddressesMap.containsKey(address);

  void resetActiveChangeAddress() {
    throw UnimplementedError();
  }
}
