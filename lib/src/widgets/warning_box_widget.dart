import 'package:cake_wallet/themes/theme_base.dart';
import 'package:flutter/material.dart';

class WarningBox extends StatelessWidget {
  const WarningBox({required this.content, required this.currentTheme, Key? key})
      : super(key: key);

  final String content;
  final ThemeBase currentTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: currentTheme.type == ThemeType.dark
              ? Color.fromRGBO(132, 110, 64, 1)
              : Color.fromRGBO(194, 165, 94, 1),
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: currentTheme.type == ThemeType.dark
                ? Color.fromRGBO(177, 147, 41, 1)
                : Color.fromRGBO(125, 122, 15, 1),
            width: 2.0,
          )),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.75),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: currentTheme.type == ThemeType.dark
                    ? Colors.white.withOpacity(0.75)
                    : Colors.white.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
