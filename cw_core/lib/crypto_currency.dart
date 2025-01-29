import 'package:cw_core/currency.dart';
import 'package:cw_core/enumerable_item.dart';

class CryptoCurrency extends EnumerableItem<int> with Serializable<int> implements Currency {
  const CryptoCurrency({
    String title = '',
    int raw = -1,
    required this.name,
    required this.decimals,
    this.fullName,
    this.iconPath,
    this.tag,
    this.enabled = false,
    })
      : super(title: title, raw: raw);

  final String name;
  final String? tag;
  final String? fullName;
  final String? iconPath;
  final int decimals;
  final bool enabled;

  set enabled(bool value) => this.enabled = value;

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
    CryptoCurrency.sol,
    CryptoCurrency.maticpoly,
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
    CryptoCurrency.usdtPoly,
    CryptoCurrency.usdcEPoly,
    CryptoCurrency.kaspa,
    CryptoCurrency.digibyte,
    CryptoCurrency.usdtSol,
    CryptoCurrency.usdcTrc20,
    CryptoCurrency.tbtc,
    CryptoCurrency.wow,
    CryptoCurrency.zano,
    CryptoCurrency.ton,
    CryptoCurrency.flip
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
  static const xmr = CryptoCurrency(title: 'XMR', fullName: 'Monero', raw: 0, name: 'xmr', iconPath: 'assets/images/monero_icon.png', decimals: 12);
  static const ada = CryptoCurrency(title: 'ADA', fullName: 'Cardano', raw: 1, name: 'ada', iconPath: 'assets/images/ada_icon.png', decimals: 6);
  static const bch = CryptoCurrency(title: 'BCH', fullName: 'Bitcoin Cash', raw: 2, name: 'bch', iconPath: 'assets/images/bch_icon.png', decimals: 8);
  static const bnb = CryptoCurrency(title: 'BNB', tag: 'BSC', fullName: 'Binance Coin', raw: 3, name: 'bnb', iconPath: 'assets/images/bnb_icon.png', decimals: 8);
  static const btc = CryptoCurrency(title: 'BTC', fullName: 'Bitcoin', raw: 4, name: 'btc', iconPath: 'assets/images/btc.png', decimals: 8);
  static const dai = CryptoCurrency(title: 'DAI', tag: 'ETH', fullName: 'Dai', raw: 5, name: 'dai', iconPath: 'assets/images/dai_icon.png', decimals: 18);
  static const dash = CryptoCurrency(title: 'DASH', fullName: 'Dash', raw: 6, name: 'dash', iconPath: 'assets/images/dash_icon.png', decimals: 8);
  static const eos = CryptoCurrency(title: 'EOS', fullName: 'EOS', raw: 7, name: 'eos', iconPath: 'assets/images/eos_icon.png', decimals: 4);
  static const eth = CryptoCurrency(title: 'ETH', fullName: 'Ethereum', raw: 8, name: 'eth', iconPath: 'assets/images/eth_icon.png', decimals: 18);
  static const ltc = CryptoCurrency(title: 'LTC', fullName: 'Litecoin', raw: 9, name: 'ltc', iconPath: 'assets/images/litecoin-ltc_icon.png', decimals: 8);
  static const nano = CryptoCurrency(title: 'XNO', fullName: 'Nano', raw: 10, name: 'xno', iconPath: 'assets/images/nano_icon.png', decimals: 30);
  static const trx = CryptoCurrency(title: 'TRX', fullName: 'TRON', raw: 11, name: 'trx', iconPath: 'assets/images/trx_icon.png', decimals: 6);
  static const usdt = CryptoCurrency(title: 'USDT', tag: 'OMNI', fullName: 'USDT Tether', raw: 12, name: 'usdt', iconPath: 'assets/images/usdt_icon.png', decimals: 6);
  static const usdterc20 = CryptoCurrency(title: 'USDT', tag: 'ETH', fullName: 'USDT Tether', raw: 13, name: 'usdterc20', iconPath: 'assets/images/usdterc20_icon.png', decimals: 6);
  static const xlm = CryptoCurrency(title: 'XLM', fullName: 'Stellar', raw: 14, name: 'xlm', iconPath: 'assets/images/xlm_icon.png', decimals: 7);
  static const xrp = CryptoCurrency(title: 'XRP', fullName: 'Ripple', raw: 15, name: 'xrp', iconPath: 'assets/images/xrp_icon.png', decimals: 6);
  static const xhv = CryptoCurrency(title: 'XHV', fullName: 'Haven Protocol', raw: 16, name: 'xhv', iconPath: 'assets/images/xhv_logo.png', decimals: 12);

