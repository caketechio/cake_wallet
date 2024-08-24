import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

part 'wallet_type.g.dart';

const walletTypes = [
  WalletType.monero,
  WalletType.bitcoin,
  WalletType.lightning,
  WalletType.litecoin,
  WalletType.haven,
  WalletType.ethereum,
  WalletType.bitcoinCash,
  WalletType.nano,
  WalletType.banano,
  WalletType.polygon,
  WalletType.solana,
  WalletType.tron,
];

@HiveType(typeId: WALLET_TYPE_TYPE_ID)
enum WalletType {
  @HiveField(0)
  monero,

  @HiveField(1)
  none,

  @HiveField(2)
  bitcoin,

  @HiveField(3)
  litecoin,

  @HiveField(4)
  haven,

  @HiveField(5)
  ethereum,

  @HiveField(6)
  nano,

  @HiveField(7)
  banano,

  @HiveField(8)
  bitcoinCash,

  @HiveField(9)
  polygon,

  @HiveField(10)
  solana,

  @HiveField(11)
  tron,

  @HiveField(12)
  wownero,

  @HiveField(13)
  lightning,
}

int serializeToInt(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 0;
    case WalletType.bitcoin:
      return 1;
    case WalletType.litecoin:
      return 2;
    case WalletType.haven:
      return 3;
    case WalletType.ethereum:
      return 4;
    case WalletType.nano:
      return 5;
    case WalletType.banano:
      return 6;
    case WalletType.bitcoinCash:
      return 7;
    case WalletType.polygon:
      return 8;
    case WalletType.solana:
      return 9;
    case WalletType.tron:
      return 10;
    case WalletType.wownero:
      return 11;
    case WalletType.lightning:
      return 12;
    case WalletType.none:
      return -1;
  }
}

WalletType deserializeFromInt(int raw) {
  switch (raw) {
    case 0:
      return WalletType.monero;
    case 1:
      return WalletType.bitcoin;
    case 2:
      return WalletType.litecoin;
    case 3:
      return WalletType.haven;
    case 4:
      return WalletType.ethereum;
    case 5:
      return WalletType.nano;
    case 6:
      return WalletType.banano;
    case 7:
      return WalletType.bitcoinCash;
    case 8:
      return WalletType.polygon;
    case 9:
      return WalletType.solana;
    case 10:
      return WalletType.tron;
    case 11:
      return WalletType.wownero;
    case 12:
      return WalletType.lightning;
    default:
      throw Exception('Unexpected token: $raw for WalletType deserializeFromInt');
  }
}

String walletTypeToString(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero';
    case WalletType.bitcoin:
      return 'Bitcoin';
    case WalletType.litecoin:
      return 'Litecoin';
    case WalletType.haven:
      return 'Haven';
    case WalletType.ethereum:
      return 'Ethereum';
    case WalletType.bitcoinCash:
      return 'Bitcoin Cash';
    case WalletType.nano:
      return 'Nano';
    case WalletType.banano:
      return 'Banano';
    case WalletType.polygon:
      return 'Polygon';
    case WalletType.lightning:
      return 'Lightning';
    case WalletType.solana:
      return 'Solana';
    case WalletType.tron:
      return 'Tron';
    case WalletType.wownero:
      return 'Wownero';
    case WalletType.none:
      return '';
  }
}

String walletTypeToDisplayName(WalletType type) {
  switch (type) {
    case WalletType.monero:
      return 'Monero (XMR)';
    case WalletType.bitcoin:
      return 'Bitcoin (BTC)';
    case WalletType.litecoin:
      return 'Litecoin (LTC)';
    case WalletType.haven:
      return 'Haven (XHV)';
    case WalletType.ethereum:
      return 'Ethereum (ETH)';
    case WalletType.bitcoinCash:
      return 'Bitcoin Cash (BCH)';
    case WalletType.nano:
      return 'Nano (XNO)';
    case WalletType.banano:
      return 'Banano (BAN)';
    case WalletType.polygon:
      return 'Polygon (MATIC)';
    case WalletType.lightning:
      return 'Bitcoin (Lightning)';
    case WalletType.solana:
      return 'Solana (SOL)';
    case WalletType.tron:
      return 'Tron (TRX)';
    case WalletType.wownero:
      return 'Wownero (WOW)';
    case WalletType.none:
      return '';
  }
}

CryptoCurrency walletTypeToCryptoCurrency(WalletType type, {bool isTestnet = false}) {
  switch (type) {
    case WalletType.monero:
      return CryptoCurrency.xmr;
    case WalletType.bitcoin:
      if (isTestnet) {
        return CryptoCurrency.tbtc;
      }
      return CryptoCurrency.btc;
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
    case WalletType.lightning:
      return CryptoCurrency.btcln;
    case WalletType.solana:
      return CryptoCurrency.sol;
    case WalletType.tron:
      return CryptoCurrency.trx;
    case WalletType.wownero:
      return CryptoCurrency.wow;
    case WalletType.none:
      throw Exception(
          'Unexpected wallet type: ${type.toString()} for CryptoCurrency walletTypeToCryptoCurrency');
  }
}
