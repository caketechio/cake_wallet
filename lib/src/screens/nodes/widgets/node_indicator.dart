import 'package:flutter/material.dart';
import 'package:cake_wallet/palette.dart';

class NodeIndicator extends StatelessWidget {
  NodeIndicator({
    this.color = Palette.red,
    this.text = "",
  });

  final Color? color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12.0,
          height: 12.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 8.0),
          Text(
            text,
            style: TextStyle(fontSize: 14.0),
          )
        ],
      ],
    );
  }
}
