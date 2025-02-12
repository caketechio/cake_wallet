import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_wallet.dart';
import 'package:cw_bitcoin/bitcoin_wallet_addresses.dart';
import 'package:cw_bitcoin/payjoin/payjoin_receive_worker.dart';
import 'package:cw_bitcoin/payjoin/payjoin_send_worker.dart';
import 'package:cw_bitcoin/payjoin/payjoin_session_errors.dart';
import 'package:cw_bitcoin/payjoin/storage.dart';
import 'package:cw_bitcoin/psbt/signer.dart';
import 'package:cw_bitcoin/psbt/utils.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:payjoin_flutter/common.dart';
import 'package:payjoin_flutter/receive.dart';
import 'package:payjoin_flutter/send.dart';
import 'package:payjoin_flutter/uri.dart' as PayjoinUri;

class PayjoinManager {
  PayjoinManager(this._payjoinStorage, this._wallet);

  final PayjoinStorage _payjoinStorage;
  final BitcoinWalletBase _wallet;
  final Map<String, PayjoinPollerSession> _activePollers = {};

  static const List<String> ohttpRelayUrls = [
    'https://pj.bobspacebkk.com',
    'https://ohttp.achow101.com',
  ];

  static Future<PayjoinUri.Url> randomOhttpRelayUrl() => PayjoinUri.Url.fromStr(
      ohttpRelayUrls[Random.secure().nextInt(ohttpRelayUrls.length)]);

  static const payjoinDirectoryUrl = 'https://payjo.in';

  Future<void> resumeSessions() async {
    final allSessions = _payjoinStorage.readAllOpenSessions(_wallet.id);

    final spawnedSessions = allSessions.map((session) {
      if (session.isSenderSession) {
        printV("Resuming Payjoin Sender Session ${session.pjUri!}");
        return spawnSender(
          sender: Sender.fromJson(session.sender!),
          pjUri: session.pjUri!,
        );
      }
      final receiver = Receiver.fromJson(session.receiver!);
      printV("Resuming Payjoin Receiver Session ${receiver.id()}");
      return spawnReceiver(receiver: receiver);
    });

    printV("Resumed ${spawnedSessions.length} Payjoin Sessions");
    await Future.wait(spawnedSessions);
  }

  Future<Sender> initSender(
      String pjUriString, String originalPsbt, int networkFeesSatPerVb) async {
    try {
      final pjUri =
          (await PayjoinUri.Uri.fromStr(pjUriString)).checkPjSupported();
      final minFeeRateSatPerKwu = BigInt.from(networkFeesSatPerVb * 250);
      final senderBuilder = await SenderBuilder.fromPsbtAndUri(
        psbtBase64: originalPsbt,
        pjUri: pjUri,
      );
      return senderBuilder.buildRecommended(minFeeRate: minFeeRateSatPerKwu);
    } catch (e) {
      throw Exception('Error initializing Payjoin Sender: $e');
    }
  }

  Future<void> spawnNewSender({
    required Sender sender,
    required String pjUrl,
    required BigInt amount,
    bool isTestnet = false,
  }) async {
    final pjUri = Uri.parse(pjUrl).queryParameters['pj']!;
    await _payjoinStorage.insertSenderSession(
        sender, pjUri, _wallet.id, amount);

    return spawnSender(isTestnet: isTestnet, sender: sender, pjUri: pjUri);
  }

