import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:flutter/material.dart';

import '../../models/bottom_sheet_queue_item_model.dart';

class BottomSheetListener extends StatefulWidget {
  final Widget child;

  const BottomSheetListener({required this.child, super.key});

  @override
  BottomSheetListenerState createState() => BottomSheetListenerState();
}

class BottomSheetListenerState extends State<BottomSheetListener> {
  late final BottomSheetService _bottomSheetService;

  @override
  void initState() {
    super.initState();
    
    //TODO(David): Switch to dependency injection
    _bottomSheetService = getIt.get<BottomSheetService>();
    _bottomSheetService.currentSheet.addListener(_showBottomSheet);
  }

  @override
  void dispose() {
    _bottomSheetService.currentSheet.removeListener(_showBottomSheet);
    super.dispose();
  }

  Future<void> _showBottomSheet() async {
    if (_bottomSheetService.currentSheet.value != null) {
      BottomSheetQueueItemModel item = _bottomSheetService.currentSheet.value!;
      final value = await showModalBottomSheet(
        context: context,
        isDismissible: false,
        backgroundColor: Color.fromARGB(0, 0, 0, 0),
        isScrollControlled: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 18, 18, 19),
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            child: item.widget,
          );
        },
      );
      item.completer.complete(value);
      _bottomSheetService.showNext();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
