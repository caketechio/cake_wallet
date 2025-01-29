import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_type.dart';

CryptoCurrency currencyForWalletType(WalletType type, {bool? isTestnet}) {
  switch (type) {
    case WalletType.bitcoin:
      if (isTestnet == true) {
        return CryptoCurrency.tbtc;
      }
      return CryptoCurrency.btc;
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
    case WalletType.zano:
      return CryptoCurrency.zano;
    case WalletType.none:
      throw Exception(
          
          'Unexpected wallet type: ${type.toString()} for CryptoCurrency currencyForWalletType');
  }
}

WalletType? walletTypeForCurrency(CryptoCurrency currency) {
  switch (currency) {
    case CryptoCurrency.btc:
      return WalletType.bitcoin;
    case CryptoCurrency.xmr:
      return WalletType.monero;
    case CryptoCurrency.ltc:
      return WalletType.litecoin;
    case CryptoCurrency.xhv:
      return WalletType.haven;
    case CryptoCurrency.eth:
      return WalletType.ethereum;
    case CryptoCurrency.bch:
      return WalletType.bitcoinCash;
    case CryptoCurrency.nano:
      return WalletType.nano;
    case CryptoCurrency.banano:
      return WalletType.banano;
    case CryptoCurrency.maticpoly:
      return WalletType.polygon;
    case CryptoCurrency.sol:
      return WalletType.solana;
    case CryptoCurrency.trx:
      return WalletType.tron;
    case CryptoCurrency.wow:
      return WalletType.wownero;
    default:
      return null;
  }
}
