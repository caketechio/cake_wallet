import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_dashboard_navbar.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_sidebar/side_menu.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_sidebar/side_menu_item.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_wallet_selection_dropdown.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/sync_indicator.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/bottom_sheet_listener.dart';
import 'package:cake_wallet/src/widgets/services_updates_widget.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/desktop_sidebar_view_model.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/router.dart' as Router;
import 'package:mobx/mobx.dart';

class DesktopSidebarWrapper extends BasePage {
  final BottomSheetService bottomSheetService;
  final Widget child;
  final DesktopSidebarViewModel desktopSidebarViewModel;
  final DashboardViewModel dashboardViewModel;
  final GlobalKey<NavigatorState> desktopNavigatorKey;

  DesktopSidebarWrapper({
    required this.child,
    required this.bottomSheetService,
    required this.desktopSidebarViewModel,
    required this.dashboardViewModel,
    required this.desktopNavigatorKey,
  });

  @override
  ObstructingPreferredSizeWidget appBar(BuildContext context) => DesktopDashboardNavbar(
        leading: Padding(
          padding: EdgeInsets.only(left: sideMenuWidth),
          child: getIt<DesktopWalletSelectionDropDown>(),
        ),
        middle: SyncIndicator(
          dashboardViewModel: dashboardViewModel,
          onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(Routes.connectionSync),
        ),
        trailing: InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(
              Routes.unlock,
              arguments: (bool isAuthenticatedSuccessfully, AuthPageState auth) {
                if (isAuthenticatedSuccessfully) {
                  auth.close();
                }
              },
            );
          },
          child: Icon(Icons.lock_outline),
        ),
      );

  @override
  bool get resizeToAvoidBottomInset => false;

  final pageController = PageController();

  final selectedIconPath = 'assets/images/desktop_transactions_solid_icon.png';
  final unselectedIconPath = 'assets/images/desktop_transactions_outline_icon.png';

  double get sideMenuWidth => 76.0;

  @override
  Widget body(BuildContext context) {
    _setEffects();

    return BottomSheetListener(
      bottomSheetService: bottomSheetService,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Observer(builder: (_) {
            return SideMenu(
              width: sideMenuWidth,
              topItems: [
                SideMenuItem(
                  imagePath: 'assets/images/wallet_outline.png',
                  isSelected: desktopSidebarViewModel.currentPage == SidebarItem.dashboard,
                  onTap: () {
                    desktopSidebarViewModel.onPageChange(SidebarItem.dashboard);
                    desktopNavigatorKey.currentState
                        ?.pushNamedAndRemoveUntil(Routes.desktop_actions, (route) => false);
                  },
                ),
                SideMenuItem(
                  onTap: () {
                    if (desktopSidebarViewModel.currentPage == SidebarItem.transactions) {
                      desktopNavigatorKey.currentState
                          ?.pushNamedAndRemoveUntil(Routes.desktop_actions, (route) => false);
                      desktopSidebarViewModel.resetSidebar();
                    } else {
                      desktopSidebarViewModel.onPageChange(SidebarItem.transactions);
                      desktopNavigatorKey.currentState?.pushNamed(Routes.transactionsPage);
                    }
                  },
                  isSelected: desktopSidebarViewModel.currentPage == SidebarItem.transactions,
                  imagePath: desktopSidebarViewModel.currentPage == SidebarItem.transactions
                      ? selectedIconPath
                      : unselectedIconPath,
                ),
                SideMenuItem(
                  widget: ServicesUpdatesWidget(dashboardViewModel.getServicesStatus()),
                  isSelected: desktopSidebarViewModel.currentPage == SidebarItem.status,
                  onTap: () {},
                ),
              ],
              bottomItems: [
                SideMenuItem(
                  imagePath: 'assets/images/support_icon.png',
                  isSelected: desktopSidebarViewModel.currentPage == SidebarItem.support,
                  onTap: () => desktopSidebarViewModel.onPageChange(SidebarItem.support),
                ),
                SideMenuItem(
                  imagePath: 'assets/images/settings_outline.png',
                  isSelected: desktopSidebarViewModel.currentPage == SidebarItem.settings,
                  onTap: () => desktopSidebarViewModel.onPageChange(SidebarItem.settings),
                ),
              ],
            );
          }),
          Expanded(
            child: PageView(
              controller: pageController,
              physics: NeverScrollableScrollPhysics(),
              children: [
                child,
                Container(
                  color: Theme.of(context).colorScheme.background,
                  padding: EdgeInsets.all(20),
                  child: Navigator(
                    initialRoute: Routes.support,
                    onGenerateRoute: (settings) => Router.createRoute(settings),
                    onGenerateInitialRoutes: (NavigatorState navigator, String initialRouteName) {
                      return [
                        navigator.widget.onGenerateRoute!(RouteSettings(name: initialRouteName))!
                      ];
                    },
                  ),
                ),
                Navigator(
                  initialRoute: Routes.desktop_settings_page,
                  onGenerateRoute: (settings) => Router.createRoute(settings),
                  onGenerateInitialRoutes: (NavigatorState navigator, String initialRouteName) {
                    return [
                      navigator.widget.onGenerateRoute!(RouteSettings(name: initialRouteName))!
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setEffects() async {
    reaction<SidebarItem>((_) => desktopSidebarViewModel.currentPage, (page) {
      if (page == SidebarItem.dashboard) {
        pageController.jumpToPage(0);
        return;
      }
      pageController.jumpToPage(page.index - 1);
    });
  }
}
