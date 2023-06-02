import 'package:cake_wallet/src/screens/dashboard/widgets/anonpay_transaction_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/order_row.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/dashboard/anonpay_transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/order_list_item.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/header_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/date_section_raw.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/trade_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/transaction_raw.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/date_section_item.dart';
import 'package:intl/intl.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';

class TransactionsPage extends StatelessWidget {
  TransactionsPage({required this.dashboardViewModel});

  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ResponsiveLayoutUtil.instance.isMobile(context)
          ? null
          : Theme.of(context).colorScheme.background,
      padding: EdgeInsets.only(top: 24, bottom: 24),
      child: Column(
        children: <Widget>[
          HeaderRow(dashboardViewModel: dashboardViewModel),
          Expanded(child: Observer(builder: (_) {
            final items = dashboardViewModel.items;

            return items.isNotEmpty
                ? ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      if (item is DateSectionItem) {
                        return DateSectionRaw(date: item.date);
                      }

                      if (item is TransactionListItem) {
                        final transaction = item.transaction;

                        return Observer(
                            builder: (_) => TransactionRow(
                                onTap: () => Navigator.of(context)
                                    .pushNamed(Routes.transactionDetails, arguments: transaction),
                                icon: transaction.direction.iconPath ?? '',
                                formattedDate: DateFormat('HH:mm').format(transaction.date),
                                formattedAmount: item.formattedCryptoAmount,
                                formattedFiatAmount:
                                    dashboardViewModel.balanceViewModel.isFiatDisabled
                                        ? ''
                                        : item.formattedFiatAmount,
                                isPending: transaction.isPending,
                                title: item.formattedTitle + item.formattedStatus
                                    + item.formattedLockedStatus));
                      }

                      if (item is AnonpayTransactionListItem) {
                        final transactionInfo = item.transaction;

                        return AnonpayTransactionRow(
                          onTap: () => Navigator.of(context)
                              .pushNamed(Routes.anonPayDetailsPage, arguments: transactionInfo),
                          currency: transactionInfo.fiatAmount != null
                              ? transactionInfo.fiatEquiv ?? ''
                              : CryptoCurrency.fromFullName(transactionInfo.coinTo)
                                  .name
                                  .toUpperCase(),
                          provider: transactionInfo.provider,
                          amount: transactionInfo.fiatAmount?.toString() ??
                              (transactionInfo.amountTo?.toString() ?? ''),
                          createdAt: DateFormat('HH:mm').format(transactionInfo.createdAt),
                        );
                      }

                      if (item is TradeListItem) {
                        final trade = item.trade;

                        return Observer(
                            builder: (_) => TradeRow(
                                onTap: () => Navigator.of(context)
                                    .pushNamed(Routes.tradeDetails, arguments: trade),
                                provider: trade.provider,
                                from: trade.from,
                                to: trade.to,
                                createdAtFormattedDate: trade.createdAt != null
                                    ? DateFormat('HH:mm').format(trade.createdAt!)
                                    : null,
                                formattedAmount: item.tradeFormattedAmount));
                      }

                      if (item is OrderListItem) {
                        final order = item.order;

                        return Observer(
                            builder: (_) => OrderRow(
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(Routes.orderDetails, arguments: order),
                                  provider: order.provider,
                                  from: order.from!,
                                  to: order.to!,
                                  createdAtFormattedDate:
                                      DateFormat('HH:mm').format(order.createdAt),
                                  formattedAmount: item.orderFormattedAmount,
                                ));
                      }

                      return Container(color: Colors.transparent, height: 1);
                    })
                : Center(
                    child: Text(
                      S.of(context).placeholder_transactions,
                      style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryTextTheme!.labelSmall!.decorationColor!),
                    ),
                  );
          }))
        ],
      ),
    );
  }
}