  static const xag = CryptoCurrency(title: 'XAG', tag: 'XHV',  raw: 17, name: 'xag', decimals: 12);
  static const xau = CryptoCurrency(title: 'XAU', tag: 'XHV', raw: 18, name: 'xau', decimals: 12);
  static const xaud = CryptoCurrency(title: 'XAUD', tag: 'XHV', raw: 19, name: 'xaud', decimals: 12);
  static const xbtc = CryptoCurrency(title: 'XBTC', tag: 'XHV', raw: 20, name: 'xbtc', decimals: 12);
  static const xcad = CryptoCurrency(title: 'XCAD', tag: 'XHV', raw: 21, name: 'xcad', decimals: 12);
  static const xchf = CryptoCurrency(title: 'XCHF', tag: 'XHV', raw: 22, name: 'xchf', decimals: 12);
  static const xcny = CryptoCurrency(title: 'XCNY', tag: 'XHV', raw: 23, name: 'xcny', decimals: 12);
  static const xeur = CryptoCurrency(title: 'XEUR', tag: 'XHV', raw: 24, name: 'xeur', decimals: 12);
  static const xgbp = CryptoCurrency(title: 'XGBP', tag: 'XHV', raw: 25, name: 'xgbp', decimals: 12);
  static const xjpy = CryptoCurrency(title: 'XJPY', tag: 'XHV', raw: 26, name: 'xjpy', decimals: 12);
  static const xnok = CryptoCurrency(title: 'XNOK', tag: 'XHV', raw: 27, name: 'xnok', decimals: 12);
  static const xnzd = CryptoCurrency(title: 'XNZD', tag: 'XHV', raw: 28, name: 'xnzd', decimals: 12);
  static const xusd = CryptoCurrency(title: 'XUSD', tag: 'XHV', raw: 29, name: 'xusd', decimals: 12);

  static const ape = CryptoCurrency(title: 'APE', tag: 'ETH', fullName: 'ApeCoin', raw: 30, name: 'ape', iconPath: 'assets/images/ape_icon.png', decimals: 18);
  static const avaxc = CryptoCurrency(title: 'AVAX', tag: 'AVAXC', fullName: 'Avalanche', raw: 31, name: 'avaxc', iconPath: 'assets/images/avaxc_icon.png', decimals: 9);
  static const btt = CryptoCurrency(title: 'BTT', tag: 'ETH', fullName: 'BitTorrent', raw: 32, name: 'btt', iconPath: 'assets/images/btt_icon.png', decimals: 18);
  static const bttc = CryptoCurrency(title: 'BTTC', tag: 'TRX', fullName: 'BitTorrent-NEW', raw: 33, name: 'bttc', iconPath: 'assets/images/btt_icon.png', decimals: 18);
  static const doge = CryptoCurrency(title: 'DOGE', fullName: 'Dogecoin', raw: 34, name: 'doge', iconPath: 'assets/images/doge_icon.png', decimals: 8);
  static const firo = CryptoCurrency(title: 'FIRO', raw: 35, name: 'firo', iconPath: 'assets/images/firo_icon.png', decimals: 8);
  static const usdttrc20 = CryptoCurrency(title: 'USDT', tag: 'TRX', fullName: 'USDT Tether', raw: 36, name: 'usdttrc20', iconPath: 'assets/images/usdttrc20_icon.png', decimals: 6);
  static const hbar = CryptoCurrency(title: 'HBAR', fullName: 'Hedera', raw: 37, name: 'hbar', iconPath: 'assets/images/hbar_icon.png', decimals: 8);
  static const sc = CryptoCurrency(title: 'SC', fullName: 'Siacoin', raw: 38, name: 'sc', iconPath: 'assets/images/sc_icon.png', decimals: 16);
  static const sol = CryptoCurrency(title: 'SOL', fullName: 'Solana', raw: 39, name: 'sol', iconPath: 'assets/images/sol_icon.png', decimals: 9);
  static const usdc = CryptoCurrency(title: 'USDC', tag: 'ETH', fullName: 'USD Coin', raw: 40, name: 'usdc', iconPath: 'assets/images/usdc_icon.png', decimals: 6);
  static const usdcsol = CryptoCurrency(title: 'USDC', tag: 'SOL', fullName: 'USDC Coin', raw: 41, name: 'usdcsol', iconPath: 'assets/images/usdc_icon.png', decimals: 6);
  static const zaddr = CryptoCurrency(title: 'ZZEC', tag: 'ZEC', fullName: 'Shielded Zcash', raw: 42, name: 'zaddr', iconPath: 'assets/images/zec_icon.png', decimals: 8);
  static const zec = CryptoCurrency(title: 'TZEC', tag: 'ZEC', fullName: 'Transparent Zcash', raw: 43, name: 'zec', iconPath: 'assets/images/zec_icon.png', decimals: 8);
  static const zen = CryptoCurrency(title: 'ZEN', fullName: 'Horizen', raw: 44, name: 'zen', iconPath: 'assets/images/zen_icon.png', decimals: 8);
  static const xvg = CryptoCurrency(title: 'XVG', fullName: 'Verge', raw: 45, name: 'xvg', iconPath: 'assets/images/xvg_icon.png', decimals: 8);

