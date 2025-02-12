import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/bip/bip/bip32/bip32.dart';
import 'package:cw_bitcoin/electrum_wallet_addresses.dart';
import 'package:cw_bitcoin/payjoin/manager.dart';
import 'package:cw_bitcoin/utils.dart';
import 'package:cw_core/unspent_coin_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:mobx/mobx.dart';
import 'package:payjoin_flutter/receive.dart' as payjoin;

part 'bitcoin_wallet_addresses.g.dart';

class BitcoinWalletAddresses = BitcoinWalletAddressesBase with _$BitcoinWalletAddresses;

abstract class BitcoinWalletAddressesBase extends ElectrumWalletAddresses with Store {
  BitcoinWalletAddressesBase(
    WalletInfo walletInfo, {
    required super.mainHd,
    required super.sideHd,
    required super.network,
    required super.isHardwareWallet,
    required this.payjoinManager,
    super.initialAddresses,
    super.initialRegularAddressIndex,
    super.initialChangeAddressIndex,
    super.initialSilentAddresses,
    super.initialSilentAddressIndex = 0,
    super.masterHd,
  }) : super(walletInfo);

  final PayjoinManager payjoinManager;

  @observable
  payjoin.Receiver? currentPayjoinReceiver;

  @computed
  String? get payjoinEndpoint =>
      currentPayjoinReceiver?.pjUriBuilder().build().pjEndpoint();

  @override
  String getAddress(
      {required int index,
      required Bip32Slip10Secp256k1 hd,
      BitcoinAddressType? addressType,
      UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any}) {
    if (addressType == P2pkhAddressType.p2pkh)
      return generateP2PKHAddress(hd: hd, index: index, network: network);

    if (addressType == SegwitAddresType.p2tr)
      return generateP2TRAddress(hd: hd, index: index, network: network);

    if (addressType == SegwitAddresType.p2wsh)
      return generateP2WSHAddress(hd: hd, index: index, network: network);

    if (addressType == P2shAddressType.p2wpkhInP2sh)
      return generateP2SHAddress(hd: hd, index: index, network: network);

    return generateP2WPKHAddress(hd: hd, index: index, network: network);
  }

  Future<void> initPayjoin() async {
    currentPayjoinReceiver = await payjoinManager.initReceiver(primaryAddress);
    
    payjoinManager.resumeSessions();
  }

  Future<void> newPayjoinReceiver() async {
    currentPayjoinReceiver = await payjoinManager.initReceiver(primaryAddress);

    printV("Initializing new Payjoin Receiver");
    payjoinManager.spawnNewReceiver(receiver: currentPayjoinReceiver!);
  }
}
