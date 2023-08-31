import 'dart:developer';

import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/core/wallet_connect/web3wallet_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/bottom_sheet_listener.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:get_it_mixin/get_it_mixin.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:cake_wallet/entities/qr_scanner.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';

import 'widgets/pairing_item_widget.dart';
import 'wc_pairing_detail_page.dart';

class WalletConnectConnectionsView extends StatefulWidget with GetItStatefulWidgetMixin {
  final Web3WalletService web3walletService;
  final BottomSheetService bottomSheetService;

  WalletConnectConnectionsView({
    Key? key,
    required this.web3walletService,
    required this.bottomSheetService,
  }) : super(key: key);

  @override
  WalletConnectConnectionsViewState createState() => WalletConnectConnectionsViewState();
}

class WalletConnectConnectionsViewState extends State<WalletConnectConnectionsView>
    with GetItStateMixin {
  List<PairingInfo> _pairings = [];

  Web3Wallet get web3Wallet => widget.web3walletService.getWeb3Wallet();

  @override
  void initState() {
    _pairings = web3Wallet.pairings.getAll();
    web3Wallet.core.pairing.onPairingDelete.subscribe(_onPairingDelete);
    web3Wallet.core.pairing.onPairingExpire.subscribe(_onPairingDelete);
    super.initState();
  }

  @override
  void dispose() {
    web3Wallet.core.pairing.onPairingDelete.unsubscribe(_onPairingDelete);
    web3Wallet.core.pairing.onPairingExpire.unsubscribe(_onPairingDelete);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pairings = watch(target: widget.web3walletService.pairings);

    return WCPairingsWidget(
      pairings: _pairings,
      web3wallet: web3Wallet,
      web3walletService: widget.web3walletService,
      bottomSheetService: widget.bottomSheetService,
    );
  }

  void _onPairingDelete(PairingEvent? event) {
    setState(() {
      _pairings = web3Wallet.pairings.getAll();
    });
  }
}

class WCPairingsWidget extends BasePage {
  WCPairingsWidget(
{
    required this.pairings,
    required this.web3wallet,
    required this.web3walletService,
    required this.bottomSheetService, 
    Key? key,
  });

  final List<PairingInfo> pairings;
  final Web3Wallet web3wallet;
  final Web3WalletService web3walletService;
  final BottomSheetService bottomSheetService;

  @override
  String get title => 'WalletConnect';

  Future<void> _onScanQrCode(BuildContext context, Web3Wallet web3Wallet) async {
    final String? uri = await presentQRScanner();

    if (uri == null) return _invalidUriToast(context, 'URI is null');

    try {
      log('_onFoundUri: $uri');
      final Uri uriData = Uri.parse(uri);
      await web3Wallet.pair(uri: uriData);
    } on WalletConnectError catch (e) {
      await _invalidUriToast(context, e.message);
    } catch (e) {
      await _invalidUriToast(context, e.toString());
    }
  }

  Future<void> _invalidUriToast(BuildContext context, String message) async {
    await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertWithOneAction(
          alertTitle: S.of(context).error,
          alertContent: message,
          buttonText: S.of(context).ok,
          buttonAction: Navigator.of(context).pop,
          alertBarrierDismissible: false,
        );
      },
    );
  }

  @override
  Widget body(BuildContext context) {
    return BottomSheetListener(
      bottomSheetService: bottomSheetService,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(height: 24),
                Text(
                  'Connect your wallet with WalletConnect to make transactions',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                  ),
                ),
                SizedBox(height: 16),
                PrimaryButton(
                  text: 'New Connection',
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                  onPressed: () => _onScanQrCode(context, web3wallet),
                ),
              ],
            ),
          ),
          SizedBox(height: 48),
          Expanded(
            child: Visibility(
              visible: pairings.isEmpty,
              child: Center(
                child: Text(
                  'Active connections will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                  ),
                ),
              ),
              replacement: ListView.builder(
                itemCount: pairings.length,
                itemBuilder: (BuildContext context, int index) {
                  final pairing = pairings[index];
                  return PairingItemWidget(
                    key: ValueKey(pairing.topic),
                    pairing: pairing,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalletConnectPairingDetailsPage(
                            pairing: pairing,
                            web3walletService: web3walletService,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 48),
        ],
      ),
    );
  }
}
