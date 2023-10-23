import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/new_wallet/widgets/select_button.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/widgets/scollable_with_bottom_section.dart';
import 'package:cake_wallet/src/widgets/search_bar_widget.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/theme_base.dart';
import 'package:cake_wallet/utils/icon_from_path.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/wallet_types.g.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NewWalletTypePage extends BasePage {
  NewWalletTypePage({required this.onTypeSelected, required this.isCreate});

  final void Function(BuildContext, WalletType) onTypeSelected;
  final bool isCreate;

  final walletTypeImage = Image.asset('assets/images/wallet_type.png');
  final walletTypeLightImage = Image.asset('assets/images/wallet_type_light.png');

  @override
  String get title =>
      isCreate ? S.current.wallet_list_create_new_wallet : S.current.wallet_list_restore_wallet;

  @override
  Widget body(BuildContext context) => WalletTypeForm(
      onTypeSelected: onTypeSelected,
      walletImage: currentTheme.type == ThemeType.dark ? walletTypeImage : walletTypeLightImage);
}

class WalletTypeForm extends StatefulWidget {
  WalletTypeForm({required this.onTypeSelected, required this.walletImage});

  final void Function(BuildContext, WalletType) onTypeSelected;
  final Image walletImage;

  @override
  WalletTypeFormState createState() => WalletTypeFormState();
}

class WalletTypeFormState extends State<WalletTypeForm> {
  WalletTypeFormState() : types = availableWalletTypes;

  static const aspectRatioImage = 1.22;

  final TextEditingController searchController = TextEditingController();

  WalletType? selected;
  List<WalletType> types;
  List<WalletType> filteredTypes = [];

  @override
  void initState() {
    types = filteredTypes = availableWalletTypes;
    super.initState();

    searchController.addListener(() {
      setState(() {
        filteredTypes = List.from(types.where((type) => walletTypeToDisplayName(type)
            .toLowerCase()
            .contains(searchController.text.toLowerCase())));
        return;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveLayoutUtil.kDesktopMaxWidthConstraint),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Text(
                    S.of(context).choose_wallet_currency,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: SearchBarWidget(searchController: searchController, borderRadius: 24),
                ),
                Expanded(
                  child: ScrollableWithBottomSection(
                    contentPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        ...filteredTypes.map((type) => Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: SelectButton(
                                   image: buildIconFromPath(walletTypeToCryptoCurrency(type).iconPath),
                                  text: walletTypeToDisplayName(type),
                                  showTrailingIcon: false,
                                  height: 54,
                                  isSelected: selected == type,
                                  onTap: () => setState(() => selected = type)),
                            ))
                      ],
                    ),
                    bottomSectionPadding: EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    bottomSection: PrimaryButton(
                      onPressed: () => onTypeSelected(),
                      text: S.of(context).seed_language_next,
                      color: Theme.of(context).primaryColor,
                      textColor: Colors.white,
                      isDisabled: selected == null,
                    ),
                  ),
                ),
              ],
            )));
  }

  Future<void> onTypeSelected() async {
    if (selected == null) {
      throw Exception('Wallet Type is not selected yet.');
    }

    widget.onTypeSelected(context, selected!);
  }
}
