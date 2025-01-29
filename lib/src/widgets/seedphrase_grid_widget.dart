import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:flutter/material.dart';

class SeedPhraseGridWidget extends StatelessWidget {
  const SeedPhraseGridWidget({
    super.key,
    required this.list,
  });

  final List<String> list;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: list.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.8,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      ),
      itemBuilder: (context, index) {
        final item = list[index];
        final numberCount = index + 1;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                child: Text(
                  //maxLines: 1,
                  numberCount.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context)
                          .extension<CakeTextTheme>()!
                          .buttonTextColor
                          .withOpacity(0.5)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item[0].toLowerCase()}${item.substring(1)}',
                  style: TextStyle(
                      fontSize: 14,
                      height: 0.8,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).extension<CakeTextTheme>()!.buttonTextColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
