import 'package:cw_core/currency.dart';
import 'package:cw_core/enumerable_item.dart';

class CryptoCurrency extends EnumerableItem<int> with Serializable<int> implements Currency {
  const CryptoCurrency({
    String title = '',
    int raw = -1,
    required this.name,
    this.fullName,
    this.iconPath,
    this.tag})
      : super(title: title, raw: raw);

  final String name;
  final String? tag;
  final String? fullName;
  final String? iconPath;

  static const all = [
    CryptoCurrency.xmr,
    CryptoCurrency.ada,
    CryptoCurrency.bch,
    CryptoCurrency.bnb,
    CryptoCurrency.btc,
    CryptoCurrency.dai,
    CryptoCurrency.dash,
    CryptoCurrency.eos,
    CryptoCurrency.eth,
    CryptoCurrency.ltc,
    CryptoCurrency.nano,
    CryptoCurrency.trx,
    CryptoCurrency.usdt,
    CryptoCurrency.usdterc20,
    CryptoCurrency.xlm,
    CryptoCurrency.xrp,
    CryptoCurrency.xhv,
    CryptoCurrency.ape,
    CryptoCurrency.avaxc,
    CryptoCurrency.btt,
    CryptoCurrency.bttc,
    CryptoCurrency.doge,
    CryptoCurrency.firo,
    CryptoCurrency.usdttrc20,
    CryptoCurrency.hbar,
    CryptoCurrency.sc,
    CryptoCurrency.sol,
    CryptoCurrency.usdc,
    CryptoCurrency.usdcsol,
    CryptoCurrency.zaddr,
    CryptoCurrency.zec,
    CryptoCurrency.zen,
    CryptoCurrency.xvg,
    CryptoCurrency.usdcpoly,
    CryptoCurrency.dcr,
    CryptoCurrency.kmd,
    CryptoCurrency.mana,
    CryptoCurrency.maticpoly,
    CryptoCurrency.matic,
    CryptoCurrency.mkr,
    CryptoCurrency.near,
    CryptoCurrency.oxt,
    CryptoCurrency.paxg,
    CryptoCurrency.pivx,
    CryptoCurrency.rune,
    CryptoCurrency.rvn,
    CryptoCurrency.scrt,
    CryptoCurrency.uni,
    CryptoCurrency.stx,
    CryptoCurrency.btcln,
    CryptoCurrency.shib,
    CryptoCurrency.aave,
    CryptoCurrency.arb,
    CryptoCurrency.bat,
    CryptoCurrency.comp,
    CryptoCurrency.cro,
    CryptoCurrency.ens,
    CryptoCurrency.ftm,
    CryptoCurrency.frax,
    CryptoCurrency.gusd,
    CryptoCurrency.gtc,
    CryptoCurrency.grt,
    CryptoCurrency.ldo,
    CryptoCurrency.nexo,
    CryptoCurrency.cake,
    CryptoCurrency.pepe,
    CryptoCurrency.storj,
    CryptoCurrency.tusd,
    CryptoCurrency.wbtc,
    CryptoCurrency.weth,
    CryptoCurrency.zrx,
    CryptoCurrency.dydx,
    CryptoCurrency.steth,
    CryptoCurrency.banano,
  ];

  static const havenCurrencies = [
    xag,
    xau,
    xaud,
    xbtc,
    xcad,
    xchf,
    xcny,
    xeur,
    xgbp,
    xjpy,
    xnok,
    xnzd,
    xusd,
  ];

  // title, tag (if applicable), fullName (if unique), raw, name, iconPath

