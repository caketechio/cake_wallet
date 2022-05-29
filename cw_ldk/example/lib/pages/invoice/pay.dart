import 'package:flutter/material.dart';
import 'package:cw_ldk/cw_ldk.dart';

class PayInvoicePage extends StatefulWidget {
  @override
  State<PayInvoicePage> createState() => _PayInvoiceState();
}

class _PayInvoiceState extends State<PayInvoicePage> {
  final bolt11 = TextEditingController();

  bool isValidBolt11 = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Pay Invoice")),
        body: Center(
          child: Container(
            margin: EdgeInsets.all(8),
            child: Column(
              children: [
                Text("Enter bolt11 invoice or scan"),
                ElevatedButton(
                  onPressed: () async {
                    final res = await Navigator.of(context)
                        .pushNamed("/invoice/qr_code_scanner");

                    setState(() {
                      bolt11.text = res.toString();
                      isValidBolt11 = true;
                    });
                  },
                  child: Text("Scan QRCode"),
                ),
                TextField(
                  decoration: InputDecoration(labelText: "bolt11"),
                  controller: bolt11,
                  onChanged: (_) {
                    setState(() {
                      isValidBolt11 = true;
                    });
                  },
                ),
                ElevatedButton(
                    onPressed: isValidBolt11
                        ? () async {
                            final res = await CwLdk.sendPayment(bolt11.text);
                            await showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                  title: Text("Channel Created"),
                                  content: Text(res),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Ok'),
                                      onPressed: () {
                                        final nav = Navigator.of(context);
                                        nav.pop();
                                        nav.pop();
                                      },
                                    )
                                  ]),
                            );
                          }
                        : null,
                    child: Text("Pay Invoice"))
              ],
            ),
          ),
        ));
  }
}
