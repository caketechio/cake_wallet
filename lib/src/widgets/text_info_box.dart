import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:flutter/material.dart';

class TextInfoBox extends StatelessWidget {
  const TextInfoBox({Key? key, required this.title, required this.value, this.onCopy})
      : super(key: key);

  final String title;
  final String value;
  final void Function(BuildContext context)? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .extension<CakeTextTheme>()!
                          .buttonTextColor
                          .withOpacity(0.5))),
              GestureDetector(
                  onTap: onCopy != null ? () => onCopy!(context) : null,
                  child: Icon(Icons.copy,
                      size: 13,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor)),
        ],
      ),
    );
  }
}
