import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/core/validator.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/erc20_token.dart';

class AddressValidator extends TextValidator {
  AddressValidator({required CryptoCurrency type})
      : super(
            errorMessage: S.current.error_text_address,
            useAdditionalValidation: type == CryptoCurrency.btc
                ? (String txt) => validateAddress(address: txt, network: BitcoinNetwork.mainnet)
                : null,
            pattern: getPattern(type),
            length: getLength(type));

  static String getPattern(CryptoCurrency type) {
    if (type is Erc20Token) {
      return '0x[0-9a-zA-Z]';
    }
    switch (type) {
      case CryptoCurrency.xmr:
        return '^4[0-9a-zA-Z]{94}\$|^8[0-9a-zA-Z]{94}\$|^[0-9a-zA-Z]{106}\$';
      case CryptoCurrency.ada:
        return '^[0-9a-zA-Z]{59}\$|^[0-9a-zA-Z]{92}\$|^[0-9a-zA-Z]{104}\$'
            '|^[0-9a-zA-Z]{105}\$|^addr1[0-9a-zA-Z]{98}\$';
      case CryptoCurrency.btc:
        return '^${P2pkhAddress.regex.pattern}\$|^${P2shAddress.regex.pattern}\$|^${P2wpkhAddress.regex.pattern}\$|${P2trAddress.regex.pattern}\$|^${P2wshAddress.regex.pattern}\$|^${SilentPaymentAddress.regex.pattern}\$';
      case CryptoCurrency.nano:
        return '[0-9a-zA-Z_]';
      case CryptoCurrency.banano:
        return '[0-9a-zA-Z_]';
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
        return '0x[0-9a-zA-Z]';
      case CryptoCurrency.xrp:
        return '^[0-9a-zA-Z]{34}\$|^X[0-9a-zA-Z]{46}\$';
      case CryptoCurrency.xhv:
        return '^hvx|hvi|hvs[0-9a-zA-Z]';
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
        return '[0-9a-zA-Z]';
      case CryptoCurrency.bch:
        return '^(?!bitcoincash:)[0-9a-zA-Z]*\$|^(?!bitcoincash:)q|p[0-9a-zA-Z]{41}\$|^(?!bitcoincash:)q|p[0-9a-zA-Z]{42}\$|^bitcoincash:q|p[0-9a-zA-Z]{41}\$|^bitcoincash:q|p[0-9a-zA-Z]{42}\$';
      case CryptoCurrency.bnb:
        return '[0-9a-zA-Z]';
      case CryptoCurrency.ltc:
        return '^(?!(ltc|LTC)1)[0-9a-zA-Z]*\$|(^LTC1[A-Z0-9]*\$)|(^ltc1[a-z0-9]*\$)';
      case CryptoCurrency.hbar:
        return '[0-9a-zA-Z.]';
      case CryptoCurrency.zaddr:
        return '^zs[0-9a-zA-Z]{75}';
      case CryptoCurrency.zec:
        return '^t1[0-9a-zA-Z]{33}\$|^t3[0-9a-zA-Z]{33}\$';
      case CryptoCurrency.dcr:
        return 'D[ksecS]([0-9a-zA-Z])+';
      case CryptoCurrency.rvn:
        return '[Rr]([1-9a-km-zA-HJ-NP-Z]){33}';
      case CryptoCurrency.near:
        return '[0-9a-f]{64}';
      case CryptoCurrency.rune:
        return 'thor1[0-9a-z]{38}';
      case CryptoCurrency.scrt:
        return 'secret1[0-9a-z]{38}';
      case CryptoCurrency.stx:
        return 'S[MP][0-9a-zA-Z]+';
      case CryptoCurrency.kmd:
        return 'R[0-9a-zA-Z]{33}';
      case CryptoCurrency.pivx:
        return 'D([1-9a-km-zA-HJ-NP-Z]){33}';
      case CryptoCurrency.btcln:
        return '^(lnbc|LNBC)([0-9]{1,}[a-zA-Z0-9]+)';
      default:
        return '[0-9a-zA-Z]';
    }
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
        return [42, 43, 44, 54, 55];
      case CryptoCurrency.bnb:
        return [42];
      case CryptoCurrency.ltc:
        return [34, 43, 63];
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
      default:
        return null;
    }
  }

  static String? getAddressFromStringPattern(CryptoCurrency type) {
    switch (type) {
      case CryptoCurrency.xmr:
      case CryptoCurrency.wow:
        return '([^0-9a-zA-Z]|^)4[0-9a-zA-Z]{94}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)8[0-9a-zA-Z]{94}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)[0-9a-zA-Z]{106}([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.btc:
        return '([^0-9a-zA-Z]|^)([1mn][a-km-zA-HJ-NP-Z1-9]{25,34})([^0-9a-zA-Z]|\$)' //P2pkhAddress type
            '|([^0-9a-zA-Z]|^)([23][a-km-zA-HJ-NP-Z1-9]{25,34})([^0-9a-zA-Z]|\$)' //P2shAddress type
            '|([^0-9a-zA-Z]|^)((bc|tb)1q[ac-hj-np-z02-9]{25,39})([^0-9a-zA-Z]|\$)' //P2wpkhAddress type
            '|([^0-9a-zA-Z]|^)((bc|tb)1q[ac-hj-np-z02-9]{40,80})([^0-9a-zA-Z]|\$)' //P2wshAddress type
            '|([^0-9a-zA-Z]|^)((bc|tb)1p([ac-hj-np-z02-9]{39}|[ac-hj-np-z02-9]{59}|[ac-hj-np-z02-9]{8,89}))([^0-9a-zA-Z]|\$)' //P2trAddress type
            '|${SilentPaymentAddress.regex.pattern}\$';
      case CryptoCurrency.btcln:
        return '(lnbc|LNBC)([0-9]{1,}[a-zA-Z0-9]+)([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.ltc:
        return '([^0-9a-zA-Z]|^)^L[a-zA-Z0-9]{26,33}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)[LM][a-km-zA-HJ-NP-Z1-9]{26,33}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)ltc[a-zA-Z0-9]{26,45}([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.eth:
        return '0x[0-9a-zA-Z]{42}';
      case CryptoCurrency.maticpoly:
        return '0x[0-9a-zA-Z]{42}';
      case CryptoCurrency.nano:
        return 'nano_[0-9a-zA-Z]{60}';
      case CryptoCurrency.banano:
        return 'ban_[0-9a-zA-Z]{60}';
      case CryptoCurrency.bch:
        return 'bitcoincash:q[0-9a-zA-Z]{41}([^0-9a-zA-Z]|\$)'
            '|bitcoincash:q[0-9a-zA-Z]{42}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)q[0-9a-zA-Z]{41}([^0-9a-zA-Z]|\$)'
            '|([^0-9a-zA-Z]|^)q[0-9a-zA-Z]{42}([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.sol:
        return '([^0-9a-zA-Z]|^)[1-9A-HJ-NP-Za-km-z]{43,44}([^0-9a-zA-Z]|\$)';
      case CryptoCurrency.trx:
        return '(T|t)[1-9A-HJ-NP-Za-km-z]{33}';
      default:
        if (type.tag == CryptoCurrency.eth.title) {
          return '0x[0-9a-zA-Z]{42}';
        }
        if (type.tag == CryptoCurrency.maticpoly.tag) {
          return '0x[0-9a-zA-Z]{42}';
        }
        if (type.tag == CryptoCurrency.sol.title) {
          return '([^0-9a-zA-Z]|^)[1-9A-HJ-NP-Za-km-z]{43,44}([^0-9a-zA-Z]|\$)';
        }
        if (type.tag == CryptoCurrency.trx.title) {
          return '(T|t)[1-9A-HJ-NP-Za-km-z]{33}';
        }

        return null;
    }
  }
}
