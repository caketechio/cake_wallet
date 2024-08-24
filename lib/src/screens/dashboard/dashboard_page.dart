import 'dart:async';
import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/main_actions.dart';
import 'package:cake_wallet/src/screens/dashboard/desktop_widgets/desktop_sidebar_wrapper.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/cake_features_page.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/bottom_sheet_listener.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/gradient_background.dart';
import 'package:cake_wallet/src/widgets/haven_wallet_removal_popup.dart';
import 'package:cake_wallet/src/widgets/services_updates_widget.dart';
import 'package:cake_wallet/src/widgets/vulnerable_seeds_popup.dart';
import 'package:cake_wallet/themes/extensions/sync_indicator_theme.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/version_comparator.dart';
import 'package:cake_wallet/view_model/dashboard/cake_features_view_model.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/yat_emoji_id.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/menu_widget.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/action_button.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/balance_page.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/transactions_page.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/sync_indicator.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/src/screens/release_notes/release_notes_screen.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';

class DashboardPage extends StatefulWidget {
  DashboardPage({
    required this.bottomSheetService,
    required this.balancePage,
    required this.dashboardViewModel,
    required this.addressListViewModel,
  });

  final BalancePage balancePage;
  final BottomSheetService bottomSheetService;
  final DashboardViewModel dashboardViewModel;
  final WalletAddressListViewModel addressListViewModel;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();

    bool isMobileLayout =
        responsiveLayoutUtil.screenWidth < ResponsiveLayoutUtilBase.kMobileThreshold;

