import 'package:cw_ldk/cw_ldk.dart';
import 'package:flutter/material.dart';

class CreateInvoicePage extends StatefulWidget {
  @override
  State<CreateInvoicePage> createState() => _CreateInvoiceState();
}

class _CreateInvoiceState extends State<CreateInvoicePage> {
  TextEditingController amount;
  String bolt11;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Invoice")),
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            Text("Please specify amount in satoshis"),
            TextField(
              decoration: InputDecoration(labelText: "amount"),
              controller: amount,
            ),
            ElevatedButton(
              child: Text("Create Bolt 11"),
              onPressed: () async {
                final res = await CwLdk.getInvoice(amount.text);
                setState(() {
                  bolt11 = res;
                });
              },
            ),
            if (bolt11 != null) ...[
              Container(
                margin: EdgeInsets.only(top: 10),
                child: SelectableText(bolt11),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed("/invoice/show_qr_code", arguments: bolt11);
                },
                child: Text("Show QR Code"),
              ),
            ]
          ],
        ),
      )),
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
