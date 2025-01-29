import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/core/validator.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/zano/zano.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';
const BEFORE_REGEX = '(^|\\s)';
const AFTER_REGEX = '(\$|\\s)';

class AddressValidator extends TextValidator {
  AddressValidator({required CryptoCurrency type})
      : super(
            errorMessage: S.current.error_text_address,
            useAdditionalValidation: type == CryptoCurrency.btc || type == CryptoCurrency.ltc
                ? (String txt) => BitcoinAddressUtils.validateAddress(
                      address: txt,
                      network: type == CryptoCurrency.btc
                          ? BitcoinNetwork.mainnet
                          : LitecoinNetwork.mainnet,
                    )
                : type == CryptoCurrency.zano 
                    ? zano?.validateAddress
                    : null,
            pattern: getPattern(type),
            length: getLength(type));

  static String getPattern(CryptoCurrency type) {
    var pattern = "";
    if (type is Erc20Token) {
      pattern = '0x[0-9a-zA-Z]+';
    }
    switch (type) {
      case CryptoCurrency.xmr:
        pattern = '4[0-9a-zA-Z]{94}|8[0-9a-zA-Z]{94}|[0-9a-zA-Z]{106}';
      case CryptoCurrency.ada:
        pattern = '[0-9a-zA-Z]{59}|[0-9a-zA-Z]{92}|[0-9a-zA-Z]{104}'
            '|[0-9a-zA-Z]{105}|addr1[0-9a-zA-Z]{98}';
      case CryptoCurrency.btc:
        pattern =
            '${P2pkhAddress.regex.pattern}|${P2shAddress.regex.pattern}|${RegExp(r'(bc|tb)1q[ac-hj-np-z02-9]{25,39}}').pattern}|${P2trAddress.regex.pattern}|${P2wshAddress.regex.pattern}|${SilentPaymentAddress.regex.pattern}';
      case CryptoCurrency.ltc:
        pattern = '^${RegExp(r'ltc1q[ac-hj-np-z02-9]{25,39}').pattern}\$|^${MwebAddress.regex.pattern}\$';
      case CryptoCurrency.nano:
        pattern = '[0-9a-zA-Z_]+';
      case CryptoCurrency.banano:
        pattern = '[0-9a-zA-Z_]+';
      case CryptoCurrency.usdc:
      case CryptoCurrency.usdcpoly:
      case CryptoCurrency.usdtPoly:
      case CryptoCurrency.usdcEPoly:
      case CryptoCurrency.ape:
      case CryptoCurrency.avaxc:
      case CryptoCurrency.eth:
      case CryptoCurrency.mana:
      case CryptoCurrency.matic:
      case CryptoCurrency.maticpoly:
      case CryptoCurrency.mkr:
      case CryptoCurrency.oxt:
      case CryptoCurrency.paxg:
      case CryptoCurrency.uni:
      case CryptoCurrency.aave:
      case CryptoCurrency.bat:
      case CryptoCurrency.comp:
      case CryptoCurrency.cro:
      case CryptoCurrency.ens:
      case CryptoCurrency.ftm:
      case CryptoCurrency.frax:
      case CryptoCurrency.gusd:
      case CryptoCurrency.gtc:
      case CryptoCurrency.grt:
      case CryptoCurrency.ldo:
      case CryptoCurrency.nexo:
      case CryptoCurrency.pepe:
      case CryptoCurrency.storj:
      case CryptoCurrency.tusd:
      case CryptoCurrency.wbtc:
      case CryptoCurrency.weth:
      case CryptoCurrency.zrx:
      case CryptoCurrency.dydx:
      case CryptoCurrency.steth:
      case CryptoCurrency.shib:
        pattern = '0x[0-9a-zA-Z]+';
      case CryptoCurrency.xrp:
        pattern = '[0-9a-zA-Z]{34}|[0-9a-zA-Z]{33}|X[0-9a-zA-Z]{46}';
      case CryptoCurrency.xhv:
        pattern = 'hvx|hvi|hvs[0-9a-zA-Z]+';
      case CryptoCurrency.xag:
      case CryptoCurrency.xau:
      case CryptoCurrency.xaud:
      case CryptoCurrency.xbtc:
      case CryptoCurrency.xcad:
      case CryptoCurrency.xchf:
      case CryptoCurrency.xcny:
      case CryptoCurrency.xeur:
      case CryptoCurrency.xgbp:
      case CryptoCurrency.xjpy:
      case CryptoCurrency.xnok:
      case CryptoCurrency.xnzd:
      case CryptoCurrency.xusd:
      case CryptoCurrency.usdt:
      case CryptoCurrency.usdterc20:
      case CryptoCurrency.xlm:
      case CryptoCurrency.trx:
      case CryptoCurrency.dai:
      case CryptoCurrency.dash:
      case CryptoCurrency.eos:
      case CryptoCurrency.wow:
        pattern = '[0-9a-zA-Z]+';
      case CryptoCurrency.bch:
        pattern = '(?:bitcoincash:)?(q|p)[0-9a-zA-Z]{41}'
            '|[13][a-km-zA-HJ-NP-Z1-9]{25,34}';
      case CryptoCurrency.hbar:
        pattern = '[0-9a-zA-Z.]+';
      case CryptoCurrency.zaddr:
        pattern = 'zs[0-9a-zA-Z]{75}';
      case CryptoCurrency.zec:
        pattern = 't1[0-9a-zA-Z]{33}|t3[0-9a-zA-Z]{33}';
      case CryptoCurrency.dcr:
        pattern = 'D[ksecS]([0-9a-zA-Z])+';
      case CryptoCurrency.rvn:
        pattern = '[Rr]([1-9a-km-zA-HJ-NP-Z]){33}';
      case CryptoCurrency.near:
        pattern = '[0-9a-f]{64}';
      case CryptoCurrency.rune:
        pattern = 'thor1[0-9a-z]{38}';
      case CryptoCurrency.scrt:
        pattern = 'secret1[0-9a-z]{38}';
      case CryptoCurrency.stx:
        pattern = 'S[MP][0-9a-zA-Z]+';
      case CryptoCurrency.kmd:
        pattern = 'R[0-9a-zA-Z]{33}';
      case CryptoCurrency.pivx:
        pattern = 'D([1-9a-km-zA-HJ-NP-Z]){33}';
      case CryptoCurrency.btcln:
        pattern = '(lnbc|LNBC)([0-9]{1,}[a-zA-Z0-9]+)';
      case CryptoCurrency.zano:
        pattern = r'([1-9A-HJ-NP-Za-km-z]{90,200})|(@[\w\d.-]+)';
      default:
        return '';
    }

