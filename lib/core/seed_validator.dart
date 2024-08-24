import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/validator.dart';
import 'package:cake_wallet/entities/mnemonic_item.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/nano/nano.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cake_wallet/utils/language_list.dart';
import 'package:cw_core/wallet_type.dart';

class SeedValidator extends Validator<MnemonicItem> {
  SeedValidator({required this.type, required this.language})
      : _words = getWordList(type: type, language: language),
        super(errorMessage: 'Wrong seed mnemonic');

  final WalletType type;
  final String language;
  final List<String> _words;

  static List<String> getWordList({required WalletType type, required String language}) {
    switch (type) {
      case WalletType.bitcoin:
      case WalletType.lightning:
      case WalletType.litecoin:
        return getBitcoinWordList(language);
      case WalletType.monero:
        return monero!.getMoneroWordList(language);
      case WalletType.haven:
        return haven!.getMoneroWordList(language);
      case WalletType.ethereum:
        return ethereum!.getEthereumWordList(language);
      case WalletType.bitcoinCash:
        return getBitcoinWordList(language);
      case WalletType.nano:
      case WalletType.banano:
        return nano!.getNanoWordList(language);
      case WalletType.polygon:
        return polygon!.getPolygonWordList(language);
      case WalletType.solana:
        return solana!.getSolanaWordList(language);
      case WalletType.tron:
        return tron!.getTronWordList(language);
      case WalletType.wownero:
          return wownero!.getWowneroWordList(language);
      case WalletType.none:
        return [];
    }
  }

  static bool needsNormalization(String language) =>
      ["POLYSEED_French", "POLYSEED_Spanish"].contains(language);

  static List<String> getBitcoinWordList(String language) {
    assert(language.toLowerCase() == LanguageList.english.toLowerCase());
    return bitcoin!.getWordList();
  }

  @override
  bool isValid(MnemonicItem? value) => _words.contains(value?.text);
}
