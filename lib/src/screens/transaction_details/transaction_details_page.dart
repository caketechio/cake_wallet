import 'package:cake_wallet/src/screens/transaction_details/textfield_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/widgets/textfield_list_row.dart';
import 'package:cake_wallet/src/widgets/standard_list.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/view_model/transactions/transaction_details_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/list_row.dart';
import 'package:cake_wallet/src/screens/transaction_details/blockexplorer_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/utils/date_formatter.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:hive/hive.dart';

class TransactionDetailsPage extends BasePage {
  TransactionDetailsPage({required this.transactionDetailsViewModel});

  @override
  String get title => S.current.transaction_details_title;

  final TransactionDetailsViewModel transactionDetailsViewModel;

  @override
  Widget body(BuildContext context) {
    // FIX-ME: Added `context` it was not used here before, maby bug ?
    return SectionStandardList(
        context: context,
        sectionCount: 1,
        itemCounter: (int _) => transactionDetailsViewModel.items.length,
        itemBuilder: (_, __, index) {
          final item = transactionDetailsViewModel.items[index];

          if (item is StandartListItem) {
            return GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: item.value));
                showBar<void>(context,
                    S.of(context).transaction_details_copied(item.title));
              },
              child:
                  ListRow(title: '${item.title}:', value: item.value),
            );
          }

          if (item is BlockExplorerListItem) {
            return GestureDetector(
              onTap: item.onTap,
              child:
                  ListRow(title: '${item.title}:', value: item.value),
            );
          }

          if (item is TextFieldListItem) {
            return TextFieldListRow(
              title: item.title,
              value: item.value,
              onSubmitted: item.onSubmitted,
            );
          }

          return Container();
        });
  }
}
