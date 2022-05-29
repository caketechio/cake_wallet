import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:cw_ldk/cw_ldk.dart';

class HomePage extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<HomePage> {
  String _platformVersion = 'Unknown';

  final _mnomonicKeyPhrase =
      "stool outside acoustic correct craft attitude scheme urge grape again chalk gas";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;

    try {
      platformVersion = await CwLdk.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // setup pointer for isolate communication.
    CwLdk.storeDartPostCobject(NativeApi.postCObject);

    // show previous logs
    // final logs = await CwLdk.showLogs();
    // print(logs);

    // await CwLdk.clear();

    // ignore: unawaited_futures
    CwLdk.startLDK("polaruser:polarpass@192.168.0.13:18443", 9732, "regtest",
        "hellolightning", "0.0.0.0", _mnomonicKeyPhrase);

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  /// Show logs to LDK.
  void showLogs(BuildContext context) async {
    final res = await CwLdk.showLogs();
    print(res);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("logs"),
        content: SingleChildScrollView(child: Text(res)),
      ),
    );
  }

  void showError(BuildContext context) {
    final res = CwLdk.showError();
    print(res);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("nodeInfo"),
        content: Text(res),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CW_LDK example'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Running on: $_platformVersion\n'),
              Text('BTC Amount: \$\$\$'),
              Text('LN Amount: \$\$\$\n'),
              ElevatedButton(
                  onPressed: () {
                    showLogs(context);
                  },
                  child: Text("logs")),
              ElevatedButton(
                  onPressed: () {
                    showError(context);
                  },
                  child: Text("Show Error")),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.orange),
              child: Row(children: <Widget>[
                FlutterLogo(
                  size: 70,
                ),
                Text("CW_LDK")
              ]),
            ),
            ListTile(
              title: Text("Create Channel"),
              leading: Icon(Icons.account_balance),
              onTap: () {
                Navigator.of(context).pushNamed("/channel/create");
              },
            ),
            ListTile(
              title: Text("Close Channel"),
              leading: Icon(Icons.close),
              onTap: () async {
                final res = await CwLdk.closeChannel("1234ad56");
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
                          },
                        )
                      ]),
                );
              },
            ),
            ListTile(
              title: Text("Create Invoice"),
              leading: Icon(Icons.qr_code),
              onTap: () {
                Navigator.of(context).pushNamed("/invoice/create");
              },
            ),
            ListTile(
              title: Text("Pay Invoice"),
              leading: Icon(Icons.payment),
              onTap: () {
                Navigator.of(context).pushNamed("/invoice/pay");
              },
            ),
            ListTile(
              title: Text("Node and Channel Info"),
              leading: Icon(Icons.account_box),
              onTap: () {
                Navigator.of(context).pushNamed("/info");
              },
            )
          ],
        ),
      ),
    );
  }
}
