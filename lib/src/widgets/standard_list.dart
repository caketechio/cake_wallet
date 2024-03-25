import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/src/widgets/standard_list_card.dart';
import 'package:cake_wallet/src/widgets/standard_list_status_row.dart';
import 'package:flutter/material.dart';

class StandardListRow extends StatelessWidget {
  StandardListRow({required this.title, required this.isSelected, this.onTap, this.decoration});

  final String title;
  final bool isSelected;
  final void Function(BuildContext context)? onTap;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    final leading = buildLeading(context);
    final trailing = buildTrailing(context);

    final base = Container(
      height: 56,
      padding: EdgeInsets.only(left: 24, right: 24),
      decoration: decoration ??
          BoxDecoration(
            color: Theme.of(context).colorScheme.background,
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (leading != null) leading,
          buildCenter(context, hasLeftOffset: leading != null),
          if (trailing != null) trailing,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () => onTap?.call(context),
        child: base,
      );
    } else {
      return base;
    }
  }

  Widget? buildLeading(BuildContext context) => null;

  Widget buildCenter(BuildContext context, {required bool hasLeftOffset}) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (hasLeftOffset) SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: titleColor(context),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget? buildTrailing(BuildContext context) => null;

  Color titleColor(BuildContext context) => isSelected
      ? Theme.of(context).primaryColor
      : Theme.of(context).extension<CakeTextTheme>()!.titleColor;
}

class SectionHeaderListRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        StandardListSeparator(padding: EdgeInsets.only(left: 24)),
        Container(
          width: double.infinity,
          height: 40,
          color: Theme.of(context).colorScheme.background,
        ),
        //StandardListSeparator(padding: EdgeInsets.only(left: 24))
      ]);
}

class StandardListSeparator extends StatelessWidget {
  const StandardListSeparator({this.padding, this.height = 1});

  final EdgeInsets? padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      color: Theme.of(context).colorScheme.background,
      child: Container(
        height: height,
        color: Theme.of(context).extension<CakeTextTheme>()!.textfieldUnderlineColor,
      ),
    );
  }
}

class StandardList extends StatelessWidget {
  StandardList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        separatorBuilder: (_, __) => StandardListSeparator(padding: EdgeInsets.only(left: 24)),
        itemCount: itemCount,
        itemBuilder: itemBuilder);
  }
}

class SectionStandardListItem {
  SectionStandardListItem({this.hasFullSeparator = false, required this.child});

  final bool hasFullSeparator;
  final Widget child;
}

class SectionStandardList extends StatelessWidget {
  SectionStandardList({
    required this.itemCounter,
    required this.itemBuilder,
    required this.sectionCount,
    this.dividerPadding = const EdgeInsets.only(left: 24),
    this.sectionTitleBuilder,
    this.hasTopSeparator = false,
  }) : totalRows = [];

  final int sectionCount;
  final bool hasTopSeparator;
  final int Function(int sectionIndex) itemCounter;
  final Widget Function(int sectionIndex, int itemIndex) itemBuilder;
  final Widget Function(int sectionIndex)? sectionTitleBuilder;
  final List<Widget> totalRows;
  final EdgeInsets dividerPadding;

  List<Widget> transform(
      bool hasTopSeparator,
      int sectionCount,
      int Function(int sectionIndex) itemCounter,
      Widget Function(int sectionIndex, int itemIndex) itemBuilder,
      Widget Function(int sectionIndex)? sectionTitleBuilder) {
    final items = <Widget>[];

    for (var sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++) {
      if ((sectionIndex == 0) && (hasTopSeparator)) {
        items.add(StandardListSeparator(padding: EdgeInsets.only(left: 24)));
      }

      if (sectionTitleBuilder != null) {
        items.add(buildTitle(items, sectionIndex));
      }

      final itemCount = itemCounter(sectionIndex);

      items.addAll(buildSection(itemCount, items, sectionIndex));

      items.add(sectionIndex + 1 != sectionCount
          ? SectionHeaderListRow()
          : StandardListSeparator(padding: dividerPadding));
    }

    return items;
  }

  Widget buildTitle(List<Widget> items, int sectionIndex) {
    if (sectionTitleBuilder == null) {
      throw Exception('Cannot to build title. sectionTitleBuilder is null');
    }

    return sectionTitleBuilder!.call(sectionIndex);
  }

  List<Widget> buildSection(int itemCount, List<Widget> items, int sectionIndex) {
    final List<Widget> section = [];

    for (var itemIndex = 0; itemIndex < itemCount; itemIndex++) {
      final item = itemBuilder(sectionIndex, itemIndex);

      section.add(item);
    }
    return section;
  }

  @override
  Widget build(BuildContext context) {
    totalRows.clear();
    totalRows.addAll(
        transform(hasTopSeparator, sectionCount, itemCounter, itemBuilder, sectionTitleBuilder));

    return ListView.separated(
      separatorBuilder: (_, index) {
        final row = totalRows[index];

        if (row is StandardListSeparator || row is SectionHeaderListRow) {
          return Container();
        }

        if (row is StandardListStatusRow || row is TradeDetailsStandardListCard) {
          return Container();
        }

        final nextRow = totalRows[index + 1];

        // If current row is pre last and last row is separator.
        if (nextRow is StandardListSeparator || nextRow is SectionHeaderListRow) {
          return Container();
        }

        return StandardListSeparator(padding: dividerPadding);
      },
      itemCount: totalRows.length,
      itemBuilder: (_, index) => totalRows[index],
    );
  }
}
