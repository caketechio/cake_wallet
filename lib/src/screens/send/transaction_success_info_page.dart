import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/Info_page.dart';
import 'package:flutter/cupertino.dart';

class TransactionSuccessPage extends InfoPage {
  TransactionSuccessPage({required this.content})
      : super(
          imageLightPath: 'assets/images/birthday_cake.png',
          imageDarkPath: 'assets/images/birthday_cake.png',
        );

  final String content;

  @override
  bool get onWillPop => false;

  @override
  String get pageTitle => 'Transaction Sent Successfully';

  @override
  String get pageDescription => content;

  @override
  String get buttonText => S.current.ok;

  @override
  Key? get buttonKey => ValueKey('transaction_success_info_page_button_key');

  @override
  void Function(BuildContext) get onPressed => (BuildContext context) {
        if (context.mounted) Navigator.of(context).pop();
      };
}
