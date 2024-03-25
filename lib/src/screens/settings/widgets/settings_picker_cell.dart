import 'package:cake_wallet/themes/extensions/transaction_trade_theme.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/src/widgets/standard_list.dart';

class SettingsPickerCell<ItemType> extends StandardListRow {
  SettingsPickerCell(
      {required String title,
      required this.selectedItem,
      required this.items,
      this.displayItem,
      this.images,
      this.searchHintText,
      this.isGridView = false,
      this.matchingCriteria,
      this.onItemSelected,
      this.decoration})
      : super(
          title: title,
          isSelected: false,
          decoration: decoration,
          onTap: (BuildContext context) async {
            final selectedAtIndex = items.indexOf(selectedItem);

            await showPopUp<void>(
              context: context,
              builder: (_) => Picker(
                items: items,
                displayItem: displayItem,
                selectedAtIndex: selectedAtIndex,
                mainAxisAlignment: MainAxisAlignment.start,
                onItemSelected: (ItemType item) => onItemSelected?.call(item),
                images: images ?? const <Image>[],
                isSeparated: false,
                hintText: searchHintText,
                isGridView: isGridView,
                matchingCriteria: matchingCriteria,
              ),
            );
          },
        );

  final ItemType selectedItem;
  final List<ItemType> items;
  final void Function(ItemType item)? onItemSelected;
  final String Function(ItemType item)? displayItem;
  final List<Image>? images;
  final String? searchHintText;
  final bool isGridView;
  final bool Function(ItemType, String)? matchingCriteria;
  final BoxDecoration? decoration;

  @override
  Widget buildTrailing(BuildContext context) {
    return Text(
      displayItem?.call(selectedItem) ?? selectedItem.toString(),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).extension<TransactionTradeTheme>()!.detailsTitlesColor,
      ),
    );
  }
}