  static const xmr = CryptoCurrency(title: 'XMR', fullName: 'Monero', raw: 0, name: 'xmr', iconPath: 'assets/images/crypto_assets/monero_icon.svg');
  static const ada = CryptoCurrency(title: 'ADA', fullName: 'Cardano', raw: 1, name: 'ada', iconPath: 'assets/images/crypto_assets/ada_icon.svg');
  static const bch = CryptoCurrency(title: 'BCH', fullName: 'Bitcoin Cash', raw: 2, name: 'bch', iconPath: 'assets/images/crypto_assets/bch_icon.svg');
  static const bnb = CryptoCurrency(title: 'BNB', tag: 'BSC', fullName: 'Binance Coin', raw: 3, name: 'bnb', iconPath: 'assets/images/crypto_assets/bnb_icon.svg');
  static const btc = CryptoCurrency(title: 'BTC', fullName: 'Bitcoin', raw: 4, name: 'btc', iconPath: 'assets/images/crypto_assets/btc_icon.svg');
  static const dai = CryptoCurrency(title: 'DAI', tag: 'ETH', fullName: 'Dai', raw: 5, name: 'dai', iconPath: 'assets/images/crypto_assets/dai_icon.svg');
  static const dash = CryptoCurrency(title: 'DASH', fullName: 'Dash', raw: 6, name: 'dash', iconPath: 'assets/images/crypto_assets/dash_icon.svg');
  static const eos = CryptoCurrency(title: 'EOS', fullName: 'EOS', raw: 7, name: 'eos', iconPath: 'assets/images/crypto_assets/eos_icon.svg');
  static const eth = CryptoCurrency(title: 'ETH', fullName: 'Ethereum', raw: 8, name: 'eth', iconPath: 'assets/images/crypto_assets/eth_icon.svg');
  static const ltc = CryptoCurrency(title: 'LTC', fullName: 'Litecoin', raw: 9, name: 'ltc', iconPath: 'assets/images/crypto_assets/ltc_icon.svg');
  static const nano = CryptoCurrency(title: 'NANO', raw: 10, name: 'nano', iconPath: 'assets/images/crypto_assets/xno_icon.svg');
  static const trx = CryptoCurrency(title: 'TRX', fullName: 'TRON', raw: 11, name: 'trx', iconPath: 'assets/images/crypto_assets/trx_icon.svg');
  static const usdt = CryptoCurrency(title: 'USDT', tag: 'OMNI', fullName: 'USDT Tether', raw: 12, name: 'usdt', iconPath: 'assets/images/crypto_assets/usdt_icon.svg');
  static const usdterc20 = CryptoCurrency(title: 'USDT', tag: 'ETH', fullName: 'USDT Tether', raw: 13, name: 'usdterc20', iconPath: 'assets/images/crypto_assets/usdterc20_icon.svg');
  static const xlm = CryptoCurrency(title: 'XLM', fullName: 'Stellar', raw: 14, name: 'xlm', iconPath: 'assets/images/crypto_assets/xlm_icon.svg');
  static const xrp = CryptoCurrency(title: 'XRP', fullName: 'Ripple', raw: 15, name: 'xrp', iconPath: 'assets/images/crypto_assets/xrp_icon.svg');
  static const xhv = CryptoCurrency(title: 'XHV', fullName: 'Haven Protocol', raw: 16, name: 'xhv', iconPath: 'assets/images/crypto_assets/xhv_icon.svg');

  static const xag = CryptoCurrency(title: 'XAG', tag: 'XHV',  raw: 17, name: 'xag');
  static const xau = CryptoCurrency(title: 'XAU', tag: 'XHV', raw: 18, name: 'xau');
  static const xaud = CryptoCurrency(title: 'XAUD', tag: 'XHV', raw: 19, name: 'xaud');
  static const xbtc = CryptoCurrency(title: 'XBTC', tag: 'XHV', raw: 20, name: 'xbtc');
  static const xcad = CryptoCurrency(title: 'XCAD', tag: 'XHV', raw: 21, name: 'xcad');
  static const xchf = CryptoCurrency(title: 'XCHF', tag: 'XHV', raw: 22, name: 'xchf');
  static const xcny = CryptoCurrency(title: 'XCNY', tag: 'XHV', raw: 23, name: 'xcny');
  static const xeur = CryptoCurrency(title: 'XEUR', tag: 'XHV', raw: 24, name: 'xeur');
  static const xgbp = CryptoCurrency(title: 'XGBP', tag: 'XHV', raw: 25, name: 'xgbp');
  static const xjpy = CryptoCurrency(title: 'XJPY', tag: 'XHV', raw: 26, name: 'xjpy');
  static const xnok = CryptoCurrency(title: 'XNOK', tag: 'XHV', raw: 27, name: 'xnok');
  static const xnzd = CryptoCurrency(title: 'XNZD', tag: 'XHV', raw: 28, name: 'xnzd');
  static const xusd = CryptoCurrency(title: 'XUSD', tag: 'XHV', raw: 29, name: 'xusd');

