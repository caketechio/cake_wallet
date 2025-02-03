import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/setting_action_button.dart';
import 'package:cake_wallet/src/widgets/setting_actions.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/router.dart' as Router;
import 'package:cake_wallet/themes/extensions/menu_theme.dart';

final _settingsNavigatorKey = GlobalKey<NavigatorState>();

class DesktopSettingsPage extends StatefulWidget {
  const DesktopSettingsPage(this.dashboardViewModel, {super.key});

  final DashboardViewModel dashboardViewModel;

  @override
  State<DesktopSettingsPage> createState() => _DesktopSettingsPageState();
}

class _DesktopSettingsPageState extends State<DesktopSettingsPage> {
  final int itemCount = SettingActions.desktopSettings.length;

  int? currentPage;

  void _onItemChange(int index) {
    setState(() {
      currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.background,
        height: MediaQuery.of(context).size.height,
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                    child: Text(
                      S.current.settings,
                      style: textXLarge(),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.only(top: 0),
                      itemBuilder: (_, index) {
                        final item = SettingActions.desktopSettings[index];

                        if (!widget.dashboardViewModel.hasSilentPayments &&
                            item.name(context) == S.of(context).silent_payments_settings) {
                          return Container();
                        }

                        if ((!widget.dashboardViewModel.isMoneroViewOnly &&
                            item.name(context) == S.of(context).export_outputs) ||
                           (!widget.dashboardViewModel.hasMweb &&
                            item.name(context) == S.of(context).litecoin_mweb_settings)) {
                          return Container();
                        }

                        final isLastTile = index == itemCount - 1;
                        return SettingActionButton(
                          isLastTile: isLastTile,
                          selectionActive: currentPage != null,
                          isSelected: currentPage == index,
                          isArrowVisible: true,
                          onTap: () {
                            if (currentPage != index) {
                              final settingContext =
                                  _settingsNavigatorKey.currentState?.context ?? context;
                              item.onTap.call(settingContext);
                              _onItemChange(index);
                            }
                          },
                          image: item.image,
                          title: item.name.call(context),
                        );
                      },
                      separatorBuilder: (_, index) => Container(
                        height: 1,
                        color: Theme.of(context).extension<CakeMenuTheme>()!.dividerColor,
                      ),
                      itemCount: itemCount,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              flex: 2,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 500),
                child: Navigator(
                  key: _settingsNavigatorKey,
                  initialRoute: Routes.empty_no_route,
                  onGenerateRoute: (settings) => Router.createRoute(settings),
                  onGenerateInitialRoutes:
                      (NavigatorState navigator, String initialRouteName) {
                    return [
                      navigator
                          .widget.onGenerateRoute!(RouteSettings(name: initialRouteName))!
                    ];
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
