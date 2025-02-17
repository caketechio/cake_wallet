import 'dart:async';
import 'dart:io';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/connect_device/connect_device_page.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/hardware/device_connection_type.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/widgets.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as sdk;
import 'package:mobx/mobx.dart';
import 'package:permission_handler/permission_handler.dart';

part 'ledger_view_model.g.dart';

class LedgerViewModel = LedgerViewModelBase with _$LedgerViewModel;

abstract class LedgerViewModelBase with Store {
  // late final Ledger ledger;
  late final sdk.LedgerInterface ledgerPlusBLE;
  late final sdk.LedgerInterface ledgerPlusUSB;

  bool get _doesSupportHardwareWallets {
    if (!DeviceInfo.instance.isMobile) {
      return false;
    }

    if (isMoneroOnly) {
      return DeviceConnectionType.supportedConnectionTypes(
              WalletType.monero, Platform.isIOS)
          .isNotEmpty;
    }

    return true;
  }

  LedgerViewModelBase() {
    if (_doesSupportHardwareWallets) {
      reaction((_) => bleIsEnabled, (_) {
        if (bleIsEnabled) _initBLE();
      });
      updateBleState();

      if (!Platform.isIOS) {
        ledgerPlusUSB = sdk.LedgerInterface.usb();
      }
    }
  }

  @observable
  bool bleIsEnabled = false;

  bool _bleIsInitialized = false;

  Future<void> _initBLE() async {
    if (bleIsEnabled && !_bleIsInitialized) {
      ledgerPlusBLE = sdk.LedgerInterface.ble(
        onPermissionRequest: (_) async {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.bluetoothAdvertise,
          ].request();

          return statuses.values.where((status) => status.isDenied).isEmpty;
        },
        bleOptions: sdk.BluetoothOptions(maxScanDuration: Duration(minutes: 5)),
      );
      _bleIsInitialized = true;
    }
  }

  Future<void> updateBleState() async {
    final bleState = await sdk.UniversalBle.getBluetoothAvailabilityState();

    final newState = bleState == sdk.AvailabilityState.poweredOn;

    if (newState != bleIsEnabled) bleIsEnabled = newState;
  }

  Stream<sdk.LedgerDevice> scanForBleDevices() => ledgerPlusBLE.scan();

  Stream<sdk.LedgerDevice> scanForUsbDevices() => ledgerPlusUSB.scan();

  Future<void> stopScanning() async {
    if (_bleIsInitialized) await ledgerPlusBLE.stopScanning();
    if (!Platform.isIOS) await ledgerPlusUSB.stopScanning();
  }

  Future<void> connectLedger(sdk.LedgerDevice device, WalletType type) async {
    _isConnecting = true;
    _connectingWalletType = type;
    if (isConnected) {
      try {
        await _connection!.disconnect().catchError((_) {});
      } catch (_) {}
    }

    final ledger = device.connectionType == sdk.ConnectionType.ble
        ? ledgerPlusBLE
        : ledgerPlusUSB;

    if (_connectionChangeSubscription == null) {
      _connectionChangeSubscription =
          ledger.deviceStateChanges.listen(_connectionChangeListener);
    }

    _connection = await ledger.connect(device);
    _isConnecting = false;
  }

  StreamSubscription<sdk.BleConnectionState>? _connectionChangeSubscription;
  sdk.LedgerConnection? _connection;
  bool _isConnecting = true;
  WalletType? _connectingWalletType;

  void _connectionChangeListener(sdk.BleConnectionState event) {
    printV('Ledger Device State Changed: $event');
    if (event == sdk.BleConnectionState.disconnected && !_isConnecting) {
      _connection = null;
      if (_connectingWalletType == WalletType.monero) {
        monero!.resetLedgerConnection();

        Navigator.of(navigatorKey.currentContext!).pushNamed(
          Routes.connectDevices,
          arguments: ConnectDevicePageParams(
            walletType: WalletType.monero,
            allowChangeWallet: true,
            isReconnect: true,
            onConnectDevice: (context, ledgerVM) async {
              Navigator.of(context).pop();
            },
          ),
        );
      }
    }
  }

  bool get isConnected => _connection != null && !(_connection!.isDisconnected);

  sdk.LedgerConnection get connection => _connection!;

  void setLedger(WalletBase wallet) {
    switch (wallet.type) {
      case WalletType.monero:
        return monero!.setLedgerConnection(wallet, connection);
      case WalletType.bitcoin:
      case WalletType.litecoin:
        return bitcoin!.setLedgerConnection(wallet, connection);
      case WalletType.ethereum:
        return ethereum!.setLedgerConnection(wallet, connection);
      case WalletType.polygon:
        return polygon!.setLedgerConnection(wallet, connection);
      default:
        throw Exception('Unexpected wallet type: ${wallet.type}');
    }
  }

  String? interpretErrorCode(String errorCode) {
    switch (errorCode) {
      case "6985":
        return S.current.ledger_error_tx_rejected_by_user;
      case "5515":
        return S.current.ledger_error_device_locked;
      case "6d02": // UNKNOWN_APDU
      case "6511":
      case "6e00":
        return S.current.ledger_error_wrong_app;
      default:
        return null;
    }
  }
}
