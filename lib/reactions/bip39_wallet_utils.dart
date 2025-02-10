import 'package:cw_core/wallet_type.dart';

bool isBIP39Wallet(WalletType walletType) {
  switch (walletType) {
    case WalletType.ethereum:
    case WalletType.polygon:
    case WalletType.solana:
    case WalletType.tron:
    case WalletType.bitcoin:
    case WalletType.litecoin:
    case WalletType.bitcoinCash:
    case WalletType.nano:
    case WalletType.banano:
      return true;
    case WalletType.monero:
    case WalletType.wownero:
    case WalletType.haven:
    case WalletType.zano:
    case WalletType.decred:
    case WalletType.none:
      return false;
  }
}