  static const ape = CryptoCurrency(title: 'APE', tag: 'ETH', fullName: 'ApeCoin', raw: 30, name: 'ape', iconPath: 'assets/images/crypto_assets/ape_icon.svg');
  static const avaxc = CryptoCurrency(title: 'AVAX', tag: 'AVAXC', raw: 31, name: 'avaxc', iconPath: 'assets/images/crypto_assets/avaxc_icon.svg');
  static const btt = CryptoCurrency(title: 'BTT', tag: 'ETH', fullName: 'BitTorrent', raw: 32, name: 'btt', iconPath: 'assets/images/crypto_assets/btt_icon.svg');
  static const bttc = CryptoCurrency(title: 'BTTC', tag: 'TRX', fullName: 'BitTorrent-NEW', raw: 33, name: 'bttc', iconPath: 'assets/images/crypto_assets/btt_icon.svg');
  static const doge = CryptoCurrency(title: 'DOGE', fullName: 'Dogecoin', raw: 34, name: 'doge', iconPath: 'assets/images/crypto_assets/doge_icon.svg');
  static const firo = CryptoCurrency(title: 'FIRO', raw: 35, name: 'firo', iconPath: 'assets/images/crypto_assets/firo_icon.svg');
  static const usdttrc20 = CryptoCurrency(title: 'USDT', tag: 'TRX', fullName: 'USDT Tether', raw: 36, name: 'usdttrc20', iconPath: 'assets/images/crypto_assets/usdttrc20_icon.svg');
  static const hbar = CryptoCurrency(title: 'HBAR', fullName: 'Hedera', raw: 37, name: 'hbar', iconPath: 'assets/images/crypto_assets/hbar_icon.svg', );
  static const sc = CryptoCurrency(title: 'SC', fullName: 'Siacoin', raw: 38, name: 'sc', iconPath: 'assets/images/crypto_assets/sc_icon.svg');
  static const sol = CryptoCurrency(title: 'SOL', fullName: 'Solana', raw: 39, name: 'sol', iconPath: 'assets/images/crypto_assets/sol_icon.svg');
  static const usdc = CryptoCurrency(title: 'USDC', tag: 'ETH', fullName: 'USD Coin', raw: 40, name: 'usdc', iconPath: 'assets/images/crypto_assets/usdc_icon.svg');
  static const usdcsol = CryptoCurrency(title: 'USDC', tag: 'SOL', fullName: 'USDC Coin', raw: 41, name: 'usdcsol', iconPath: 'assets/images/crypto_assets/usdc_icon.svg');
  static const zaddr = CryptoCurrency(title: 'ZZEC', tag: 'ZEC', fullName: 'Shielded Zcash', raw: 42, name: 'zaddr', iconPath: 'assets/images/crypto_assets/zec_icon.svg');
  static const zec = CryptoCurrency(title: 'TZEC', tag: 'ZEC', fullName: 'Transparent Zcash', raw: 43, name: 'zec', iconPath: 'assets/images/crypto_assets/zec_icon.svg');
  static const zen = CryptoCurrency(title: 'ZEN', fullName: 'Horizen', raw: 44, name: 'zen', iconPath: 'assets/images/crypto_assets/zen_icon.svg');
  static const xvg = CryptoCurrency(title: 'XVG', fullName: 'Verge', raw: 45, name: 'xvg', iconPath: 'assets/images/crypto_assets/xvg_icon.svg');

