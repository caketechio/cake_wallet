import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/enumerable_item.dart';

class ExchangeApiMode extends EnumerableItem<int> with Serializable<int> {
  const ExchangeApiMode({required String title, required int raw}) : super(title: title, raw: raw);

  static const all = [ExchangeApiMode.enabled, ExchangeApiMode.disabled];

  static const enabled = ExchangeApiMode(raw: 0, title: 'Enabled');
  static const disabled = ExchangeApiMode(raw: 1, title: 'Disabled');

  static ExchangeApiMode deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return enabled;
      case 1:
        return disabled;
      default:
        throw Exception('Unexpected token: $raw for ExchangeApiMode deserialize');
    }
  }

  @override
  String toString() {
    switch (this) {
      case ExchangeApiMode.enabled:
        return S.current.enabled;
      case ExchangeApiMode.disabled:
        return S.current.disabled;
      default:
        return '';
    }
  }
}