import 'package:cake_wallet/entities/qr_view_data.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/seedphrase_grid_widget.dart';
import 'package:cake_wallet/src/widgets/text_info_box.dart';
import 'package:cake_wallet/src/widgets/warning_box_widget.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/brightness_util.dart';
import 'package:cake_wallet/utils/clipboard_util.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/wallet_keys_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletKeysPage extends BasePage {
  WalletKeysPage(this.walletKeysViewModel);

  @override
  String get title => walletKeysViewModel.title;

  final WalletKeysViewModel walletKeysViewModel;

  @override
  Widget body(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          WarningBox(
            key: const ValueKey('wallet_keys_page_share_warning_text_key'),
            content: S.of(context).do_not_share_warning_text.toUpperCase(),
            currentTheme: currentTheme,
          ),
          Expanded(
            child: WalletKeysPageBody(
              walletKeysViewModel: walletKeysViewModel,
              currentTheme: currentTheme,
            ),
          ),
        ],
      ),
    );
  }
}

class WalletKeysPageBody extends StatefulWidget {
  WalletKeysPageBody({
    required this.walletKeysViewModel,
    required this.currentTheme,
  });

  final WalletKeysViewModel walletKeysViewModel;
  final ThemeBase currentTheme;

  @override
  State<StatefulWidget> createState() => _WalletKeysPageBodyState();
}

class _WalletKeysPageBodyState extends State<WalletKeysPageBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.walletKeysViewModel.legacySeedSplit.isNotEmpty ? 3 : 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLegacySeedExist = widget.walletKeysViewModel.legacySeedSplit.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            splashFactory: NoSplash.splashFactory,
            indicatorSize: TabBarIndicatorSize.label,
            isScrollable: true,
            labelStyle: TextStyle(
              fontSize: 18,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).appBarTheme.titleTextStyle!.color,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 18,
              fontFamily: 'Lato',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).appBarTheme.titleTextStyle!.color?.withOpacity(0.5),
            ),
            labelColor: Theme.of(context).appBarTheme.titleTextStyle!.color,
            indicatorColor: Theme.of(context).appBarTheme.titleTextStyle!.color,
            indicatorPadding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(right: 24),
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            padding: EdgeInsets.zero,
            tabs: [
              const Tab(text: 'Seed'),
              const Tab(text: 'Keys'),
              if (isLegacySeedExist) const Tab(text: 'Legacy'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildSeedTab(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildKeysTab(context),
                ),
                if (isLegacySeedExist) _buildLegacySeedTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SeedPhraseGridWidget(
            list: widget.walletKeysViewModel.seedSplit,
          ),
        ),
        const SizedBox(height: 10),
        _buildBottomActionPanel(
          titleForClipboard: S.of(context).wallet_seed.toLowerCase(),
          dataToCopy: widget.walletKeysViewModel.seed,
          onShowQR: () async => _showQR(context, false),
        ),
      ],
    );
  }

  Widget _buildKeysTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.walletKeysViewModel.items.length,
            itemBuilder: (context, index) {
              final item = widget.walletKeysViewModel.items[index];
              return TextInfoBox(
                key: item.key,
                title: item.title,
                value: item.value,
                onCopy: (context) => _onCopy(item.title, item.value, context),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(height: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLegacySeedTab(BuildContext context) {
    return Column(
      children: [
        _buildHeightBox(),
        const SizedBox(height: 20),
        Expanded(
          child: SeedPhraseGridWidget(
            list: widget.walletKeysViewModel.legacySeedSplit,
          ),
        ),
        const SizedBox(height: 10),
        _buildBottomActionPanel(
          titleForClipboard: S.of(context).wallet_seed.toLowerCase(),
          dataToCopy: widget.walletKeysViewModel.legacySeed,
          onShowQR: () async => _showQR(context, true),
        ),
      ],
    );
  }

  Widget _buildHeightBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Block height',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
            widget.walletKeysViewModel.legacyRestoreHeight,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBottomActionPanel({
    required String titleForClipboard,
    required String dataToCopy,
    required VoidCallback onShowQR,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: PrimaryButton(
                  key: const ValueKey('wallet_keys_page_copy_seeds_button_key'),
                  onPressed: () => _onCopy(titleForClipboard, dataToCopy, context),
                  text: S.of(context).copy,
                  color: Theme.of(context).cardColor,
                  textColor: widget.currentTheme.type == ThemeType.dark
                      ? Theme.of(context).extension<DashboardPageTheme>()!.textColor
                      : Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor,
                ),
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: PrimaryButton(
                  key: const ValueKey('wallet_keys_page_show_qr_seeds_button_key'),
                  onPressed: onShowQR,
                  text: S.current.show + ' QR',
                  color: Theme.of(context).primaryColor,
                  textColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _onCopy(String title, String text, BuildContext context) async {
    await ClipboardUtil.setSensitiveDataToClipboard(ClipboardData(text: text));
    showBar<void>(context, S.of(context).copied_key_to_clipboard(title));
  }

  Future<void> _showQR(BuildContext context, bool isLegacySeed) async {
    final url = await widget.walletKeysViewModel.getUrl(isLegacySeed);

    BrightnessUtil.changeBrightnessForFunction(() async {
      await Navigator.pushNamed(
        context,
        Routes.fullscreenQR,
        arguments: QrViewData(data: url.toString(), version: QrVersions.auto),
      );
    });
  }
}
