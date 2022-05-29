import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShowQRCodePage extends StatefulWidget {
  @override
  State<ShowQRCodePage> createState() => _ShowQRCodeState();
}

class _ShowQRCodeState extends State<ShowQRCodePage> {
  TextEditingController amount;

  @override
  Widget build(BuildContext context) {
    final bolt11 = ModalRoute.of(context).settings.arguments.toString();

    return Scaffold(
      appBar: AppBar(title: Text("Bolt11 QRCode")),
      body: Center(
        child: QrImage(
          data: bolt11,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    amount = TextEditingController();
  }

  @override
  void dispose() {
    super.dispose();
    amount.dispose();
  }
}