  static const usdcpoly = CryptoCurrency(title: 'USDC', tag: 'POLY', fullName: 'USD Coin', raw: 46, name: 'usdcpoly', iconPath: 'assets/images/crypto_assets/usdc_icon.svg');
  static const dcr = CryptoCurrency(title: 'DCR', fullName: 'Decred', raw: 47, name: 'dcr', iconPath: 'assets/images/crypto_assets/dcr_icon.svg');
  static const kmd = CryptoCurrency(title: 'KMD', fullName: 'Komodo', raw: 48, name: 'kmd', iconPath: 'assets/images/crypto_assets/kmd_icon.svg');
  static const mana = CryptoCurrency(title: 'MANA', tag: 'ETH', fullName: 'Decentraland', raw: 49, name: 'mana', iconPath: 'assets/images/crypto_assets/mana_icon.svg');
  static const maticpoly = CryptoCurrency(title: 'MATIC', tag: 'POLY', fullName: 'Polygon', raw: 50, name: 'maticpoly', iconPath: 'assets/images/crypto_assets/matic_icon.svg');
  static const matic = CryptoCurrency(title: 'MATIC', tag: 'ETH', fullName: 'Polygon', raw: 51, name: 'matic', iconPath: 'assets/images/crypto_assets/matic_icon.svg');
  static const mkr = CryptoCurrency(title: 'MKR', tag: 'ETH', fullName: 'Maker', raw: 52, name: 'mkr', iconPath: 'assets/images/crypto_assets/mkr_icon.svg');
  static const near = CryptoCurrency(title: 'NEAR', fullName: 'NEAR Protocol', raw: 53, name: 'near', iconPath: 'assets/images/crypto_assets/near_icon.svg');
  static const oxt = CryptoCurrency(title: 'OXT', tag: 'ETH', fullName: 'Orchid', raw: 54, name: 'oxt', iconPath: 'assets/images/crypto_assets/oxt_icon.svg');
  static const paxg = CryptoCurrency(title: 'PAXG', tag: 'ETH', fullName: 'Pax Gold', raw: 55, name: 'paxg', iconPath: 'assets/images/crypto_assets/paxg_icon.svg');
  static const pivx = CryptoCurrency(title: 'PIVX', raw: 56, name: 'pivx', iconPath: 'assets/images/crypto_assets/pivx_icon.svg');
  static const rune = CryptoCurrency(title: 'RUNE', fullName: 'Thorchain', raw: 57, name: 'rune', iconPath: 'assets/images/crypto_assets/rune_icon.svg');
  static const rvn = CryptoCurrency(title: 'RVN', fullName: 'Ravencoin', raw: 58, name: 'rvn', iconPath: 'assets/images/crypto_assets/rvn_icon.svg');
  static const scrt = CryptoCurrency(title: 'SCRT', fullName: 'Secret Network', raw: 59, name: 'scrt', iconPath: 'assets/images/crypto_assets/scrt_icon.svg');
  static const uni = CryptoCurrency(title: 'UNI', tag: 'ETH', fullName: 'Uniswap', raw: 60, name: 'uni', iconPath: 'assets/images/crypto_assets/uni_icon.svg');
  static const stx = CryptoCurrency(title: 'STX', fullName: 'Stacks', raw: 61, name: 'stx', iconPath: 'assets/images/crypto_assets/stx_icon.svg');
  static const btcln = CryptoCurrency(title: 'BTC', tag: 'LN', fullName: 'Bitcoin Lightning Network', raw: 62, name: 'btcln', iconPath: 'assets/images/crypto_assets/btc_icon.svg');
  static const shib = CryptoCurrency(title: 'SHIB', tag: 'ETH', fullName: 'Shiba Inu', raw: 63, name: 'shib', iconPath: 'assets/images/crypto_assets/shib_icon.svg');
  static const aave = CryptoCurrency(title: 'AAVE', tag: 'ETH', fullName: 'Aave', raw: 64, name: 'aave', iconPath: 'assets/images/crypto_assets/aave_icon.svg');
  static const arb = CryptoCurrency(title: 'ARB', fullName: 'Arbitrum', raw: 65, name: 'arb', iconPath: 'assets/images/crypto_assets/arb_icon.svg');
  static const bat = CryptoCurrency(title: 'BAT', tag: 'ETH', fullName: 'Basic Attention Token', raw: 66, name: 'bat', iconPath: 'assets/images/crypto_assets/bat_icon.svg');
  static const comp = CryptoCurrency(title: 'COMP', tag: 'ETH', fullName: 'Compound', raw: 67, name: 'comp', iconPath: 'assets/images/crypto_assets/comp_icon.svg');
  static const cro = CryptoCurrency(title: 'CRO', tag: 'ETH', fullName: 'Crypto.com Cronos', raw: 68, name: 'cro', iconPath: 'assets/images/crypto_assets/cro_icon.svg');
  static const ens = CryptoCurrency(title: 'ENS', tag: 'ETH', fullName: 'Ethereum Name Service', raw: 69, name: 'ens', iconPath: 'assets/images/crypto_assets/ens_icon.svg');
  static const ftm = CryptoCurrency(title: 'FTM', tag: 'ETH', fullName: 'Fantom', raw: 70, name: 'ftm', iconPath: 'assets/images/crypto_assets/ftm_icon.svg');
  static const frax = CryptoCurrency(title: 'FRAX', tag: 'ETH', fullName: 'Frax', raw: 71, name: 'frax', iconPath: 'assets/images/crypto_assets/frax_icon.svg');
  static const gusd = CryptoCurrency(title: 'GUSD', tag: 'ETH', fullName: 'Gemini USD', raw: 72, name: 'gusd', iconPath: 'assets/images/crypto_assets/gusd_icon.svg');
  static const gtc = CryptoCurrency(title: 'GTC', tag: 'ETH', fullName: 'Gitcoin', raw: 73, name: 'gtc', iconPath: 'assets/images/crypto_assets/gtc_icon.svg');
  static const grt = CryptoCurrency(title: 'GRT', tag: 'ETH', fullName: 'The Graph', raw: 74, name: 'grt', iconPath: 'assets/images/crypto_assets/grt_icon.svg');
  static const ldo = CryptoCurrency(title: 'LDO', tag: 'ETH', fullName: 'Lido DAO', raw: 75, name: 'ldo', iconPath: 'assets/images/crypto_assets/ldo_icon.svg');
  static const nexo = CryptoCurrency(title: 'NEXO', tag: 'ETH', fullName: 'Nexo', raw: 76, name: 'nexo', iconPath: 'assets/images/crypto_assets/nexo_icon.svg');
  static const cake = CryptoCurrency(title: 'CAKE', tag: 'BSC', fullName: 'PancakeSwap', raw: 77, name: 'cake', iconPath: 'assets/images/crypto_assets/cake_icon.svg');
  static const pepe = CryptoCurrency(title: 'PEPE', tag: 'ETH', fullName: 'Pepe', raw: 78, name: 'pepe', iconPath: 'assets/images/crypto_assets/pepe_icon.svg');
  static const storj = CryptoCurrency(title: 'STORJ', tag: 'ETH', fullName: 'Storj', raw: 79, name: 'storj', iconPath: 'assets/images/crypto_assets/storj_icon.svg');
  static const tusd = CryptoCurrency(title: 'TUSD', tag: 'ETH', fullName: 'TrueUSD', raw: 80, name: 'tusd', iconPath: 'assets/images/crypto_assets/tusd_icon.svg');
  static const wbtc = CryptoCurrency(title: 'WBTC', tag: 'ETH', fullName: 'Wrapped Bitcoin', raw: 81, name: 'wbtc', iconPath: 'assets/images/crypto_assets/wbtc_icon.svg');
  static const weth = CryptoCurrency(title: 'WETH', tag: 'ETH', fullName: 'Wrapped Ethereum', raw: 82, name: 'weth', iconPath: 'assets/images/crypto_assets/weth_icon.svg');
  static const zrx = CryptoCurrency(title: 'ZRX', tag: 'ETH', fullName: '0x Protocol', raw: 83, name: 'zrx', iconPath: 'assets/images/crypto_assets/zrx_icon.svg');
  static const dydx = CryptoCurrency(title: 'DYDX', tag: 'ETH', fullName: 'dYdX', raw: 84, name: 'dydx', iconPath: 'assets/images/crypto_assets/dydx_icon.svg');
  static const steth = CryptoCurrency(title: 'STETH', tag: 'ETH', fullName: 'Lido Staked Ethereum', raw: 85, name: 'steth', iconPath: 'assets/images/crypto_assets/steth_icon.svg');
  static const banano = CryptoCurrency(title: 'BAN', raw: 86, name: 'banano', iconPath: 'assets/images/crypto_assets/ban_icon.svg');

