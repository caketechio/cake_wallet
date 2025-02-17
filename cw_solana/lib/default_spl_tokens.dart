import 'package:cw_core/crypto_currency.dart';
import 'package:cw_solana/spl_token.dart';

class DefaultSPLTokens {
  final List<SPLToken> _defaultTokens = [
    SPLToken(
      name: 'USDT Tether',
      symbol: 'USDT',
      mintAddress: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
      decimal: 6,
      mint: 'usdtsol',
      enabled: true,
    ),
    SPLToken(
      name: 'USD Coin',
      symbol: 'USDC',
      mintAddress: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      decimal: 6,
      mint: 'usdcsol',
      enabled: true,
    ),
    SPLToken(
      name: 'Bonk',
      symbol: 'Bonk',
      mintAddress: 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263',
      decimal: 5,
      mint: 'Bonk',
      iconPath: 'assets/images/bonk_icon.png',
      enabled: false,
    ),
    SPLToken(
      name: 'Raydium',
      symbol: 'RAY',
      mintAddress: '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R',
      decimal: 6,
      mint: 'ray',
      iconPath: 'assets/images/ray_icon.png',
      enabled: true,
    ),
    SPLToken(
      name: 'Wrapped Ethereum (Sollet)',
      symbol: 'soETH',
      mintAddress: '2FPyTwcZLUg1MDrwsyoP4D6s1tM7hAkHYRjkNb5w6Pxk',
      decimal: 6,
      mint: 'soEth',
      iconPath: 'assets/images/eth_icon.png',
      enabled: false,
    ),
    SPLToken(
      name: 'Wrapped SOL',
      symbol: 'WSOL',
      mintAddress: 'So11111111111111111111111111111111111111112',
      decimal: 9,
      mint: 'WSOL',
      iconPath: 'assets/images/sol_icon.png',
      enabled: false,
    ),
    SPLToken(
      name: 'Wrapped Bitcoin (Sollet)',
      symbol: 'BTC',
      mintAddress: '9n4nbM75f5Ui33ZbPYXn59EwSgE8CGsHtAeTH5YFeJ9E',
      decimal: 6,
      mint: 'btcsol',
      iconPath: 'assets/images/btc.png',
      enabled: false,
    ),
    SPLToken(
      name: 'Helium Network Token',
      symbol: 'HNT',
      mintAddress: 'hntyVP6YFm1Hg25TN9WGLqM12b8TQmcknKrdu1oxWux',
      decimal: 8,
      mint: 'hnt',
      iconPath: 'assets/images/hnt_icon.png',
      enabled: false,
    ),
    SPLToken(
      name: 'Pyth Network',
      symbol: 'PYTH',
      mintAddress: 'HZ1JovNiVvGrGNiiYvEozEVgZ58xaU3RKwX8eACQBCt3',
      decimal: 6,
      mint: 'pyth',
      enabled: false,
    ),
    SPLToken(
      name: 'GMT',
      symbol: 'GMT',
      mintAddress: '7i5KKsX2weiTkry7jA4ZwSuXGhs5eJBEjY8vVxR4pfRx',
      decimal: 6,
      mint: 'ray',
      iconPath: 'assets/images/gmt_icon.png',
      enabled: false,
    ),
    SPLToken(
      name: 'AvocadoCoin',
      symbol: 'AVDO',
      mintAddress: 'EE5L8cMU4itTsCSuor7NLK6RZx6JhsBe8GGV3oaAHm3P',
      decimal: 8,
      mint: 'avdo',
      iconPath: 'assets/images/avdo_icon.png',
      enabled: false,
    ),
  ];

  List<SPLToken> get initialSPLTokens => _defaultTokens.map((token) {
        String? iconPath;
        if (token.iconPath != null) return token;

        try {
          iconPath = CryptoCurrency.all
              .firstWhere((element) => element.title.toUpperCase() == token.symbol.toUpperCase())
              .iconPath;
        } catch (_) {}

        return SPLToken.copyWith(token, iconPath, 'SOL');
      }).toList();
}
