import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/anonpay_transaction_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/order_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/payjoin_transaction_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/trade_row.dart';
import 'package:cake_wallet/themes/extensions/placeholder_theme.dart';
import 'package:cake_wallet/src/widgets/dashboard_card_widget.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/dashboard/anonpay_transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/order_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/payjoin_transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/header_row.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/date_section_raw.dart';
import 'package:cake_wallet/src/screens/dashboard/widgets/transaction_raw.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/date_section_item.dart';
import 'package:intl/intl.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionsPage extends StatelessWidget {
  TransactionsPage({required this.dashboardViewModel});

  final DashboardViewModel dashboardViewModel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => dashboardViewModel.balanceViewModel.isReversing =
          !dashboardViewModel.balanceViewModel.isReversing,
      onLongPressUp: () => dashboardViewModel.balanceViewModel.isReversing =
          !dashboardViewModel.balanceViewModel.isReversing,
      child: Container(
        color: responsiveLayoutUtil.shouldRenderMobileUI
            ? null
            : Theme.of(context).colorScheme.background,
        padding: EdgeInsets.only(top: 24, bottom: 24),
        child: Column(
          children: <Widget>[
            Observer(builder: (_) {
              final status = dashboardViewModel.status;
              if (status is SyncingSyncStatus) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: DashBoardRoundedCardWidget(
                    key: ValueKey('transactions_page_syncing_alert_card_key'),
                    onTap: () {
                      try {
                        final uri = Uri.parse(
                            "https://docs.cakewallet.com/faq/funds-not-appearing");
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    title: S.of(context).syncing_wallet_alert_title,
                    subTitle: S.of(context).syncing_wallet_alert_content,
                  ),
                );
              } else {
                return Container();
              }
            }),
            HeaderRow(
              dashboardViewModel: dashboardViewModel,
              key: ValueKey('transactions_page_header_row_key'),
            ),
            Expanded(
              child: Observer(
                builder: (_) {
                  final items = dashboardViewModel.items;

                  return items.isNotEmpty
                      ? ListView.builder(
                          key: ValueKey('transactions_page_list_view_builder_key'),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];

                            if (item is DateSectionItem) {
                              return DateSectionRaw(date: item.date, key: item.key);
                            }

                            if (item is TransactionListItem) {
                              if (item.hasTokens && item.assetOfTransaction == null) {
                                return Container();
                              }

                              final transaction = item.transaction;
                              final transactionType =
                                  dashboardViewModel.getTransactionType(transaction);

                              List<String> tags = [];
                              if (dashboardViewModel.type == WalletType.bitcoin) {
                                if (bitcoin!.txIsReceivedSilentPayment(transaction)) {
                                  tags.add(S.of(context).silent_payment);
                                }
                              }
                              if (dashboardViewModel.type == WalletType.litecoin) {
                                if (bitcoin!.txIsMweb(transaction)) {
                                  tags.add("MWEB");
                                }
                              }

                              return Observer(
                                builder: (_) => TransactionRow(
                                  key: item.key,
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(Routes.transactionDetails, arguments: transaction),
                                  direction: transaction.direction,
                                  formattedDate: DateFormat('HH:mm').format(transaction.date),
                                  formattedAmount: item.formattedCryptoAmount,
                                  formattedFiatAmount:
                                      dashboardViewModel.balanceViewModel.isFiatDisabled
                                          ? ''
                                          : item.formattedFiatAmount,
                                  title:
                                      item.formattedTitle + item.formattedStatus + transactionType,
                                  tags: tags,
                                ),
                              );
                            }

                            if (item is AnonpayTransactionListItem) {
                              final transactionInfo = item.transaction;

                              return AnonpayTransactionRow(
                                key: item.key,
                                onTap: () => Navigator.of(context).pushNamed(
                                    Routes.anonPayDetailsPage,
                                    arguments: transactionInfo),
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

                            if (item is PayjoinTransactionListItem) {
                              final session = item.session;

                              return PayjoinTransactionRow(
                                key: item.key,
                                onTap: () => Navigator.of(context).pushNamed(
                                    Routes.payjoinDetails,
                                    arguments: item.sessionId),
                                currency: "BTC",
                                state: session.status,
                                amount: bitcoin!.formatterBitcoinAmountToString(
                                    amount: session.amount.toInt()),
                                createdAt: DateFormat('HH:mm')
                                    .format(session.inProgressSince!),
                                isSending: session.isSenderSession,
                              );
                            }

                            if (item is TradeListItem) {
                              final trade = item.trade;

                              return Observer(
                                builder: (_) => TradeRow(
                                  key: item.key,
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(Routes.tradeDetails, arguments: trade),
                                  provider: trade.provider,
                                  from: trade.from,
                                  to: trade.to,
                                  createdAtFormattedDate: trade.createdAt != null
                                      ? DateFormat('HH:mm').format(trade.createdAt!)
                                      : null,
                                  formattedAmount: item.tradeFormattedAmount, 
                                  formattedReceiveAmount: item.tradeFormattedReceiveAmount
                                ),
                              );
                            }

                            if (item is OrderListItem) {
                              final order = item.order;

                              return Observer(
                                builder: (_) => OrderRow(
                                  key: item.key,
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(Routes.orderDetails, arguments: order),
                                  provider: order.provider,
                                  from: order.from!,
                                  to: order.to!,
                                  createdAtFormattedDate:
                                      DateFormat('HH:mm').format(order.createdAt),
                                  formattedAmount: item.orderFormattedAmount,
                                ),
                              );
                            }

                            return Container(color: Colors.transparent, height: 1);
                          })
                      : Center(
                          child: Text(
                            key: ValueKey('transactions_page_placeholder_transactions_text_key'),
                            S.of(context).placeholder_transactions,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).extension<PlaceholderTheme>()!.color,
                            ),
                          ),
                        );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
