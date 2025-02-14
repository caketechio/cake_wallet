import 'package:cake_wallet/core/seed_validator.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/widgets/validable_annotated_editable_text.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/send_page_theme.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SeedWidget extends StatefulWidget {
  SeedWidget({
    required this.language,
    required this.type,
    this.onSeedChange,
    this.pasteButtonKey,
    this.seedTextFieldKey,
    this.initialSeed,
    super.key,
  });
  final Key? seedTextFieldKey;
  final Key? pasteButtonKey;
  final String language;
  final WalletType type;
  final void Function(String)? onSeedChange;
  final String? initialSeed;

  @override
  SeedWidgetState createState() => SeedWidgetState(language, type, initialSeed);
}

class SeedWidgetState extends State<SeedWidget> {
  SeedWidgetState(String language, this.type, String? initialSeed)
      : controller = TextEditingController(text: initialSeed ?? ''),
        focusNode = FocusNode(),
        words = SeedValidator.getWordList(type: type, language: language),
        _showPlaceholder = initialSeed == null || initialSeed.isEmpty {
    focusNode.addListener(() {
      setState(() {
        if (!focusNode.hasFocus && controller.text.isEmpty) {
          _showPlaceholder = true;
        }

        if (focusNode.hasFocus) {
          _showPlaceholder = false;
        }
      });
    });
  }

  final TextEditingController controller;
  final FocusNode focusNode;
  final WalletType type;
  List<String> words;
  bool normalizeSeed = false;
  bool _showPlaceholder;

  String get text => controller.text;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {
        _showPlaceholder = controller.text.isEmpty;
      });
      widget.onSeedChange?.call(text);
    });
  }

  void changeSeedLanguage(String language) {
    setState(() {
      words = SeedValidator.getWordList(type: type, language: language);
      normalizeSeed = SeedValidator.needsNormalization(language);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
          Stack(children: [
            SizedBox(height: 35),
            if (_showPlaceholder)
              Positioned(
                  top: 10,
                  left: 0,
                  child: Text(S.of(context).enter_seed_phrase,
                      style: TextStyle(fontSize: 16.0, color: Theme.of(context).hintColor))),
            Padding(
                padding: EdgeInsets.only(right: 40, top: 10),
                child: ValidatableAnnotatedEditableText(
                  key: widget.seedTextFieldKey,
                  cursorColor: Colors.blue,
                  backgroundCursorColor: Colors.blue,
                  validStyle: TextStyle(
                      color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                      backgroundColor: Colors.transparent,
                      fontWeight: FontWeight.normal,
                      fontSize: 16),
                  invalidStyle: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.normal,
                      backgroundColor: Colors.transparent),
                  focusNode: focusNode,
                  controller: controller,
                  words: words,
                  normalizeSeed: normalizeSeed,
                  textStyle: TextStyle(
                      color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                      backgroundColor: Colors.transparent,
                      fontWeight: FontWeight.normal,
                      fontSize: 16),
                )),
            Positioned(
                top: 0,
                right: 8,
                child: Container(
                    width: 32,
                    height: 32,
                    child: InkWell(
                      key: widget.pasteButtonKey,
                      onTap: () async => _pasteText(),
                      child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Theme.of(context).hintColor,
                              borderRadius: BorderRadius.all(Radius.circular(6))),
                          child: Image.asset('assets/images/paste_ios.png',
                              color: Theme.of(context)
                                  .extension<SendPageTheme>()!
                                  .textFieldButtonIconColor)),
                    )))
          ]),
          Container(
              margin: EdgeInsets.only(top: 15),
              height: 1.0,
              color: Theme.of(context).extension<CakeTextTheme>()!.textfieldUnderlineColor),
        ]));
  }

  Future<void> _pasteText() async {
    final value = await Clipboard.getData('text/plain');

    if (value?.text?.isNotEmpty ?? false) {
      setState(() {
        _showPlaceholder = false;
        controller.text = value!.text!;
      });
    }
  }
}