  static final Map<int, CryptoCurrency> _rawCurrencyMap =
    [...all, ...havenCurrencies].fold<Map<int, CryptoCurrency>>(<int, CryptoCurrency>{}, (acc, item) {
      acc.addAll({item.raw: item});
      return acc;
    });

  static final Map<String, CryptoCurrency> _nameCurrencyMap =
    [...all, ...havenCurrencies].fold<Map<String, CryptoCurrency>>(<String, CryptoCurrency>{}, (acc, item) {
      acc.addAll({item.name: item});
      return acc;
    });

  static final Map<String, CryptoCurrency> _fullNameCurrencyMap =
    [...all, ...havenCurrencies].fold<Map<String, CryptoCurrency>>(<String, CryptoCurrency>{}, (acc, item) {
      if(item.fullName != null){
        acc.addAll({item.fullName!.toLowerCase(): item});
      }
      return acc;
    });

  static CryptoCurrency deserialize({required int raw}) {

    if (CryptoCurrency._rawCurrencyMap[raw] == null) {
      final s = 'Unexpected token: $raw for CryptoCurrency deserialize';
      throw  ArgumentError.value(raw, 'raw', s);
    }
    return CryptoCurrency._rawCurrencyMap[raw]!;
  }

  static CryptoCurrency fromString(String name) {

    if (CryptoCurrency._nameCurrencyMap[name.toLowerCase()] == null) {
      final s = 'Unexpected token: $name for CryptoCurrency fromString';
      throw  ArgumentError.value(name, 'name', s);
    }
    return CryptoCurrency._nameCurrencyMap[name.toLowerCase()]!;
  }

  static CryptoCurrency fromFullName(String name) {

    if (CryptoCurrency._fullNameCurrencyMap[name.toLowerCase()] == null) {
      final s = 'Unexpected token: $name for CryptoCurrency fromFullName';
      throw  ArgumentError.value(name, 'Fullname', s);
    }
    return CryptoCurrency._fullNameCurrencyMap[name.toLowerCase()]!;
  }
  

  @override
  String toString() => title;
}
