import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:ens_dart/ens_dart.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class EnsRecord {
  static Future<String> fetchEnsAddress(String name, {WalletBase? wallet}) async {
    Web3Client? _client;

    if (wallet != null && wallet.type == WalletType.ethereum) {
      _client = ethereum!.getWeb3Client(wallet);
    }
    
    if (wallet != null && wallet.type == WalletType.polygon) {
      _client = polygon!.getWeb3Client(wallet);
    }

    if (_client == null) {
      _client = Web3Client("https://ethereum-rpc.publicnode.com", Client());
    }

    try {
      final ens = Ens(client: _client);

      if (wallet != null) {
        switch (wallet.type) {
          case WalletType.monero:
            return await ens.withName(name).getCoinAddress(CoinType.XMR);
          case WalletType.bitcoin:
            return await ens.withName(name).getCoinAddress(CoinType.BTC);
          case WalletType.litecoin:
            return await ens.withName(name).getCoinAddress(CoinType.LTC);
          case WalletType.haven:
            return await ens.withName(name).getCoinAddress(CoinType.XHV);
          case WalletType.ethereum:
          case WalletType.polygon:
          default:
            return (await ens.withName(name).getAddress()).hex;
        }
      }

      final addr = await ens.withName(name).getAddress();
      return addr.hex;
    } catch (e) {
      printV(e);
      return "";
    }
  }
}
