import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/enumerable_item.dart';

class TorConnectionMode extends EnumerableItem<int> with Serializable<int> {
  const TorConnectionMode({required String title, required int raw}) : super(title: title, raw: raw);

  static const all = [TorConnectionMode.enabled, TorConnectionMode.disabled, TorConnectionMode.torOnly];
  static const enabledDisabled = [TorConnectionMode.enabled, TorConnectionMode.disabled];

  static const enabled = TorConnectionMode(raw: 0, title: 'Enabled');
  static const disabled = TorConnectionMode(raw: 1, title: 'Disabled');
  static const torOnly = TorConnectionMode(raw: 2, title: 'Tor only');

  static TorConnectionMode deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return enabled;
      case 1:
        return disabled;
      case 2:
        return torOnly;
      default:
        throw Exception('Unexpected token: $raw for TorConnectionMode deserialize');
    }
  }

  @override
  String toString() {
    switch (this) {
      case TorConnectionMode.enabled:
        return S.current.enabled;
      case TorConnectionMode.disabled:
        return S.current.disabled;
      case TorConnectionMode.torOnly:
        return S.current.tor_only;
      default:
        return '';
    }
  }
}



class TorConnectionStatus extends EnumerableItem<int> with Serializable<int> {
  const TorConnectionStatus({required String title, required int raw}) : super(title: title, raw: raw);

  static const all = [TorConnectionMode.enabled, TorConnectionMode.disabled, TorConnectionMode.torOnly];

  static const connecting = TorConnectionStatus(raw: 0, title: 'Connecting');
  static const connected = TorConnectionStatus(raw: 1, title: 'Connected');
  static const disconnected = TorConnectionStatus(raw: 2, title: 'Disconnected');

  static TorConnectionStatus deserialize({required int raw}) {
    switch (raw) {
      case 0:
        return connecting;
      case 1:
        return connected;
      case 2:
        return disconnected;
      default:
        throw Exception('Unexpected token: $raw for TorConnectionStatus deserialize');
    }
  }

  @override
  String toString() {
    switch (this) {
      case TorConnectionStatus.connecting:
        return S.current.connecting;
      case TorConnectionStatus.connected:
        return S.current.connected;
      case TorConnectionStatus.disconnected:
        return S.current.disconnected;
      default:
        return '';
    }
  }
}