  Future<void> spawnSender({
    required Sender sender,
    required String pjUri,
    bool isTestnet = false,
  }) async {
    final completer = Completer();
    final receivePort = ReceivePort();

    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        try {
          switch (message['type']) {
            case PayjoinSenderRequestTypes.requestPosted:
              return;
            case PayjoinSenderRequestTypes.psbtToSign:
              final proposalPsbt = message['psbt'] as String;
              final utxos = _wallet.getUtxoWithPrivateKeys();
              final finalizedPsbt = await _wallet.signPsbt(proposalPsbt, utxos);
              final txId = getTxIdFromPsbtV0(finalizedPsbt);
              _wallet.commitPsbt(finalizedPsbt);

              _cleanupSession(pjUri);
              await _payjoinStorage.markSenderSessionComplete(pjUri, txId);
              completer.complete();
          }
        } catch (e) {
          _cleanupSession(pjUri);
          printV(e);
          await _payjoinStorage.markSenderSessionUnrecoverable(pjUri);
          completer.completeError(e);
        }
      } else if (message is PayjoinSessionError) {
        _cleanupSession(pjUri);
        if (message is UnrecoverableError) {
          printV(message.message);
          await _payjoinStorage.markSenderSessionUnrecoverable(pjUri);
          completer.complete();
        } else {
          completer.completeError(message);
        }
      }
    });

    final isolate = await Isolate.spawn(
      PayjoinSenderWorker.run,
      [receivePort.sendPort, sender.toJson(), pjUri],
    );

    _activePollers[pjUri] = PayjoinPollerSession(isolate, receivePort);

    return completer.future;
  }

  Future<Receiver> initReceiver(String address,
      [bool isTestnet = false]) async {
    try {
      final payjoinDirectory =
          await PayjoinUri.Url.fromStr(payjoinDirectoryUrl);

      final ohttpKeys = await PayjoinUri.fetchOhttpKeys(
        ohttpRelay: await randomOhttpRelayUrl(),
        payjoinDirectory: payjoinDirectory,
      );

      final receiver = await Receiver.create(
        address: address,
        network: isTestnet ? Network.testnet : Network.bitcoin,
        directory: payjoinDirectory,
        ohttpKeys: ohttpKeys,
        ohttpRelay: await randomOhttpRelayUrl(),
      );

      await _payjoinStorage.insertReceiverSession(receiver, _wallet.id);

      return receiver;
    } catch (e) {
      throw Exception('Error initializing Payjoin Receiver: $e');
    }
  }

  Future<void> spawnNewReceiver({
    required Receiver receiver,
    bool isTestnet = false,
  }) async {
    await _payjoinStorage.insertReceiverSession(receiver, _wallet.id);
    return spawnReceiver(isTestnet: isTestnet, receiver: receiver);
  }

  Future<void> spawnReceiver({
    required Receiver receiver,
    bool isTestnet = false,
  }) async {
    final completer = Completer();
    final receivePort = ReceivePort();

    SendPort? mainToIsolateSendPort;
    List<UtxoWithPrivateKey> utxos = [];

    receivePort.listen((message) async {
      if (message is Map<String, dynamic>) {
        try {
          switch (message['type']) {
            case PayjoinReceiverRequestTypes.checkIsOwned:
              (_wallet.walletAddresses as BitcoinWalletAddresses).newPayjoinReceiver();
              _payjoinStorage.markReceiverSessionInProgress(receiver.id());

              final inputScript = message['input_script'] as Uint8List;
              final isOwned =
                  _wallet.isMine(Script.fromRaw(byteData: inputScript));
              mainToIsolateSendPort?.send({
                'requestId': message['requestId'],
                'result': isOwned,
              });
              break;

            case PayjoinReceiverRequestTypes.checkIsReceiverOutput:
              final outputScript = message['output_script'] as Uint8List;
              final isReceiverOutput =
                  _wallet.isMine(Script.fromRaw(byteData: outputScript));
              mainToIsolateSendPort?.send({
                'requestId': message['requestId'],
                'result': isReceiverOutput,
              });
              break;

            case PayjoinReceiverRequestTypes.getCandidateInputs:
              utxos = _wallet.getUtxoWithPrivateKeys();
              mainToIsolateSendPort?.send({
                'requestId': message['requestId'],
                'result': utxos,
              });
              break;

            case PayjoinReceiverRequestTypes.processPsbt:
              final psbt = message['psbt'] as String;
              final signedPsbt = await _wallet.signPsbt(psbt, utxos);
              mainToIsolateSendPort?.send({
                'requestId': message['requestId'],
                'result': signedPsbt,
              });
              break;

            case PayjoinReceiverRequestTypes.proposalSent:
              _cleanupSession(receiver.id());
              final psbt = message['psbt'] as String;
              await _payjoinStorage.markReceiverSessionComplete(
                  receiver.id(), getTxIdFromPsbtV0(psbt), getOutputAmountFromPsbt(psbt, _wallet));
              completer.complete();
          }
        } catch (e) {
          _cleanupSession(receiver.id());
          await _payjoinStorage.markReceiverSessionUnrecoverable(receiver.id());
          completer.completeError(e);
        }
      } else if (message is PayjoinSessionError) {
        _cleanupSession(receiver.id());
        if (message is UnrecoverableError) {
          printV(message.message);
          await _payjoinStorage.markReceiverSessionUnrecoverable(receiver.id());
          completer.complete();
        } else {
          completer.completeError(message);
        }
      } else if (message is SendPort) {
        mainToIsolateSendPort = message;
      }
    });

    final isolate = await Isolate.spawn(
      PayjoinReceiverWorker.run,
      [receivePort.sendPort, receiver.toJson()],
    );

    _activePollers[receiver.id()] = PayjoinPollerSession(isolate, receivePort);

    return completer.future;
  }

  void cleanupSessions() {
    final sessionIds = _activePollers.keys.toList();
    for (final sessionId in sessionIds) {
      _cleanupSession(sessionId);
    }
  }

  void _cleanupSession(String sessionId) {
    _activePollers[sessionId]?.close();
    _activePollers.remove(sessionId);
  }
}

class PayjoinPollerSession {
  final Isolate isolate;
  final ReceivePort port;

  PayjoinPollerSession(this.isolate, this.port);

  void close() {
    isolate.kill();
    port.close();
  }
}
