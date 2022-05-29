import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QRCodeScannerPage extends StatefulWidget {
  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends State<QRCodeScannerPage> {
  bool isValidBolt11 = false;

  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  QRViewController controller;

  String result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Scan QRCode")),
        body: Column(
          children: [
            Expanded(
              flex: 5,
              child: QRView(
                key: qrKey,
                overlay: QrScannerOverlayShape(
                  borderWidth: 10,
                  borderLength: 20,
                ),
                onQRViewCreated: (QRViewController controller) {
                  _onQRViewCreated(controller, context);
                },
              ),
            ),
            Expanded(
              child: Center(
                child: (result == null) ? Text("Scan a qrcode") : Text(result),
              ),
            )
          ],
        ));
  }

  void _onQRViewCreated(QRViewController controller, BuildContext context) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        result = scanData.code;
        Navigator.of(context).pop(result);
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