    reaction((_) => responsiveLayoutUtil.screenWidth, (screenWidth) {
      // Check if it was previously in mobile layout, and now changing to desktop
      if (isMobileLayout &&
          screenWidth > ResponsiveLayoutUtilBase.kDesktopMaxDashBoardWidthConstraint) {
        setState(() {
          isMobileLayout = false;
        });
      }

      // Check if it was previously in desktop layout, and now changing to mobile
      if (!isMobileLayout &&
          screenWidth <= ResponsiveLayoutUtilBase.kDesktopMaxDashBoardWidthConstraint) {
        setState(() {
          isMobileLayout = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget dashboardChild;

    final dashboardPageView = RefreshIndicator(
      displacement: responsiveLayoutUtil.screenHeight * 0.1,
      onRefresh: () async => await widget.dashboardViewModel.refreshDashboard(),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Container(
          height: responsiveLayoutUtil.screenHeight,
          child: _DashboardPageView(
            balancePage: widget.balancePage,
            bottomSheetService: widget.bottomSheetService,
            dashboardViewModel: widget.dashboardViewModel,
            addressListViewModel: widget.addressListViewModel,
          ),
        ),
      ),
    );

    if (DeviceInfo.instance.isDesktop) {
      if (responsiveLayoutUtil.screenWidth >
          ResponsiveLayoutUtilBase.kDesktopMaxDashBoardWidthConstraint) {
        dashboardChild = getIt.get<DesktopSidebarWrapper>();
      } else {
        dashboardChild = dashboardPageView;
      }
    } else if (responsiveLayoutUtil.shouldRenderMobileUI) {
      dashboardChild = dashboardPageView;
    } else {
      dashboardChild = getIt.get<DesktopSidebarWrapper>();
    }

    return Scaffold(body: dashboardChild);
  }
}

class _DashboardPageView extends BasePage {
  _DashboardPageView({
    required this.bottomSheetService,
    required this.balancePage,
    required this.dashboardViewModel,
    required this.addressListViewModel,
  });

  final BalancePage balancePage;

  @override
  bool get gradientBackground => true;

  @override
  Widget Function(BuildContext, Widget) get rootWrapper =>
      (BuildContext context, Widget scaffold) => GradientBackground(scaffold: scaffold);

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  Widget get endDrawer => MenuWidget(dashboardViewModel);

  @override
  Widget leading(BuildContext context) {
    return Observer(
      builder: (context) {
        return ServicesUpdatesWidget(
          dashboardViewModel.getServicesStatus(),
          enabled: dashboardViewModel.isEnabledBulletinAction,
        );
      },
    );
  }

  @override
  Widget middle(BuildContext context) {
    return SyncIndicator(
      dashboardViewModel: dashboardViewModel,
      onTap: () => Navigator.of(context, rootNavigator: true).pushNamed(Routes.connectionSync),
    );
  }

  @override
  Widget trailing(BuildContext context) {
    final menuButton = Image.asset(
      'assets/images/menu.png',
      color: Theme.of(context).extension<DashboardPageTheme>()!.pageTitleTextColor,
    );

    return Container(
      alignment: Alignment.centerRight,
      width: 40,
      child: TextButton(
        // FIX-ME: Style
        //highlightColor: Colors.transparent,
        //splashColor: Colors.transparent,
        //padding: EdgeInsets.all(0),
        onPressed: () => onOpenEndDrawer(),
        child: Semantics(label: S.of(context).wallet_menu, child: menuButton),
      ),
    );
  }

  final DashboardViewModel dashboardViewModel;
  final BottomSheetService bottomSheetService;
  final WalletAddressListViewModel addressListViewModel;

  int get initialPage => dashboardViewModel.shouldShowMarketPlaceInDashboard ? 1 : 0;
  ObservableList<Widget> pages = ObservableList<Widget>();
  bool _isEffectsInstalled = false;
  StreamSubscription<bool>? _onInactiveSub;

  @override
  Widget body(BuildContext context) {
    final controller = PageController(initialPage: initialPage);

    reaction(
      (_) => dashboardViewModel.shouldShowMarketPlaceInDashboard,
      (bool value) {
        if (!dashboardViewModel.shouldShowMarketPlaceInDashboard) {
          controller.jumpToPage(0);
        }
        pages.clear();
        _isEffectsInstalled = false;
        _setEffects(context);

        if (value) {
          controller.jumpToPage(1);
        } else {
          controller.jumpToPage(0);
        }
      },
    );
    _setEffects(context);

    return SafeArea(
      minimum: EdgeInsets.only(bottom: 24),
      child: BottomSheetListener(
        bottomSheetService: bottomSheetService,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              child: Observer(
                builder: (context) {
                  return PageView.builder(
                    controller: controller,
                    itemCount: pages.length,
                    itemBuilder: (context, index) => pages[index],
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 24, top: 10),
              child: Observer(
                builder: (context) {
                  return Semantics(
                    button: false,
                    label: 'Page Indicator',
                    hint: 'Swipe to change page',
                    excludeSemantics: true,
                    child: SmoothPageIndicator(
                      controller: controller,
                      count: pages.length,
                      effect: ColorTransitionEffect(
                        spacing: 6.0,
                        radius: 6.0,
                        dotWidth: 6.0,
                        dotHeight: 6.0,
                        dotColor: Theme.of(context)
                            .extension<DashboardPageTheme>()!
                            .indicatorDotTheme
                            .indicatorColor,
                        activeDotColor: Theme.of(context)
                            .extension<DashboardPageTheme>()!
                            .indicatorDotTheme
                            .activeIndicatorColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            Observer(
              builder: (_) {
                return ClipRect(
                  child: Container(
                    margin: const EdgeInsets.only(left: 16, right: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50.0),
                        border: Border.all(
                          color: Theme.of(context).extension<BalancePageTheme>()!.cardBorderColor,
                          width: 1,
                        ),
                        color: Theme.of(context)
                            .extension<SyncIndicatorTheme>()!
                            .syncedBackgroundColor,
                      ),
                      child: Container(
                        padding: EdgeInsets.only(left: 24, right: 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: MainActions.all
                              .where((element) => element.canShow?.call(dashboardViewModel) ?? true)
                              .map(
                                (action) => Semantics(
                                  button: true,
                                  enabled: (action.isEnabled?.call(dashboardViewModel) ?? true),
                                  child: ActionButton(
                                    image: Image.asset(
                                      action.image,
                                      height: 24,
                                      width: 24,
                                      color: action.isEnabled?.call(dashboardViewModel) ?? true
                                          ? Theme.of(context)
                                              .extension<DashboardPageTheme>()!
                                              .mainActionsIconColor
                                          : Theme.of(context)
                                              .extension<BalancePageTheme>()!
                                              .labelTextColor,
                                    ),
                                    title: action.name(context),
                                    onClick: () async =>
                                        await action.onTap(context, dashboardViewModel),
                                    textColor: action.isEnabled?.call(dashboardViewModel) ?? true
                                        ? null
                                        : Theme.of(context)
                                            .extension<BalancePageTheme>()!
                                            .labelTextColor,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setEffects(BuildContext context) async {
    if (_isEffectsInstalled) {
      return;
    }
    if (dashboardViewModel.shouldShowMarketPlaceInDashboard) {
      pages.add(
        Semantics(
          label: 'Cake ${S.of(context).features}',
          child: CakeFeaturesPage(
            dashboardViewModel: dashboardViewModel,
            cakeFeaturesViewModel: getIt.get<CakeFeaturesViewModel>(),
          ),
        ),
      );
    }
    pages.add(Semantics(label: S.of(context).balance_page, child: balancePage));
    pages.add(
      Semantics(
        label: S.of(context).settings_transactions,
        child: TransactionsPage(dashboardViewModel: dashboardViewModel),
      ),
    );
    _isEffectsInstalled = true;

    _showReleaseNotesPopup(context);

    _showVulnerableSeedsPopup(context);

    _showHavenPopup(context);

    var needToPresentYat = false;
    var isInactive = false;

    _onInactiveSub = rootKey.currentState?.isInactive.listen(
      (inactive) {
        isInactive = inactive;

        if (needToPresentYat) {
          Future<void>.delayed(Duration(milliseconds: 500)).then(
            (_) {
              showPopUp<void>(
                context: navigatorKey.currentContext!,
                builder: (_) => YatEmojiId(dashboardViewModel.yatStore.emoji),
              );
              needToPresentYat = false;
            },
          );
        }
      },
    );

    dashboardViewModel.yatStore.emojiIncommingStream.listen(
      (String emoji) {
        if (!_isEffectsInstalled || emoji.isEmpty) {
          return;
        }

        needToPresentYat = true;
      },
    );
  }

  void _showReleaseNotesPopup(BuildContext context) async {
    final sharedPrefs = await SharedPreferences.getInstance();
    final currentAppVersion =
        VersionComparator.getExtendedVersionNumber(dashboardViewModel.settingsStore.appVersion);
    final lastSeenAppVersion = sharedPrefs.getInt(PreferencesKey.lastSeenAppVersion);
    final isNewInstall = sharedPrefs.getBool(PreferencesKey.isNewInstall);

    if (currentAppVersion != lastSeenAppVersion && !isNewInstall!) {
      Future<void>.delayed(
        Duration(seconds: 1),
        () {
          showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return ReleaseNotesScreen(
                title: 'Version ${dashboardViewModel.settingsStore.appVersion}',
              );
            },
          );
        },
      );

      sharedPrefs.setInt(PreferencesKey.lastSeenAppVersion, currentAppVersion);
    } else if (isNewInstall!) {
      sharedPrefs.setInt(PreferencesKey.lastSeenAppVersion, currentAppVersion);
    }
  }

  void _showVulnerableSeedsPopup(BuildContext context) async {
    final List<String> affectedWalletNames = await dashboardViewModel.checkAffectedWallets();

    if (affectedWalletNames.isNotEmpty) {
      Future<void>.delayed(
        Duration(seconds: 1),
        () {
          showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return VulnerableSeedsPopup(affectedWalletNames);
            },
          );
        },
      );
    }
  }

  void _showHavenPopup(BuildContext context) async {
    final List<String> havenWalletList = await dashboardViewModel.checkForHavenWallets();

    if (havenWalletList.isNotEmpty) {
      Future<void>.delayed(
        Duration(seconds: 1),
        () {
          showPopUp<void>(
            context: context,
            builder: (BuildContext context) {
              return HavenWalletRemovalPopup(havenWalletList);
            },
          );
        },
      );
    }
  }
}
