import 'package:flutter/material.dart';
import 'package:cw_core/transaction_direction.dart';

class TransactionRow extends StatelessWidget {
  TransactionRow(
      {required this.icon,
      required this.formattedDate,
      required this.formattedAmount,
      required this.formattedFiatAmount,
      required this.isPending,
      required this.title,
      required this.onTap});

  final VoidCallback onTap;
  final String icon;
  final String formattedDate;
  final String formattedAmount;
  final String formattedFiatAmount;
  final bool isPending;
  final String title;

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
                    color: Theme.of(context).textTheme!.labelSmall!.decorationColor!
                ),
                child: Image.asset(icon),
              ),
              SizedBox(width: 12),
              Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(title,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).accentTextTheme!
                                        .displayMedium!.backgroundColor!)),
                            Text(formattedAmount,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).accentTextTheme!
                                        .displayMedium!.backgroundColor!))
                          ]),
                      SizedBox(height: 5),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(formattedDate,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .textTheme!
                                        .labelSmall!
                                        .backgroundColor!)),
                            Text(formattedFiatAmount,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .textTheme!
                                        .labelSmall!
                                        .backgroundColor!))
                          ])
                    ],
                  )
              )
            ],
          ),
        ));
  }
}
