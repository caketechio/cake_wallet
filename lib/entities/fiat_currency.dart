import 'package:cw_core/currency.dart';
import 'package:cw_core/enumerable_item.dart';

class FiatCurrency extends EnumerableItem<String> with Serializable<String> implements Currency {
  const FiatCurrency({required String symbol, required this.countryCode, required this.fullName}) : super(title: symbol, raw: symbol);

  final String countryCode;
  final String fullName;

  static List<FiatCurrency> get all => _all.values.toList();

  static List<FiatCurrency> get currenciesAvailableToBuyWith =>
      [aud, bgn, brl, cad, chf, clp, cop, czk, dkk, egp, eur, gbp, gtq, hkd, hrk, huf, idr, ils, inr, isk, jpy, krw, mad, mxn, myr, ngn, nok, nzd, php, pkr, pln, ron, sek, sgd, thb, twd, usd, vnd, zar];

  static const ars = FiatCurrency(symbol: 'ARS', countryCode: "arg", fullName: "Argentine Peso");
  static const aud = FiatCurrency(symbol: 'AUD', countryCode: "aus", fullName: "Australian Dollar");
  static const bdt = FiatCurrency(symbol: 'BDT', countryCode: "bgd", fullName: "Bangladeshi Taka");
  static const bgn = FiatCurrency(symbol: 'BGN', countryCode: "bgr", fullName: "Bulgarian Lev");
  static const brl = FiatCurrency(symbol: 'BRL', countryCode: "bra", fullName: "Brazilian Real");
  static const cad = FiatCurrency(symbol: 'CAD', countryCode: "cad", fullName: "Canadian Dollar");
  static const chf = FiatCurrency(symbol: 'CHF', countryCode: "che", fullName: "Swiss Franc");
  static const clp = FiatCurrency(symbol: 'CLP', countryCode: "chl", fullName: "Chilean Peso");
  static const cny = FiatCurrency(symbol: 'CNY', countryCode: "chn", fullName: "Chinese Yuan");
  static const cop = FiatCurrency(symbol: 'COP', countryCode: "col", fullName: "Colombian Peso");
  static const czk = FiatCurrency(symbol: 'CZK', countryCode: "czk", fullName: "Czech Koruna");
  static const dkk = FiatCurrency(symbol: 'DKK', countryCode: "dnk", fullName: "Danish Krone");
  static const egp = FiatCurrency(symbol: 'EGP', countryCode: "egy", fullName: "Egyptian Pound");
  static const eur = FiatCurrency(symbol: 'EUR', countryCode: "eur", fullName: "Euro");
  static const gbp = FiatCurrency(symbol: 'GBP', countryCode: "gbr", fullName: "Pound Sterling");
  static const ghs = FiatCurrency(symbol: 'GHS', countryCode: "gha", fullName: "Ghanaian Cedi");
  static const gtq = FiatCurrency(symbol: 'GTQ', countryCode: "gtm", fullName: "Guatemalan Quetzal");
  static const hkd = FiatCurrency(symbol: 'HKD', countryCode: "hkg", fullName: "Hong Kong Dollar");
  static const hrk = FiatCurrency(symbol: 'HRK', countryCode: "hrv", fullName: "Croatian Kuna");
  static const huf = FiatCurrency(symbol: 'HUF', countryCode: "hun", fullName: "Hungarian Forint");
  static const idr = FiatCurrency(symbol: 'IDR', countryCode: "idn", fullName: "Indonesian Rupiah");
  static const ils = FiatCurrency(symbol: 'ILS', countryCode: "isr", fullName: "Israeli New Shekel");
  static const inr = FiatCurrency(symbol: 'INR', countryCode: "ind", fullName: "Indian Rupee");
  static const irr = FiatCurrency(symbol: 'IRR', countryCode: "irn", fullName: "Iranian Rial");
  static const isk = FiatCurrency(symbol: 'ISK', countryCode: "isl", fullName: "Icelandic Krona Króna");
  static const jpy = FiatCurrency(symbol: 'JPY', countryCode: "jpn", fullName: "Japanese Yen");
  static const krw = FiatCurrency(symbol: 'KRW', countryCode: "kor", fullName: "South Korean Won");
  static const mad = FiatCurrency(symbol: 'MAD', countryCode: "mar", fullName: "Moroccan Dirham");
  static const mxn = FiatCurrency(symbol: 'MXN', countryCode: "mex", fullName: "Mexican Peso");
  static const myr = FiatCurrency(symbol: 'MYR', countryCode: "mys", fullName: "Malaysian Ringgit");
  static const ngn = FiatCurrency(symbol: 'NGN', countryCode: "nga", fullName: "Nigerian Naira");
  static const nok = FiatCurrency(symbol: 'NOK', countryCode: "nor", fullName: "Norwegian Krone");
  static const nzd = FiatCurrency(symbol: 'NZD', countryCode: "nzl", fullName: "New Zealand Dollar");
  static const php = FiatCurrency(symbol: 'PHP', countryCode: "phl", fullName: "Philippine Peso");
  static const pkr = FiatCurrency(symbol: 'PKR', countryCode: "pak", fullName: "Pakistani Rupee");
  static const pln = FiatCurrency(symbol: 'PLN', countryCode: "pol", fullName: "Poland Zloty złoty");
  static const ron = FiatCurrency(symbol: 'RON', countryCode: "rou", fullName: "Romanian Leu");
  static const rub = FiatCurrency(symbol: 'RUB', countryCode: "rus", fullName: "Russian Ruble");
  static const sar = FiatCurrency(symbol: 'SAR', countryCode: "sau", fullName: "Saudi Riyal");
  static const sek = FiatCurrency(symbol: 'SEK', countryCode: "swe", fullName: "Swedish Krona");
  static const sgd = FiatCurrency(symbol: 'SGD', countryCode: "sgp", fullName: "Singapore Dollar");
  static const thb = FiatCurrency(symbol: 'THB', countryCode: "tha", fullName: "New Thaiwan Dollar");
  static const twd = FiatCurrency(symbol: 'TWD', countryCode: "twn", fullName: "Thai Baht");
  static const uah = FiatCurrency(symbol: 'UAH', countryCode: "ukr", fullName: "Ukrainian Hryvnia");
  static const usd = FiatCurrency(symbol: 'USD', countryCode: "usa", fullName: "United States Dollar");
  static const vef = FiatCurrency(symbol: 'VEF', countryCode: "ven", fullName: "Venezuelan Bolivar Bolívar");
  static const vnd = FiatCurrency(symbol: 'VND', countryCode: "vnm", fullName: "Vietnamese Dong đồng");
  static const zar = FiatCurrency(symbol: 'ZAR', countryCode: "saf", fullName: "South African Rand");