  static const usdcpoly = CryptoCurrency(title: 'USDC', tag: 'POL', fullName: 'USD Coin', raw: 46, name: 'usdcpoly', iconPath: 'assets/images/usdc_icon.png', decimals: 6);
  static const dcr = CryptoCurrency(title: 'DCR', fullName: 'Decred', raw: 47, name: 'dcr', iconPath: 'assets/images/dcr_icon.png', decimals: 8);
  static const kmd = CryptoCurrency(title: 'KMD', fullName: 'Komodo', raw: 48, name: 'kmd', iconPath: 'assets/images/kmd_icon.png', decimals: 8);
  static const mana = CryptoCurrency(title: 'MANA', tag: 'ETH', fullName: 'Decentraland', raw: 49, name: 'mana', iconPath: 'assets/images/mana_icon.png', decimals: 18);
  static const maticpoly = CryptoCurrency(title: 'POL', tag: 'POL', fullName: 'Polygon', raw: 50, name: 'maticpoly', iconPath: 'assets/images/matic_icon.png', decimals: 18);
  static const matic = CryptoCurrency(title: 'MATIC', tag: 'ETH', fullName: 'Polygon', raw: 51, name: 'matic', iconPath: 'assets/images/matic_icon.png', decimals: 18);
  static const mkr = CryptoCurrency(title: 'MKR', tag: 'ETH', fullName: 'Maker', raw: 52, name: 'mkr', iconPath: 'assets/images/mkr_icon.png', decimals: 18);
  static const near = CryptoCurrency(title: 'NEAR', fullName: 'NEAR Protocol', raw: 53, name: 'near', iconPath: 'assets/images/near_icon.png', decimals: 24);
  static const oxt = CryptoCurrency(title: 'OXT', tag: 'ETH', fullName: 'Orchid', raw: 54, name: 'oxt', iconPath: 'assets/images/oxt_icon.png', decimals: 18);
  static const paxg = CryptoCurrency(title: 'PAXG', tag: 'ETH', fullName: 'Pax Gold', raw: 55, name: 'paxg', iconPath: 'assets/images/paxg_icon.png', decimals: 18);
  static const pivx = CryptoCurrency(title: 'PIVX', raw: 56, name: 'pivx', iconPath: 'assets/images/pivx_icon.png', decimals: 8);
  static const rune = CryptoCurrency(title: 'RUNE', fullName: 'Thorchain', raw: 57, name: 'rune', iconPath: 'assets/images/rune_icon.png', decimals: 18);
  static const rvn = CryptoCurrency(title: 'RVN', fullName: 'Ravencoin', raw: 58, name: 'rvn', iconPath: 'assets/images/rvn_icon.png', decimals: 8);
  static const scrt = CryptoCurrency(title: 'SCRT', fullName: 'Secret Network', raw: 59, name: 'scrt', iconPath: 'assets/images/scrt_icon.png', decimals: 6);
  static const uni = CryptoCurrency(title: 'UNI', tag: 'ETH', fullName: 'Uniswap', raw: 60, name: 'uni', iconPath: 'assets/images/uni_icon.png', decimals: 18);
  static const stx = CryptoCurrency(title: 'STX', fullName: 'Stacks', raw: 61, name: 'stx', iconPath: 'assets/images/stx_icon.png', decimals: 8);
  static const btcln = CryptoCurrency(title: 'BTC', tag: 'LN', fullName: 'Bitcoin Lightning Network', raw: 62, name: 'btcln', iconPath: 'assets/images/btc.png', decimals: 8);
  static const shib = CryptoCurrency(title: 'SHIB', tag: 'ETH', fullName: 'Shiba Inu', raw: 63, name: 'shib', iconPath: 'assets/images/shib_icon.png', decimals: 18);
  static const aave = CryptoCurrency(title: 'AAVE', tag: 'ETH', fullName: 'Aave', raw: 64, name: 'aave', iconPath: 'assets/images/aave_icon.png', decimals: 18);
  static const arb = CryptoCurrency(title: 'ARB', fullName: 'Arbitrum', raw: 65, name: 'arb', iconPath: 'assets/images/arb_icon.png', decimals: 18);
  static const bat = CryptoCurrency(title: 'BAT', tag: 'ETH', fullName: 'Basic Attention Token', raw: 66, name: 'bat', iconPath: 'assets/images/bat_icon.png', decimals: 18);
  static const comp = CryptoCurrency(title: 'COMP', tag: 'ETH', fullName: 'Compound', raw: 67, name: 'comp', iconPath: 'assets/images/comp_icon.png', decimals: 18);
  static const cro = CryptoCurrency(title: 'CRO', tag: 'ETH', fullName: 'Crypto.com Cronos', raw: 68, name: 'cro', iconPath: 'assets/images/cro_icon.png', decimals: 8);
  static const ens = CryptoCurrency(title: 'ENS', tag: 'ETH', fullName: 'Ethereum Name Service', raw: 69, name: 'ens', iconPath: 'assets/images/ens_icon.png', decimals: 18);
  static const ftm = CryptoCurrency(title: 'FTM', tag: 'ETH', fullName: 'Fantom', raw: 70, name: 'ftm', iconPath: 'assets/images/ftm_icon.png', decimals: 18);
  static const frax = CryptoCurrency(title: 'FRAX', tag: 'ETH', fullName: 'Frax', raw: 71, name: 'frax', iconPath: 'assets/images/frax_icon.png', decimals: 18);
  static const gusd = CryptoCurrency(title: 'GUSD', tag: 'ETH', fullName: 'Gemini USD', raw: 72, name: 'gusd', iconPath: 'assets/images/gusd_icon.png', decimals: 2);
  static const gtc = CryptoCurrency(title: 'GTC', tag: 'ETH', fullName: 'Gitcoin', raw: 73, name: 'gtc', iconPath: 'assets/images/gtc_icon.png', decimals: 18);
  static const grt = CryptoCurrency(title: 'GRT', tag: 'ETH', fullName: 'The Graph', raw: 74, name: 'grt', iconPath: 'assets/images/grt_icon.png', decimals: 18);
  static const ldo = CryptoCurrency(title: 'LDO', tag: 'ETH', fullName: 'Lido DAO', raw: 75, name: 'ldo', iconPath: 'assets/images/ldo_icon.png', decimals: 18);
  static const nexo = CryptoCurrency(title: 'NEXO', tag: 'ETH', fullName: 'Nexo', raw: 76, name: 'nexo', iconPath: 'assets/images/nexo_icon.png', decimals: 18);
  static const cake = CryptoCurrency(title: 'CAKE', tag: 'BSC', fullName: 'PancakeSwap', raw: 77, name: 'cake', iconPath: 'assets/images/cake_icon.png', decimals: 18);
  static const pepe = CryptoCurrency(title: 'PEPE', tag: 'ETH', fullName: 'Pepe', raw: 78, name: 'pepe', iconPath: 'assets/images/pepe_icon.png', decimals: 18);
  static const storj = CryptoCurrency(title: 'STORJ', tag: 'ETH', fullName: 'Storj', raw: 79, name: 'storj', iconPath: 'assets/images/storj_icon.png', decimals: 8);
  static const tusd = CryptoCurrency(title: 'TUSD', tag: 'ETH', fullName: 'TrueUSD', raw: 80, name: 'tusd', iconPath: 'assets/images/tusd_icon.png', decimals: 18);
  static const wbtc = CryptoCurrency(title: 'WBTC', tag: 'ETH', fullName: 'Wrapped Bitcoin', raw: 81, name: 'wbtc', iconPath: 'assets/images/wbtc_icon.png', decimals: 8);
  static const weth = CryptoCurrency(title: 'WETH', tag: 'ETH', fullName: 'Wrapped Ethereum', raw: 82, name: 'weth', iconPath: 'assets/images/weth_icon.png', decimals: 18);
  static const zrx = CryptoCurrency(title: 'ZRX', tag: 'ETH', fullName: '0x Protocol', raw: 83, name: 'zrx', iconPath: 'assets/images/zrx_icon.png', decimals: 18);
  static const dydx = CryptoCurrency(title: 'DYDX', tag: 'ETH', fullName: 'dYdX', raw: 84, name: 'dydx', iconPath: 'assets/images/dydx_icon.png', decimals: 18);
  static const steth = CryptoCurrency(title: 'STETH', tag: 'ETH', fullName: 'Lido Staked Ethereum', raw: 85, name: 'steth', iconPath: 'assets/images/steth_icon.png', decimals: 18);
  static const banano = CryptoCurrency(title: 'BAN', fullName: 'Banano', raw: 86, name: 'banano', iconPath: 'assets/images/nano_icon.png', decimals: 29);
  static const usdtPoly = CryptoCurrency(title: 'USDT', tag: 'POL', fullName: 'Tether USD (PoS)', raw: 87, name: 'usdtpoly', iconPath: 'assets/images/usdt_icon.png', decimals: 6);
  static const usdcEPoly = CryptoCurrency(title: 'USDC.E', tag: 'POL', fullName: 'USD Coin (PoS)', raw: 88, name: 'usdcepoly', iconPath: 'assets/images/usdc_icon.png', decimals: 6);
  static const kaspa = CryptoCurrency(title: 'KAS', fullName: 'Kaspa', raw: 89, name: 'kas', iconPath: 'assets/images/kaspa_icon.png', decimals: 8);
  static const digibyte = CryptoCurrency(title: 'DGB', fullName: 'DigiByte', raw: 90, name: 'dgb', iconPath: 'assets/images/digibyte.png', decimals: 8);
  static const usdtSol = CryptoCurrency(title: 'USDT', tag: 'SOL', fullName: 'USDT Tether', raw: 91, name: 'usdtsol', iconPath: 'assets/images/usdt_icon.png', decimals: 6);
  static const usdcTrc20 = CryptoCurrency(title: 'USDC', tag: 'TRX', fullName: 'USDC Coin', raw: 92, name: 'usdctrc20', iconPath: 'assets/images/usdc_icon.png', decimals: 6);
  static const tbtc = CryptoCurrency(title: 'tBTC', fullName: 'Testnet Bitcoin', raw: 93, name: 'tbtc', iconPath: 'assets/images/tbtc.png', decimals: 8);
  static const wow = CryptoCurrency(title: 'WOW', fullName: 'Wownero', raw: 94, name: 'wow', iconPath: 'assets/images/wownero_icon.png', decimals: 11);
  static const ton = CryptoCurrency(title: 'TON', fullName: 'Toncoin', raw: 95, name: 'ton', iconPath: 'assets/images/ton_icon.png', decimals: 8);
  static const zano = CryptoCurrency(title: 'ZANO', tag: 'ZANO', fullName: 'Zano', raw: 96, name: 'zano', iconPath: 'assets/images/zano_icon.png', decimals: 12);
  static const flip = CryptoCurrency(title: 'FLIP', tag: 'ETH', fullName: 'Chainflip', raw: 97, name: 'flip', iconPath: 'assets/images/flip_icon.png', decimals: 18);

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

