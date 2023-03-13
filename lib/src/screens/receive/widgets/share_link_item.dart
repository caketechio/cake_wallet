import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/typography.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareLinkItem extends StatelessWidget {
  const ShareLinkItem({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final copyImage = Image.asset('assets/images/copy_address.png',
        color: Theme.of(context).accentTextTheme.headline2!.backgroundColor!);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: textMedium(
            color: Theme.of(context).accentTextTheme.headline2!.backgroundColor!,
          ),
        ),
        SizedBox(width: 50),
        Row(
          children: [
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                showBar<void>(context, S.of(context).copied_to_clipboard);
              },
              child: copyImage,
            ),
            SizedBox(width: 20),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              iconSize: 25,
              onPressed: () => Share.share(url),
              icon: Icon(
                Icons.share,
                color: Theme.of(context).accentTextTheme.headline2!.backgroundColor!,
              ),
            )
          ],
        )
      ],
    );
  }
}
