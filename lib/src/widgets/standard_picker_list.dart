import 'package:cake_wallet/src/widgets/list_row.dart';
import 'package:cake_wallet/src/widgets/picker.dart';
import 'package:cake_wallet/themes/extensions/picker_theme.dart';
import 'package:flutter/material.dart';

class StandardPickerList<T> extends StatefulWidget {
  StandardPickerList({
    Key? key,
    required this.title,
    required this.value,
    required this.items,
    required this.displayItem,
    required this.onSliderChanged,
    required this.onItemSelected,
    required this.selectedIdx,
    required this.customItemIndex,
    required this.customValue,
  }) : super(key: key);

  final String title;
  final List<T> items;
  final int customItemIndex;
  final String Function(T item, double sliderValue) displayItem;
  final Function(double) onSliderChanged;
  final Function(T) onItemSelected;
  String value;
  int selectedIdx;
  double customValue;

  @override
  _StandardPickerListState<T> createState() => _StandardPickerListState<T>();
}

class _StandardPickerListState<T> extends State<StandardPickerList<T>> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    String adaptedDisplayItem(T item) => widget.displayItem(item, widget.customValue);

    return Column(
      children: [
        ListRow(title: '${widget.title}:', value: widget.value),
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 24),
          child: Picker(
            items: widget.items,
            displayItem: adaptedDisplayItem,
            selectedAtIndex: widget.selectedIdx,
            customItemIndex: widget.customItemIndex,
            headerEnabled: false,
            closeOnItemSelected: false,
            mainAxisAlignment: MainAxisAlignment.center,
            sliderValue: widget.customValue,
            isWrapped: false,
            borderColor: Theme.of(context).extension<PickerTheme>()!.dividerColor,
            onSliderChanged: (newValue) {
              setState(() => widget.customValue = newValue);
              widget.value = widget.onSliderChanged(newValue).toString();
            },
            onItemSelected: (T item) {
              setState(() => widget.selectedIdx = widget.items.indexOf(item));
              widget.value = widget.onItemSelected(item).toString();
            },
          ),
        ),
      ],
    );
  }
}
