import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/core/sync_status_title.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/sync_indicator_icon.dart';

class SyncIndicator extends StatelessWidget {
  SyncIndicator({required this.dashboardViewModel, required this.onTap});

  final DashboardViewModel dashboardViewModel;
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      final syncIndicatorWidth = 237.0;
      final status = dashboardViewModel.status;
      final statusText = status != null ? syncStatusTitle(status) : '';
      final progress = status != null ? status.progress() : 0.0;
      final indicatorOffset = progress * syncIndicatorWidth;
      final indicatorWidth = progress < 1
          ? indicatorOffset > 0
              ? indicatorOffset
              : 0.0
          : syncIndicatorWidth;

      return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 30,
              width: syncIndicatorWidth,
              color: Theme.of(context).extension<SyncIndicatorTheme>()!.notSyncedBackgroundColor,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  progress <= 1
                      ? Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: indicatorWidth,
                            height: 30,
                            color: Theme.of(context)
                                .extension<SyncIndicatorTheme>()!
                                .syncedBackgroundColor,
                          ))
                      : Offstage(),
                  Row(
                    children: [
                      Observer(builder: (_) {
                        if (dashboardViewModel.isElectrumBased) {
                          return Container(
                            width: 15,
                          );
                        }
                        Widget torImage;
                        switch (dashboardViewModel.torViewModel.torConnectionStatus) {
                          case TorConnectionStatus.connected:
                            torImage = Image.asset(
                              'assets/images/tor_onion.png',
                              color: Color(0xFF6000D9),
                            );
                            break;
                          case TorConnectionStatus.connecting:
                            torImage = Image.asset(
                              'assets/images/tor_onion.png',
                              color: Theme.of(context).extension<SyncIndicatorTheme>()!.notSyncedIconColor,
                            );
                            break;
                          case TorConnectionStatus.disconnected:
                          default:
                            torImage = Image.asset(
                              'assets/images/tor_onion.png',
                              color: Theme.of(context).extension<SyncIndicatorTheme>()!.textColor,
                            );
                            break;
                        }
                        return Container(
                          width: 15,
                          margin: EdgeInsets.only(left: 12, bottom: 2),
                          child: torImage,
                        );
                      }),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 24, right: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SyncIndicatorIcon(isSynced: status is SyncedSyncStatus),
                        Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            statusText,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    Theme.of(context).extension<SyncIndicatorTheme>()!.textColor),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ));
    });
  }
}
