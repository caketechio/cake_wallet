import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_type.dart';

CryptoCurrency currencyForWalletType(WalletType type, {bool? isTestnet}) {
  switch (type) {
    case WalletType.bitcoin:
      if (isTestnet == true) {
        return CryptoCurrency.tbtc;
      }
      return CryptoCurrency.btc;
    case WalletType.lightning:
      return CryptoCurrency.btcln;
    case WalletType.monero:
      return CryptoCurrency.xmr;
    case WalletType.litecoin:
      return CryptoCurrency.ltc;
    case WalletType.haven:
      return CryptoCurrency.xhv;
    case WalletType.ethereum:
      return CryptoCurrency.eth;
    case WalletType.bitcoinCash:
      return CryptoCurrency.bch;
    case WalletType.nano:
      return CryptoCurrency.nano;
    case WalletType.banano:
      return CryptoCurrency.banano;
    case WalletType.polygon:
      return CryptoCurrency.maticpoly;
    case WalletType.solana:
      return CryptoCurrency.sol;
    case WalletType.tron:
      return CryptoCurrency.trx;
    case WalletType.wownero:
      return CryptoCurrency.wow;
    case WalletType.none:
      throw Exception(
          'Unexpected wallet type: ${type.toString()} for CryptoCurrency currencyForWalletType');
  }
}
