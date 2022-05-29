import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cw_ldk/cw_ldk.dart';

class CreateChannelPage extends StatefulWidget {
  @override
  State<CreateChannelPage> createState() => _CreateChannelState();
}

class _CreateChannelState extends State<CreateChannelPage> {
  TextEditingController amount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Channel")),
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
              child: Text("Create Channel"),
              onPressed: () async {
                // Navigator.pop(context);
                final res = await CwLdk.openChannel(
                    "03efcf3a659de7ca716cea0044617549c5bc82dd71f7d43363d6bceeb7321b34a6@192.168.0.12:9735",
                    amount.text);

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
              },
            )
          ],
        ),
      )),
    );
  }

  @override
  void initState() {
    super.initState();
    amount = TextEditingController();
    initStateAsync();
  }

  Future<void> initStateAsync() async {
    final String peersJson = await CwLdk.listPeers();
    // final peersJson = "{ \"peers\": []}";
    final Map<String, dynamic> res =
        jsonDecode(peersJson) as Map<String, dynamic>;
    if ((res['peers'] as List).length == 0) {
      await CwLdk.connectPeer(
          "038f07ba15d065b96efc5cb708e9847f72cb9138871a15e5e4097f15a6a74a914a@192.168.0.13:9735");
    }
  }

  @override
  void dispose() {
    super.dispose();
    amount.dispose();
  }
}
