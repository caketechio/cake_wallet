import 'package:cw_core/enumerable_item.dart';

class ExchangeProviderDescription extends EnumerableItem<int> with Serializable<int> {
  const ExchangeProviderDescription(
      {required String title, required int raw, required this.image, this.horizontalLogo = false})
      : super(title: title, raw: raw);

  final bool horizontalLogo;
  final String image;

  static const xmrto =
      ExchangeProviderDescription(title: 'XMR.TO', raw: 0, image: 'assets/images/xmrto.png');
  static const changeNow =
      ExchangeProviderDescription(title: 'ChangeNOW', raw: 1, image: 'assets/images/changenow.png');
  static const morphToken =
      ExchangeProviderDescription(title: 'MorphToken', raw: 2, image: 'assets/images/morph.png');
  static const sideShift =
      ExchangeProviderDescription(title: 'SideShift', raw: 3, image: 'assets/images/sideshift.png');
  static const simpleSwap = 
      ExchangeProviderDescription(title: 'SimpleSwap', raw: 4, image: 'assets/images/simpleSwap.png');
  static const trocador =
      ExchangeProviderDescription(title: 'Trocador', raw: 5, image: 'assets/images/trocador.png');
  static const exolix =
      ExchangeProviderDescription(title: 'Exolix', raw: 6, image: 'assets/images/exolix.png');
  static const all = 
      ExchangeProviderDescription(title: 'All trades', raw: 7, image: '');
  static const thorChain =
      ExchangeProviderDescription(title: 'ThorChain', raw: 8, image: 'assets/images/thorchain.png');
  static const quantex =
      ExchangeProviderDescription(title: 'Quantex', raw: 9, image: 'assets/images/quantex.png');
  static const letsExchange =
      ExchangeProviderDescription(title: 'LetsExchange', raw: 10, image: 'assets/images/letsexchange_icon.svg');
  static const stealthEx =
      ExchangeProviderDescription(title: 'StealthEx', raw: 11, image: 'assets/images/stealthex.png');
  static const chainflip =
      ExchangeProviderDescription(title: 'Chainflip', raw: 12, image: 'assets/images/chainflip.png');
  
  static ExchangeProviderDescription deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return xmrto;
      case 1:
        return changeNow;
      case 2:
        return morphToken;
      case 3:
        return sideShift;
      case 4:
        return simpleSwap;
      case 5:
        return trocador;
      case 6:
        return exolix;
      case 7:
        return all;
      case 8:
        return thorChain;
      case 9:
        return quantex;
      case 10:
        return letsExchange;
      case 11:
        return stealthEx;
      case 12:
        return chainflip;
      default:
        throw Exception('Unexpected token: $raw for ExchangeProviderDescription deserialize');
    }
  }
}
