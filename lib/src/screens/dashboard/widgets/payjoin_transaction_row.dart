import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';
import 'package:flutter/material.dart';

class PayjoinTransactionRow extends StatelessWidget {
  PayjoinTransactionRow({
    required this.createdAt,
    required this.currency,
    required this.onTap,
    required this.amount,
    required this.state,
    required this.isSending,
    super.key,
  });

  final VoidCallback? onTap;
  final String createdAt;
  final String amount;
  final String currency;
  final String state;
  final bool isSending;

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
              _getImage(),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          "${isSending ? S.current.outgoing : S.current.incoming} Payjoin",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .extension<DashboardPageTheme>()!
                                .textColor,
                          ),
                        ),
                        Text(
                          amount + ' ' + currency,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .extension<DashboardPageTheme>()!
                                .textColor,
                          ),
                        )
                      ]),
                  SizedBox(height: 5),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .extension<CakeTextTheme>()!
                                .dateSectionRowColor,
                          ),
                        ),
                        Text(
                          state,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .extension<CakeTextTheme>()!
                                .dateSectionRowColor,
                          ),
                        ),
                      ])
                ],
              ))
            ],
          ),
        ));
  }

  Widget _getImage() => ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: Image.asset('assets/images/payjoin.png', width: 36, height: 36));

}
