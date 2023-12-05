import 'package:cake_wallet/generated/i18n.dart';

enum ExchangeProviderType {
  AskEachTime,
  MoonPay,
  Normal;

  @override
  String toString() {
    switch (this) {
      case ExchangeProviderType.AskEachTime:
        return S.current.ask_each_time;
      case ExchangeProviderType.MoonPay:
        return "MoonPay";
      case ExchangeProviderType.Normal:
        return "Normal";
    }
  }
}
