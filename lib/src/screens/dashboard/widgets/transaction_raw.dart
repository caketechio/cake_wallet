import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:flutter/material.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:cake_wallet/themes/extensions/transaction_trade_theme.dart';

class TransactionRow extends StatelessWidget {
  TransactionRow({
    required this.direction,
    required this.formattedDate,
    required this.formattedAmount,
    required this.formattedFiatAmount,
    required this.tags,
    required this.title,
    required this.onTap,
    super.key,
  });

  final VoidCallback onTap;
  final TransactionDirection direction;
  final String formattedDate;
  final String formattedAmount;
  final String formattedFiatAmount;
  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).extension<TransactionTradeTheme>()!.rowsColor),
              child: Image.asset(direction == TransactionDirection.incoming
                  ? 'assets/images/down_arrow.png'
                  : 'assets/images/up_arrow.png'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                            )),
                        ...tags.map((tag) => Row(children: [SizedBox(width: 8), TxTag(tag: tag)])),
                      ],
                    ),
                    Text(formattedAmount,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(formattedDate,
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .extension<CakeTextTheme>()!
                                  .dateSectionRowColor)),
                      Text(
                        formattedFiatAmount,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).extension<CakeTextTheme>()!.dateSectionRowColor,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// A tag to add context to a transaction
// example use: differ silent payments from regular txs
class TxTag extends StatelessWidget {
  TxTag({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 17,
      padding: EdgeInsets.only(left: 6, right: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8.5)),
        color: Theme.of(context).extension<TransactionTradeTheme>()!.rowsColor,
      ),
      alignment: Alignment.center,
      child: Text(
        tag.toLowerCase(),
        style: TextStyle(
          color: Theme.of(context).extension<DashboardPageTheme>()!.textColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
