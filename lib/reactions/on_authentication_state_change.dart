import 'dart:async';

import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/hardware_wallet/require_hardware_wallet_connection.dart';
import 'package:cake_wallet/entities/load_current_wallet.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/connect_device/connect_device_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/store/authentication_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:rxdart/subjects.dart';

ReactionDisposer? _onAuthenticationStateChange;

dynamic loginError;
StreamController<dynamic> authenticatedErrorStreamController =
    BehaviorSubject<dynamic>();

void startAuthenticationStateChange(
  AuthenticationStore authenticationStore,
  GlobalKey<NavigatorState> navigatorKey,
) {
  authenticatedErrorStreamController.stream.listen((event) {
    if (authenticationStore.state == AuthenticationState.allowed) {
      ExceptionHandler.showError(event.toString(), delayInSeconds: 3);
    }
  });

  _onAuthenticationStateChange ??= autorun((_) async {
    final state = authenticationStore.state;

    if (state == AuthenticationState.installed &&
        !SettingsStoreBase.walletPasswordDirectInput) {
      try {
        if (!requireHardwareWalletConnection()) await loadCurrentWallet();
      } catch (error, stack) {
        loginError = error;
        await ExceptionHandler.resetLastPopupDate();
        await ExceptionHandler.onError(
            FlutterErrorDetails(exception: error, stack: stack));
      }
      return;
    }

    if ([AuthenticationState.allowed, AuthenticationState.allowedCreate]
        .contains(state)) {
      if (state == AuthenticationState.allowed &&
          requireHardwareWalletConnection()) {
        await navigatorKey.currentState!.pushNamedAndRemoveUntil(
          Routes.connectDevices,
          (route) => false,
          arguments: ConnectDevicePageParams(
            walletType: WalletType.monero,
            onConnectDevice: (context, ledgerVM) async {
              monero!.setGlobalLedgerConnection(ledgerVM.connection);
              showPopUp<void>(
                context: context,
                builder: (BuildContext context) => AlertWithOneAction(
                    alertTitle: S.of(context).proceed_on_device,
                    alertContent: S.of(context).proceed_on_device_description,
                    buttonText: S.of(context).cancel,
                    alertBarrierDismissible: false,
                    buttonAction: () => Navigator.of(context).pop()),
              );
              await loadCurrentWallet();
              getIt.get<BottomSheetService>().resetCurrentSheet();
              await navigatorKey.currentState!
                  .pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
            },
            allowChangeWallet: true,
          ),
        );

        // await navigatorKey.currentState!.pushNamedAndRemoveUntil(Routes.connectDevices, (route) => false, arguments: ConnectDevicePageParams(walletType: walletType, onConnectDevice: onConnectDevice));
      } else {
        await navigatorKey.currentState!
            .pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
      }
      if (!(await authenticatedErrorStreamController.stream.isEmpty)) {
        await ExceptionHandler.showError(
            (await authenticatedErrorStreamController.stream.first).toString());
        authenticatedErrorStreamController.stream.drain();
      }
      return;
    }
  });
}
