import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/setting_action_button.dart';
import 'package:cake_wallet/src/widgets/setting_actions.dart';
import 'package:cake_wallet/themes/extensions/menu_theme.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class MenuWidget extends StatefulWidget {
  MenuWidget(this.dashboardViewModel, Key? key);

  final DashboardViewModel dashboardViewModel;

  @override
  MenuWidgetState createState() => MenuWidgetState();
}

class MenuWidgetState extends State<MenuWidget> {
  MenuWidgetState()
      : this.menuWidth = 0,
        this.screenWidth = 0,
        this.screenHeight = 0,
        this.headerHeight = 120,
        this.tileHeight = 60,
        this.fromTopEdge = 50,
        this.fromBottomEdge = 25,
        this.moneroIcon = Image.asset('assets/images/monero_menu.png'),
        this.bitcoinIcon = Image.asset('assets/images/bitcoin_menu.png'),
        this.litecoinIcon = Image.asset('assets/images/litecoin_menu.png'),
        this.havenIcon = Image.asset('assets/images/haven_menu.png'),
        this.ethereumIcon = Image.asset('assets/images/eth_icon.png'),
        this.nanoIcon = Image.asset('assets/images/nano_icon.png'),
        this.bananoIcon = Image.asset('assets/images/nano_icon.png'),
        this.bitcoinCashIcon = Image.asset('assets/images/bch_icon.png'),
        this.polygonIcon = Image.asset('assets/images/matic_icon.png'),
        this.solanaIcon = Image.asset('assets/images/sol_icon.png'),
        this.tronIcon = Image.asset('assets/images/trx_icon.png'),
        this.wowneroIcon = Image.asset('assets/images/wownero_icon.png'),
        this.zanoIcon = Image.asset('assets/images/zano_icon.png');

  final largeScreen = 731;

  double menuWidth;
  double screenWidth;
  double screenHeight;

  double headerHeight;
  double tileHeight;
  double fromTopEdge;
  double fromBottomEdge;

  Image moneroIcon;
  Image bitcoinIcon;
  Image litecoinIcon;
  Image havenIcon;
  Image ethereumIcon;
  Image bitcoinCashIcon;
  Image nanoIcon;
  Image bananoIcon;
  Image polygonIcon;
  Image solanaIcon;
  Image tronIcon;
  Image wowneroIcon;
  Image zanoIcon;

  @override
  void initState() {
    menuWidth = 0;
    screenWidth = 0;
    screenHeight = 0;

    headerHeight = 120;
    tileHeight = 60;
    fromTopEdge = 50;
    fromBottomEdge = 25;

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(afterLayout);
  }

  void afterLayout(dynamic _) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      menuWidth = screenWidth;

      if (screenHeight > largeScreen) {
        final scale = screenHeight / largeScreen;
        tileHeight *= scale;
        headerHeight *= scale;
        fromTopEdge *= scale;
        fromBottomEdge *= scale;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<SettingActions> items = List.of(SettingActions.all);
    if (!widget.dashboardViewModel.hasSilentPayments) {
      items.removeWhere((element) => element.name(context) == S.of(context).silent_payments_settings);
    }
    if (!widget.dashboardViewModel.isMoneroViewOnly) {
      items.removeWhere((element) => element.name(context) == S.of(context).export_outputs);
    }
    if (!widget.dashboardViewModel.hasMweb) {
      items.removeWhere((element) => element.name(context) == S.of(context).litecoin_mweb_settings);
    }
    int itemCount = items.length;

    moneroIcon = Image.asset('assets/images/monero_menu.png',
        color: Theme.of(context).extension<CakeMenuTheme>()!.iconColor);
    bitcoinIcon = Image.asset('assets/images/bitcoin_menu.png',
        color: Theme.of(context).extension<CakeMenuTheme>()!.iconColor);

    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: 24),
          child: Container(
            height: 60,
            width: 4,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(2)), color: PaletteDark.gray),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius:
                BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
            child: Container(
              color: Theme.of(context).extension<CakeMenuTheme>()!.backgroundColor,
              child: ListView.separated(
                padding: EdgeInsets.only(top: 0),
                itemBuilder: (_, index) {
                  if (index == 0) {
                    return Container(
                      height: headerHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Theme.of(context).extension<CakeMenuTheme>()!.headerFirstGradientColor,
                          Theme.of(context).extension<CakeMenuTheme>()!.headerSecondGradientColor,
                        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      padding: EdgeInsets.only(
                          left: 24, top: fromTopEdge, right: 24, bottom: fromBottomEdge),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          _iconFor(type: widget.dashboardViewModel.type),
                          SizedBox(width: 12),
                          SingleChildScrollView(
                            child: Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: widget.dashboardViewModel.subname.isNotEmpty
                                    ? MainAxisAlignment.spaceBetween
                                    : MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(
                                    widget.dashboardViewModel.name,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  if (widget.dashboardViewModel.subname.isNotEmpty)
                                    Observer(
                                      builder: (_) => Text(
                                        widget.dashboardViewModel.subname,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .extension<CakeMenuTheme>()!
                                                .subnameTextColor,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  index--;

                  final item = items[index];
                  final isLastTile = index == itemCount - 1;

                  return SettingActionButton(
                    key: item.key,
                    isLastTile: isLastTile,
                    tileHeight: tileHeight,
                    selectionActive: false,
                    fromBottomEdge: fromBottomEdge,
                    fromTopEdge: fromTopEdge,
                    onTap: () => item.onTap.call(context),
                    image: item.image,
                    title: item.name.call(context),
                  );
                },
                separatorBuilder: (_, index) => Container(
                  height: 1,
                  color: Theme.of(context).extension<CakeMenuTheme>()!.dividerColor,
                ),
                itemCount: itemCount + 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Image _iconFor({required WalletType type}) {
    switch (type) {
      case WalletType.monero:
        return moneroIcon;
      case WalletType.bitcoin:
        return bitcoinIcon;
      case WalletType.litecoin:
        return litecoinIcon;
      case WalletType.haven:
        return havenIcon;
      case WalletType.ethereum:
        return ethereumIcon;
      case WalletType.bitcoinCash:
        return bitcoinCashIcon;
      case WalletType.nano:
        return nanoIcon;
      case WalletType.banano:
        return bananoIcon;
      case WalletType.polygon:
        return polygonIcon;
      case WalletType.solana:
        return solanaIcon;
      case WalletType.tron:
        return tronIcon;
      case WalletType.wownero:
        return wowneroIcon;
      case WalletType.zano:
        return zanoIcon;
      default:
        throw Exception('No icon for ${type.toString()}');
    }
  }
}
