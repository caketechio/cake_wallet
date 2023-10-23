import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:flutter/material.dart';

class DropDownItemWidget<ImageItem extends Widget> extends StatelessWidget {
  const DropDownItemWidget({super.key, required this.title, required this.image});
  final double tileHeight = 60;
  final ImageItem image;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tileHeight,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          image,
          SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          )
        ],
      ),
    );
  }
}
