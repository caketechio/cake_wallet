import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/src/widgets/standard_switch.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/utils/date_picker.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/src/widgets/base_text_form_field.dart';
import 'package:cake_wallet/decred/decred.dart';
import 'package:cw_core/wallet_type.dart';


class BlockchainHeightWidget extends StatefulWidget {
  BlockchainHeightWidget({
    GlobalKey? key,
    this.onHeightChange,
    this.focusNode,
    this.onHeightOrDateEntered,
    this.hasDatePicker = true,
    this.isSilentPaymentsScan = false,
    this.isMwebScan = false,
    this.toggleSingleScan,
    this.doSingleScan = false,
    this.bitcoinMempoolAPIEnabled,
    required this.walletType,
    this.blockHeightTextFieldKey,
  }) : super(key: key);

  final Function(int)? onHeightChange;
  final Function(bool)? onHeightOrDateEntered;
  final FocusNode? focusNode;
  final bool hasDatePicker;
  final bool isSilentPaymentsScan;
  final bool isMwebScan;
  final bool doSingleScan;
  final Future<bool>? bitcoinMempoolAPIEnabled;
  final Function()? toggleSingleScan;
  final WalletType walletType;
  final Key? blockHeightTextFieldKey;

  @override
  State<StatefulWidget> createState() => BlockchainHeightState();
}

class BlockchainHeightState extends State<BlockchainHeightWidget> {
  final dateController = TextEditingController();
  final restoreHeightController = TextEditingController();

  int get height => _height;
  int _height = 0;

  @override
  void initState() {
    restoreHeightController.addListener(() {
      if (restoreHeightController.text.isNotEmpty) {
        widget.onHeightOrDateEntered?.call(true);
      } else {
        widget.onHeightOrDateEntered?.call(false);
        dateController.text = '';
      }
      try {
        _changeHeight(
            restoreHeightController.text.isNotEmpty ? int.parse(restoreHeightController.text) : 0);
      } catch (_) {
        _changeHeight(0);
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                  child: Container(
                      padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
                      child: BaseTextFormField(
                        key: widget.blockHeightTextFieldKey,
                        focusNode: widget.focusNode,
                        controller: restoreHeightController,
                        keyboardType:
                            TextInputType.numberWithOptions(signed: false, decimal: false),
                        hintText: widget.isSilentPaymentsScan
                            ? S.of(context).silent_payments_scan_from_height
                            : S.of(context).widgets_restore_from_blockheight,
                      )))
            ],
          ),
          if (widget.hasDatePicker) ...[
            Padding(
              padding: EdgeInsets.only(top: 15, bottom: 15),
              child: Text(
                S.of(context).widgets_or,
                style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).extension<CakeTextTheme>()!.titleColor),
              ),
            ),
            Row(
              children: <Widget>[
                Flexible(
                    child: Container(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: IgnorePointer(
                        child: BaseTextFormField(
                      controller: dateController,
                      hintText: widget.isSilentPaymentsScan
                          ? S.of(context).silent_payments_scan_from_date
                          : S.of(context).widgets_restore_from_date,
                    )),
                  ),
                ))
              ],
            ),
            if (widget.isSilentPaymentsScan)
              Padding(
                padding: EdgeInsets.only(top: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context).scan_one_block,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StandardSwitch(
                        value: widget.doSingleScan,
                        onTaped: () => widget.toggleSingleScan?.call(),
                      ),
                    )
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(left: 40, right: 40, top: 24),
              child: Text(
                widget.isSilentPaymentsScan
                    ? S.of(context).silent_payments_scan_from_date_or_blockheight
                    : S.of(context).restore_from_date_or_blockheight,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).hintColor),
              ),
            )
          ]
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await getDate(
        context: context,
        initialDate: now.subtract(Duration(days: 1)),
        firstDate: DateTime(2014, DateTime.may),
        lastDate: now);

    if (date != null) {
      int height;
      if (widget.isMwebScan) {
        height = bitcoin!.getLitecoinHeightByDate(date: date);
      } else if (widget.isSilentPaymentsScan) {
        height = await bitcoin!.getHeightByDate(
          date: date,
          bitcoinMempoolAPIEnabled: await widget.bitcoinMempoolAPIEnabled,
        );
      } else {
        if (widget.walletType == WalletType.decred) {
          height = decred!.heightByDate(date);
        } else if (widget.walletType == WalletType.monero) {
          height = monero!.getHeightByDate(date: date);
        } else {
          assert(widget.walletType == WalletType.wownero,
              "unknown currency in BlockchainHeightWidget");
          height = wownero!.getHeightByDate(date: date);
        }
      }
      if (mounted) {
        setState(() {
          dateController.text = DateFormat('yyyy-MM-dd').format(date);
          restoreHeightController.text = '$height';
          _changeHeight(height);
        });
      }
    }
  }

  void _changeHeight(int height) {
    _height = height;
    widget.onHeightChange?.call(height);
  }
}
