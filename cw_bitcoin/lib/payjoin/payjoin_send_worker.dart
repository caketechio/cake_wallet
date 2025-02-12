import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:cw_bitcoin/payjoin/manager.dart';
import 'package:cw_bitcoin/payjoin/payjoin_session_errors.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:http/http.dart' as http;
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/src/generated/frb_generated.dart' as pj;

enum PayjoinSenderRequestTypes {
  requestPosted,
  psbtToSign;
}

class PayjoinSenderWorker {
  final SendPort sendPort;
  final pendingRequests = <String, Completer<dynamic>>{};
  final String pjUrl;

  PayjoinSenderWorker._(this.sendPort, this.pjUrl);

  static Future<void> run(List<Object> args) async {
    await pj.core.init();

    final sendPort = args[0] as SendPort;
    final senderJson = args[1] as String;
    final pjUrl = args[2] as String;

    final sender = Sender.fromJson(senderJson);
    final worker = PayjoinSenderWorker._(sendPort, pjUrl);

    try {
      final proposalPsbt = await worker.runSender(sender);
      sendPort.send({
        'type': PayjoinSenderRequestTypes.psbtToSign,
        'psbt': proposalPsbt,
      });
    } catch (e) {
      sendPort.send(e);
    }
  }

  /// Run a payjoin sender (V2 protocol first, fallback to V1).
  Future<String> runSender(Sender sender) async {
    final httpClient = http.Client();

    try {
      return await _runSenderV2(sender, httpClient);
    } catch (e) {
      if (e is PayjoinException &&
          // TODO condition on error type instead of message content
          e.message?.contains('parse receiver public key') == true) {
        return await _runSenderV1(sender, httpClient);
      } else if (e is HttpException) {
        throw Exception(PayjoinSessionError.recoverable(e.toString()));
      } else {
        throw Exception(PayjoinSessionError.unrecoverable(e.toString()));
      }
    }
  }

  /// Attempt to send payjoin using the V2 of the protocol.
  Future<String> _runSenderV2(Sender sender, http.Client httpClient) async {
    try {
      final postRequest = await sender.extractV2(
        ohttpProxyUrl: await await PayjoinManager.randomOhttpRelayUrl(),
      );

      final postResult = await _postRequest(httpClient, postRequest.$1);
      final getContext =
      await postRequest.$2.processResponse(response: postResult);

      sendPort.send({'type': PayjoinSenderRequestTypes.requestPosted, "pj": pjUrl});

      while (true) {
        printV('Polling V2 Proposal Request (${pjUrl})');

        final getRequest = await getContext.extractReq(
          ohttpRelay: await PayjoinManager.randomOhttpRelayUrl(),
        );
        final getRes = await _postRequest(httpClient, getRequest.$1);
        final proposalPsbt = await getContext.processResponse(
          response: getRes,
          ohttpCtx: getRequest.$2,
        );
        printV("$proposalPsbt");
        if (proposalPsbt != null) return proposalPsbt;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Attempt to send payjoin using the V1 of the protocol.
  Future<String> _runSenderV1(Sender sender, http.Client httpClient) async {
    try {
      final postRequest = await sender.extractV1();
      final response = await _postRequest(httpClient, postRequest.$1);

      sendPort.send({'type': PayjoinSenderRequestTypes.requestPosted});

      return await postRequest.$2.processResponse(response: response);
    } catch (e) {
      throw PayjoinSessionError.unrecoverable('Send V1 payjoin error: $e');
    }
  }

  Future<List<int>> _postRequest(http.Client client, Request req) async {
    final httpRequest = await client.post(Uri.parse(req.url.asString()),
        headers: {'Content-Type': req.contentType}, body: req.body);

    return httpRequest.bodyBytes;
  }
}
