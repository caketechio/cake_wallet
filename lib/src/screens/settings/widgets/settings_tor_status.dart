import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/src/screens/nodes/widgets/node_indicator.dart';
import 'package:cake_wallet/src/widgets/standard_list.dart';
import 'package:cake_wallet/view_model/settings/tor_connection.dart';
import 'package:cake_wallet/view_model/settings/tor_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class TorStatus extends StandardListRow {
  TorStatus(
      {required String title,
      required bool isSelected,
      required this.torViewModel,
      BoxDecoration? decoration})
      : super(title: title, onTap: null, isSelected: isSelected, decoration: decoration);

  final TorViewModel torViewModel;

  @override
  Widget buildTrailing(BuildContext context) {
    return Observer(builder: (context) {
      Color? color;
      switch (torViewModel.torConnectionStatus) {
        case TorConnectionStatus.connected:
          color = Palette.green;
          break;
        case TorConnectionStatus.connecting:
          color = Colors.amber;
          break;
        case TorConnectionStatus.disconnected:
          color = Palette.red;
          break;
      }
      return NodeIndicator(
        color: color,
        text: torViewModel.torConnectionStatus.toString(),
      );
    });
  }
}