  // TODO: refactor this
  static CryptoCurrency fromString(String name, {CryptoCurrency? walletCurrency}) {
    try {
      return CryptoCurrency.all.firstWhere((element) =>
          element.title.toLowerCase() == name.toLowerCase() &&
          (element.tag == null ||
              element.tag == walletCurrency?.title ||
              element.tag == walletCurrency?.tag));
    } catch (_) {}

    // search by fullName if not found by title:
    try {
      return CryptoCurrency.all.firstWhere((element) => element.fullName?.toLowerCase() == name);
    } catch (_) {}

    if (CryptoCurrency._nameCurrencyMap[name.toLowerCase()] == null) {
      final s = 'Unexpected token: $name for CryptoCurrency fromString';
      throw  ArgumentError.value(name, 'name', s);
    }

    return CryptoCurrency._nameCurrencyMap[name.toLowerCase()]!;
  }

  static CryptoCurrency fromFullName(String name) {
    if (CryptoCurrency._fullNameCurrencyMap[name.split("(").first.trim().toLowerCase()] == null) {
      final s = 'Unexpected token: $name for CryptoCurrency fromFullName';
      throw  ArgumentError.value(name, 'Fullname', s);
    }
    return CryptoCurrency._fullNameCurrencyMap[name.split("(").first.trim().toLowerCase()]!;
  }

  @override
  String toString() => title;
}
