import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/utils/image_utill.dart';
import 'package:flutter/material.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/themes/extensions/dashboard_page_theme.dart';

class TradeRow extends StatelessWidget {
  TradeRow({
    required this.provider,
    required this.from,
    required this.to,
    required this.createdAtFormattedDate,
    this.onTap,
    this.formattedAmount,
    this.formattedReceiveAmount,
    super.key,
  });

  final VoidCallback? onTap;
  final ExchangeProviderDescription provider;
  final CryptoCurrency from;
  final CryptoCurrency to;
  final String? createdAtFormattedDate;
  final String? formattedAmount;
  final String? formattedReceiveAmount;

  @override
  Widget build(BuildContext context) {
    final amountCrypto = from.toString();
    final receiveAmountCrypto = to.toString();

    return InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: ImageUtil.getImageFromPath(
                      imagePath: provider.image, height: 36, width: 36)),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    Text('${from.toString()} → ${to.toString()}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).extension<DashboardPageTheme>()!.textColor)),
                    formattedAmount != null
                        ? Text(formattedAmount! + ' ' + amountCrypto,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color:
                                    Theme.of(context).extension<DashboardPageTheme>()!.textColor))
                        : Container()
                  ]),
                  SizedBox(height: 5),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: <Widget>[
                        createdAtFormattedDate != null
                          ? Text(createdAtFormattedDate!,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).extension<CakeTextTheme>()!.dateSectionRowColor))
                          : Container(),
                        formattedReceiveAmount != null
                          ? Text(formattedReceiveAmount! + ' ' + receiveAmountCrypto,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).extension<CakeTextTheme>()!.dateSectionRowColor))
                          : Container(),
                  ])
                ],
              ))
            ],
          ),
        ));
  }
}
