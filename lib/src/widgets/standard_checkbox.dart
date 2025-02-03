import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/filter_theme.dart';
import 'package:flutter/material.dart';

class StandardCheckbox extends StatelessWidget {
  StandardCheckbox(
      {required this.value,
      this.caption = '',
      this.gradientBackground = false,
      this.borderColor,
      this.iconColor,
      required this.onChanged});

  final bool value;
  final String caption;
  final bool gradientBackground;
  final Color? borderColor;
  final Color? iconColor;
  final Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    final baseGradient = LinearGradient(colors: [
      Theme.of(context).extension<FilterTheme>()!.checkboxFirstGradientColor,
      Theme.of(context).extension<FilterTheme>()!.checkboxSecondGradientColor,
    ], begin: Alignment.centerLeft, end: Alignment.centerRight);

    final boxBorder = Border.all(
      color: borderColor ?? Theme.of(context).extension<CakeTextTheme>()!.secondaryTextColor,
      width: 1.0,
    );

    final checkedBoxDecoration = BoxDecoration(
        gradient: gradientBackground ? baseGradient : null,
        border: gradientBackground ? null : boxBorder,
        borderRadius: BorderRadius.all(Radius.circular(8.0)));

    final uncheckedBoxDecoration =
        BoxDecoration(border: boxBorder, borderRadius: BorderRadius.all(Radius.circular(8.0)));

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 24.0,
            width: 24.0,
            decoration: value ? checkedBoxDecoration : uncheckedBoxDecoration,
            child: value
                ? Icon(
                    Icons.check,
                    color: iconColor ?? Theme.of(context).primaryColor,
                    size: 20.0,
                  )
                : Offstage(),
          ),
          if (caption.isNotEmpty)
            Flexible(
              child: Padding(
                padding: EdgeInsets.only(left: 10),
                child: Text(
                  caption,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
