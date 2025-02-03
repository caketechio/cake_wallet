import 'package:cw_core/utils/http_client.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:flutter/material.dart';
import 'package:tor/tor.dart';

bool didTorStart = false;
Future<void> ensureTorStopped({required BuildContext? context}) async {
  if (!didTorStart) {
    printV("Tor hasn't been initialized yet, so it can't be stopped.");
    return;
  }
  if (context != null) showFullscreenDialog(context);
  didTorStart = false;
  printV("Stopping tor");
  await CakeTor.instance.stop();
  printV("Tor stopped");
  if (context != null) dismissFullscreenDialog(context);
}

Future<void> ensureTorStarted({required BuildContext? context}) async {
  if (didTorStart) {
    printV("Tor has already started");
    return;
  }
  if (context != null) showFullscreenDialog(context);
  didTorStart = true;
  printV("Initializing tor");
  await Tor.init();
  printV("Starting tor");
  await CakeTor.instance.start();
  printV("Tor started");
  if (context != null) dismissFullscreenDialog(context);
}

Future<void> showFullscreenDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Container(
        color: Colors.transparent,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    },
  );
}

Future<void> dismissFullscreenDialog(BuildContext context) async {
  Navigator.of(context).pop();
}