    return '$BEFORE_REGEX($pattern)$AFTER_REGEX';
  }

  static List<int>? getLength(CryptoCurrency type) {
    if (type is Erc20Token) {
      return [42];
    }

    if (solana != null) {
      final length = solana!.getValidationLength(type);
      if (length != null) return length;
    }

    switch (type) {
      case CryptoCurrency.xmr:
      case CryptoCurrency.wow:
        return null;
      case CryptoCurrency.ada:
        return null;
      case CryptoCurrency.btc:
        return null;
      case CryptoCurrency.ltc:
        return null;
      case CryptoCurrency.dash:
        return [34];
      case CryptoCurrency.eos:
        return [42];
      case CryptoCurrency.eth:
      case CryptoCurrency.usdcpoly:
      case CryptoCurrency.usdtPoly:
      case CryptoCurrency.usdcEPoly:
      case CryptoCurrency.mana:
      case CryptoCurrency.matic:
      case CryptoCurrency.maticpoly:
      case CryptoCurrency.mkr:
      case CryptoCurrency.oxt:
      case CryptoCurrency.paxg:
      case CryptoCurrency.uni:
      case CryptoCurrency.dai:
      case CryptoCurrency.ape:
      case CryptoCurrency.usdc:
      case CryptoCurrency.usdterc20:
      case CryptoCurrency.aave:
      case CryptoCurrency.bat:
      case CryptoCurrency.comp:
      case CryptoCurrency.cro:
      case CryptoCurrency.ens:
      case CryptoCurrency.ftm:
      case CryptoCurrency.frax:
      case CryptoCurrency.gusd:
      case CryptoCurrency.gtc:
      case CryptoCurrency.grt:
      case CryptoCurrency.ldo:
      case CryptoCurrency.nexo:
      case CryptoCurrency.pepe:
      case CryptoCurrency.storj:
      case CryptoCurrency.tusd:
      case CryptoCurrency.wbtc:
      case CryptoCurrency.weth:
      case CryptoCurrency.zrx:
      case CryptoCurrency.dydx:
      case CryptoCurrency.steth:
      case CryptoCurrency.shib:
      case CryptoCurrency.avaxc:
        return [42];
      case CryptoCurrency.bch:
        return [42, 54, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35];
      case CryptoCurrency.bnb:
        return [42];
      case CryptoCurrency.nano:
        return [64, 65];
      case CryptoCurrency.banano:
        return [64, 65];
      case CryptoCurrency.sc:
        return [76];
      case CryptoCurrency.sol:
      case CryptoCurrency.usdtSol:
      case CryptoCurrency.usdcsol:
        return [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44];
      case CryptoCurrency.trx:
        return [34];
      case CryptoCurrency.usdt:
        return [34];
      case CryptoCurrency.usdttrc20:
        return [34];
      case CryptoCurrency.xlm:
        return [56];
      case CryptoCurrency.xrp:
        return null;
      case CryptoCurrency.xhv:
      case CryptoCurrency.xag:
      case CryptoCurrency.xau:
      case CryptoCurrency.xaud:
      case CryptoCurrency.xbtc:
      case CryptoCurrency.xcad:
      case CryptoCurrency.xchf:
      case CryptoCurrency.xcny:
      case CryptoCurrency.xeur:
      case CryptoCurrency.xgbp:
      case CryptoCurrency.xjpy:
      case CryptoCurrency.xnok:
      case CryptoCurrency.xnzd:
      case CryptoCurrency.xusd:
        return [98, 99, 106];
      case CryptoCurrency.btt:
      case CryptoCurrency.bttc:
      case CryptoCurrency.doge:
      case CryptoCurrency.firo:
        return [34];
      case CryptoCurrency.hbar:
        return [4, 5, 6, 7, 8, 9, 10, 11];
      case CryptoCurrency.xvg:
        return [34];
      case CryptoCurrency.zen:
        return [35];
      case CryptoCurrency.zaddr:
        return null;
      case CryptoCurrency.zec:
        return null;
      case CryptoCurrency.kmd:
      case CryptoCurrency.pivx:
      case CryptoCurrency.rvn:
        return [34];
      case CryptoCurrency.dcr:
        return [35];
      case CryptoCurrency.stx:
        return [40, 41, 42];
      case CryptoCurrency.rune:
        return [43];
      case CryptoCurrency.scrt:
        return [45];
      case CryptoCurrency.near:
        return [64];
      case CryptoCurrency.btcln:
      case CryptoCurrency.kaspa:
      case CryptoCurrency.zano:
      default:
        return null;
    }
  }

  static String? getAddressFromStringPattern(CryptoCurrency type) {
    String? pattern = null;

    switch (type) {
      case CryptoCurrency.xmr:
        pattern = '(4[0-9a-zA-Z]{94})'
            '|(8[0-9a-zA-Z]{94})'
            '|([0-9a-zA-Z]{106})';
      case CryptoCurrency.wow:
        pattern = '(W[0-9a-zA-Z]{94})'
            '|(W[0-9a-zA-Z]{94})'
            '|(W[0-9a-zA-Z]{96})'
            '|([0-9a-zA-Z]{106})';
      case CryptoCurrency.btc:
        pattern =
            '${P2pkhAddress.regex.pattern}|${P2shAddress.regex.pattern}|${P2wpkhAddress.regex.pattern}|${P2trAddress.regex.pattern}|${P2wshAddress.regex.pattern}|${SilentPaymentAddress.regex.pattern}';
      case CryptoCurrency.ltc:
        pattern = '([^0-9a-zA-Z]|^)^L[a-zA-Z0-9]{26,33}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)[LM][a-km-zA-HJ-NP-Z1-9]{26,33}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)ltc[a-zA-Z0-9]{26,45}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)((ltc|t)mweb1q[ac-hj-np-z02-9]{90,120})([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.eth:
      case CryptoCurrency.maticpoly:
        pattern = '0x[0-9a-zA-Z]+';
      case CryptoCurrency.nano:
        pattern = 'nano_[0-9a-zA-Z]{60}';
      case CryptoCurrency.banano:
        pattern = 'ban_[0-9a-zA-Z]{60}';
      case CryptoCurrency.bch:
        pattern = '(bitcoincash:)?q[0-9a-zA-Z]{41,42}';
      case CryptoCurrency.sol:
        pattern = '[1-9A-HJ-NP-Za-km-z]+';
      case CryptoCurrency.trx:
        pattern = '(T|t)[1-9A-HJ-NP-Za-km-z]{33}';
      case CryptoCurrency.zano:
        pattern = '([1-9A-HJ-NP-Za-km-z]{90,200})|(@[\w\d.-]+)';
      default:
        if (type.tag == CryptoCurrency.eth.title) {
          pattern = '0x[0-9a-zA-Z]{42}';
        }
        if (type.tag == CryptoCurrency.maticpoly.tag) {
          pattern = '0x[0-9a-zA-Z]{42}';
        }
        if (type.tag == CryptoCurrency.sol.title) {
          pattern = '[1-9A-HJ-NP-Za-km-z]{43,44}';
        }
        if (type.tag == CryptoCurrency.trx.title) {
          pattern = '(T|t)[1-9A-HJ-NP-Za-km-z]{33}';
        }
    }

    if (pattern != null) {
      return "$BEFORE_REGEX($pattern)$AFTER_REGEX";
    }

    return null;
  }
}
