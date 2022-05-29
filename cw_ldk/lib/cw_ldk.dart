import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isolate/ports.dart';
import 'ffi.dart' as native;
import 'package:path_provider/path_provider.dart';

// function pointer type for wrappedPrint function
typedef _print_C = Void Function(Pointer<Utf8>);

class StartLDKParams {
  StartLDKParams(this.rpcInfo, this.path, this.port, this.network,
      this.nodeName, this.address, this.mnemonicKeyPhrase);

  String rpcInfo;

  String path;

  int port;

  String network;

  String nodeName;

  String address;

  String mnemonicKeyPhrase;
}

/// This Class is for initializing and communicating with the LDK.
class CwLdk {
  // remove for later
  static const MethodChannel _channel = const MethodChannel('cw_ldk');

  // keeps track if ldk is running
  static bool ldkIsRunning = true;

  // remove for later
  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Get app doc directory path for app.
  static Future<String> getAppDocDirPath() async {
    final Directory _appDocDir = await getApplicationDocumentsDirectory();
    return _appDocDir.path;
  }

  /// create folder in app doc directory.
  static Future<String> createFolder(String folderName) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory folderPath = Directory('${appDocDir.path}/$folderName/');

    if (await folderPath.exists()) {
      return folderPath.path;
    } else {
      final Directory folderPathNew = await folderPath.create(recursive: true);
      return folderPathNew.path;
    }
  }

  static Future<void> clear() async {
    await CwLdk.deleteFolder(".ldk/logs");
    await CwLdk.deleteFolder(".ldk");
  }

  /// Delete folder in app doc directory.
  static Future<bool> deleteFolder(String folderName) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory appDocDirFolder =
        Directory('${appDocDir.path}/$folderName/');

    if (await appDocDirFolder.exists()) {
      // delete all content inside directory before deleting the folder
      await for (var entity
          in appDocDirFolder.list(recursive: true, followLinks: false)) {
        print("delete: ${entity.path}");
        await File(entity.path).delete();
      }
      await appDocDirFolder.delete();
      return true;
    } else {
      return false;
    }
  }

  /// List file in folder.
  static Future<bool> listFilesInFolder(String folderName) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    final Directory folder = Directory('${appDocDir.path}/$folderName/');

    if (await folder.exists()) {
      await for (var entity
          in folder.list(recursive: true, followLinks: false)) {
        print("path: ${entity.path}");
      }
      return true;
    } else {
      return false;
    }
  }

  /// Return content from file.
  static Future<String> readFile(String fileName) async {
    final Directory appDirPath = await getApplicationDocumentsDirectory();
    final File file = new File("${appDirPath.path}/$fileName");
    return file.readAsString();
  }

  /// Show logs for ldk.
  static Future<String> showLogs() async {
    final logs = await readFile(".ldk/logs/logs.txt");
    return logs;
  }

  /// Used by LDK for printing to the console.
  static void wrappedPrint(Pointer<Utf8> arg) {
    final res = arg.toDartString();
    print(res);
  }

  /// Starts the LDK in a isolate
  static void __startLDKIsolate(StartLDKParams params) async {
    final wrappedPrintPointer = Pointer.fromFunction<_print_C>(wrappedPrint);
    native.start_ldk(
        params.rpcInfo.toNativeUtf8(),
        params.path.toNativeUtf8(),
        params.port,
        params.network.toNativeUtf8(),
        params.nodeName.toNativeUtf8(),
        params.address.toNativeUtf8(),
        params.mnemonicKeyPhrase.toNativeUtf8(),
        wrappedPrintPointer);
  }

  /// Starts the LDK.
  ///
  /// Must supply [rpcInfo], [port] to listen on, [network] you are
  /// using (regtest, testnet, mainNet), [nodeName] to give a name to your node.
  /// [address] you will be listening to, and the [mnemonicKeyPhrase] for
  /// extracting the public key and private key for assigning funds and signing
  /// transaction.
  // ignore: missing_return
  static Future<Void> startLDK(String rpcInfo, int port, String network,
      String nodeName, String address, String mnemonicKeyPhrase) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    // ignore: unawaited_futures
    compute<StartLDKParams, void>(
        __startLDKIsolate,
        StartLDKParams(rpcInfo, appDocDir.path, port, network, nodeName,
            address, mnemonicKeyPhrase));
  }

  /// Send message to LDK
  static Future<String> sendMessage(String msg) {
    final completer = Completer<String>();
    final sendPort = singleCompletePort<String, String>(completer);
    final port = sendPort.nativePort;

    if (ldkIsRunning) {
      final res = native.send_message(msg.toNativeUtf8(), port);

      if (res != 1) {
        _throwError();
        completer.complete("ldk did not receive message");
      }
    } else {
      completer.complete("ldk is not running.");
    }

    return completer.future;
  }

  /// Get node info for ldk instance.
  static Future<String> nodeInfo() async {
    final res = await sendMessage("nodeinfo");
    return res;
  }

  /// Todo: Connect to peer for connecting creating channels.
  ///
  /// [url] should have the form pubkey@host:port
  static Future<String> connectPeer(String url) async {
    final res = await sendMessage("connectpeer $url");
    return res;
  }

  /// Todo: Show peers that we are setup with.
  static Future<String> listPeers() async {
    final res = await sendMessage("listpeers");
    return res;
  }

  /// Todo: Open a channel.
  ///
  /// Returns the channel ID.
  /// [url] url to node to connect.  should have form (pubkey@host:port)
  /// [amount] is the amount is satoshis we want to setup the channel.
  static Future<String> openChannel(String url, String amount) async {
    final res = await sendMessage("openchannel $url $amount");
    return res;
  }

  /// Todo: Close a channel.
  ///
  /// [channelID] is the channel ID.
  static Future<String> closeChannel(String channelID) async {
    final res = await sendMessage("closechannel $channelID");
    return res;
  }

  /// Todo: Create an invoice in [amount]
  ///
  /// Returns a bolt11 string.
  static Future<String> getInvoice(String amount) async {
    final res = await sendMessage("getinvoice $amount");
    return res;
  }

  /// Todo: pays invoice.
  ///
  /// [invoice] is the bolt11 string.
  static Future<String> sendPayment(String invoice) async {
    final res = await sendMessage("sendpayment $invoice");
    return res;
  }

  /// Todo: List channels you have setup.
  static Future<String> listChannels() async {
    final res = await sendMessage("listchannels");
    return res;
  }

  static void storeDartPostCobject(
    Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>> ptr,
  ) {
    native.store_dart_post_cobject(ptr);
  }

  static String showError() {
    final length = native.last_error_length();
    if (length > 0) {
      final Pointer<Utf8> message = calloc.allocate(length);
      native.error_message_utf8(message, length);
      final error = message.toDartString();
      print(error);
      return error;
    } else {
      return "no errors";
    }
  }

  static void _throwError() {
    final length = native.last_error_length();
    final Pointer<Utf8> message = calloc.allocate(length);
    native.error_message_utf8(message, length);
    final error = message.toDartString();
    print(error);
    throw Exception(error);
  }
}