  static final _all = {
    FiatCurrency.ars.raw: FiatCurrency.ars,
    FiatCurrency.aud.raw: FiatCurrency.aud,
    FiatCurrency.bdt.raw: FiatCurrency.bdt,
    FiatCurrency.bgn.raw: FiatCurrency.bgn,
    FiatCurrency.brl.raw: FiatCurrency.brl,
    FiatCurrency.cad.raw: FiatCurrency.cad,
    FiatCurrency.chf.raw: FiatCurrency.chf,
    FiatCurrency.clp.raw: FiatCurrency.clp,
    FiatCurrency.cny.raw: FiatCurrency.cny,
    FiatCurrency.cop.raw: FiatCurrency.cop,
    FiatCurrency.czk.raw: FiatCurrency.czk,
    FiatCurrency.dkk.raw: FiatCurrency.dkk,
    FiatCurrency.egp.raw: FiatCurrency.egp,
    FiatCurrency.eur.raw: FiatCurrency.eur,
    FiatCurrency.gbp.raw: FiatCurrency.gbp,
    FiatCurrency.ghs.raw: FiatCurrency.ghs,
    FiatCurrency.gtq.raw: FiatCurrency.gtq,
    FiatCurrency.hkd.raw: FiatCurrency.hkd,
    FiatCurrency.hrk.raw: FiatCurrency.hrk,
    FiatCurrency.huf.raw: FiatCurrency.huf,
    FiatCurrency.idr.raw: FiatCurrency.idr,
    FiatCurrency.ils.raw: FiatCurrency.ils,
    FiatCurrency.inr.raw: FiatCurrency.inr,
    FiatCurrency.irr.raw: FiatCurrency.irr,
    FiatCurrency.isk.raw: FiatCurrency.isk,
    FiatCurrency.jpy.raw: FiatCurrency.jpy,
    FiatCurrency.krw.raw: FiatCurrency.krw,
    FiatCurrency.mad.raw: FiatCurrency.mad,
    FiatCurrency.mxn.raw: FiatCurrency.mxn,
    FiatCurrency.myr.raw: FiatCurrency.myr,
    FiatCurrency.ngn.raw: FiatCurrency.ngn,
    FiatCurrency.nok.raw: FiatCurrency.nok,
    FiatCurrency.nzd.raw: FiatCurrency.nzd,
    FiatCurrency.php.raw: FiatCurrency.php,
    FiatCurrency.pkr.raw: FiatCurrency.pkr,
    FiatCurrency.pln.raw: FiatCurrency.pln,
    FiatCurrency.ron.raw: FiatCurrency.ron,
    FiatCurrency.rub.raw: FiatCurrency.rub,
    FiatCurrency.sar.raw: FiatCurrency.sar,
    FiatCurrency.sek.raw: FiatCurrency.sek,
    FiatCurrency.sgd.raw: FiatCurrency.sgd,
    FiatCurrency.thb.raw: FiatCurrency.thb,
    FiatCurrency.twd.raw: FiatCurrency.twd,
    FiatCurrency.uah.raw: FiatCurrency.uah,
    FiatCurrency.usd.raw: FiatCurrency.usd,
    FiatCurrency.vef.raw: FiatCurrency.vef,
    FiatCurrency.vnd.raw: FiatCurrency.vnd,
    FiatCurrency.zar.raw: FiatCurrency.zar
  };

  static FiatCurrency deserialize({required String raw}) => _all[raw]!;

  @override
  bool operator ==(Object other) => other is FiatCurrency && other.raw == raw;

  @override
  int get hashCode => raw.hashCode ^ title.hashCode;
  
  @override
  String get name => raw;
  
  @override
  String? get tag => null;

  @override
  String get iconPath => "assets/images/flags/$countryCode.svg";
}
