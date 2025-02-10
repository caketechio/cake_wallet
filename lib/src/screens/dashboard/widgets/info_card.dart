import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/dashboard_card_widget.dart';
import 'package:cake_wallet/themes/extensions/balance_page_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoCard extends StatelessWidget {
  final String leftButtonTitle;
  final String rightButtonTitle;
  final String title;
  final String description;

  final Function() leftButtonAction;
  final Function() rightButtonAction;

  final Widget? hintWidget;

  const InfoCard({
    Key? key,
    required this.title,
    required this.description,
    required this.leftButtonTitle,
    required this.rightButtonTitle,
    required this.leftButtonAction,
    required this.rightButtonAction,
    this.hintWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DashBoardRoundedCardWidget(
      customBorder: 30,
      title: title,
      subTitle: description,
      hint: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hintWidget != null) hintWidget!,
          if (hintWidget != null) SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: leftButtonAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  child: Text(
                    leftButtonTitle,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: rightButtonAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    rightButtonTitle,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => {},
      icon: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ImageIcon(
          AssetImage('assets/images/mweb_logo.png'),
          color: Color.fromARGB(255, 11, 70, 129),
          size: 40,
        ),
      ),
    );
  }
}
