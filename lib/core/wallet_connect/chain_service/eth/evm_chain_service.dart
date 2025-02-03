import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cake_wallet/core/wallet_connect/eth_transaction_model.dart';
import 'package:cake_wallet/core/wallet_connect/chain_service/eth/evm_chain_id.dart';
import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/message_display_widget.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/core/wallet_connect/models/chain_key_model.dart';
import 'package:cake_wallet/core/wallet_connect/models/connection_model.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/connection_widget.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/web3_request_modal.dart';
import 'package:cake_wallet/src/screens/wallet_connect/utils/string_parsing.dart';
import 'package:convert/convert.dart';
import 'package:cw_core/utils/http_client.dart';
import 'package:eth_sig_util/eth_sig_util.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as ioc;
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:web3dart/web3dart.dart';
import '../chain_service.dart';
import '../../wallet_connect_key_service.dart';

class EvmChainServiceImpl implements ChainService {
  final AppStore appStore;
  final BottomSheetService bottomSheetService;
  final Web3Wallet wallet;
  final WalletConnectKeyService wcKeyService;

  static const namespace = 'eip155';
  static const pSign = 'personal_sign';
  static const eSign = 'eth_sign';
  static const eSignTransaction = 'eth_signTransaction';
  static const eSignTypedData = 'eth_signTypedData_v4';
  static const eSendTransaction = 'eth_sendTransaction';

  final EVMChainId reference;

  final Web3Client ethClient;

  EvmChainServiceImpl({
    required this.reference,
    required this.appStore,
    required this.wcKeyService,
    required this.bottomSheetService,
    required this.wallet,
    Web3Client? web3Client,
  }) : ethClient = web3Client ??
            Web3Client(
              appStore.settingsStore.getCurrentNode(appStore.wallet!.type).uri.toString(),
              ioc.IOClient(getHttpClient()),
            ) {
    for (final String event in getEvents()) {
      wallet.registerEventEmitter(chainId: getChainId(), event: event);
    }
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: pSign,
      handler: personalSign,
    );
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: eSign,
      handler: ethSign,
    );
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: eSignTransaction,
      handler: ethSignTransaction,
    );
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: eSendTransaction,
      handler: ethSignTransaction,
    );
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: eSignTypedData,
      handler: ethSignTypedData,
    );
  }

  @override
  String getNamespace() {
    return namespace;
  }

  @override
  String getChainId() {
    return reference.chain();
  }

  @override
  List<String> getEvents() {
    return ['chainChanged', 'accountsChanged'];
  }

  Future<String?> requestAuthorization(String? text) async {
    // Show the bottom sheet
    final bool? isApproved = await bottomSheetService.queueBottomSheet(
      widget: Web3RequestModal(
        child: ConnectionWidget(
          title: S.current.signTransaction,
          info: [
            ConnectionModel(
              text: text,
            ),
          ],
        ),
      ),
    ) as bool?;

    if (isApproved != null && isApproved == false) {
      return 'User rejected signature';
    }

    return null;
  }

  Future<String> personalSign(String topic, dynamic parameters) async {
    log('received personal sign request: $parameters');

    final String message;
    if (parameters[0] == null) {
      message = '';
    } else {
      message = parameters[0].toString().utf8Message;
    }

    final String? authError = await requestAuthorization(message);

    if (authError != null) {
      return authError;
    }

    try {
      // Load the private key
      final List<ChainKeyModel> keys = wcKeyService
          .getKeysForChain(appStore.wallet!);

      final Credentials credentials = EthPrivateKey.fromHex(keys[0].privateKey);

      final String signature = hex.encode(
        credentials.signPersonalMessageToUint8List(Uint8List.fromList(utf8.encode(message))),
      );

      return '0x$signature';
    } catch (e) {
      log(e.toString());
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: '${S.current.errorGettingCredentials} ${e.toString()}',
        ),
      );
      return 'Failed: Error while getting credentials';
    }
  }

  Future<String> ethSign(String topic, dynamic parameters) async {
    log('received eth sign request: $parameters');

    final String message;
    if (parameters[1] == null) {
      message = '';
    } else {
      message = parameters[1].toString().utf8Message;
    }

    final String? authError = await requestAuthorization(message);
    if (authError != null) {
      return authError;
    }

    try {
      // Load the private key
      final List<ChainKeyModel> keys = wcKeyService
          .getKeysForChain(appStore.wallet!);

      final EthPrivateKey credentials = EthPrivateKey.fromHex(keys[0].privateKey);

      final String signature = hex.encode(
        credentials.signPersonalMessageToUint8List(
          Uint8List.fromList(utf8.encode(message)),
          chainId: getChainIdBasedOnWalletType(appStore.wallet!.type),
        ),
      );
      log(signature);

      return '0x$signature';
    } catch (e) {
      log('error: ${e.toString()}');
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(message: '${S.current.error}: ${e.toString()}'),
      );
      return 'Failed';
    }
  }

  Future<String> ethSignTransaction(String topic, dynamic parameters) async {
    log('received eth sign transaction request: $parameters');

    final paramsData = parameters[0] as Map<String, dynamic>;

    final message = _convertToReadable(paramsData);

    final String? authError = await requestAuthorization(message);

    if (authError != null) {
      return authError;
    }

    // Load the private key
    final List<ChainKeyModel> keys = wcKeyService
        .getKeysForChain(appStore.wallet!);

    final Credentials credentials = EthPrivateKey.fromHex(keys[0].privateKey);

    WCEthereumTransactionModel ethTransaction =
        WCEthereumTransactionModel.fromJson(parameters[0] as Map<String, dynamic>);

    final transaction = Transaction(
      from: EthereumAddress.fromHex(ethTransaction.from),
      to: EthereumAddress.fromHex(ethTransaction.to),
      maxGas: ethTransaction.gasLimit != null ? int.tryParse(ethTransaction.gasLimit ?? "") : null,
      gasPrice: ethTransaction.gasPrice != null
          ? EtherAmount.inWei(BigInt.parse(ethTransaction.gasPrice ?? ""))
          : null,
      value: EtherAmount.inWei(BigInt.parse(ethTransaction.value)),
      data: hexToBytes(ethTransaction.data ?? ""),
      nonce: ethTransaction.nonce != null ? int.tryParse(ethTransaction.nonce ?? "") : null,
    );

    try {
      final result = await ethClient.sendTransaction(
        credentials,
        transaction,
        chainId: getChainIdBasedOnWalletType(appStore.wallet!.type),
      );

      log('Result: $result');

      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: S.current.awaitDAppProcessing,
          isError: false,
        ),
      );

      return result;
    } catch (e) {
      log('An error has occurred while signing transaction: ${e.toString()}');
      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: '${S.current.errorSigningTransaction}: ${e.toString()}',
        ),
      );
      return 'Failed';
    }
  }

  Future<String> ethSignTypedData(String topic, dynamic parameters) async {
    log('received eth sign typed data request: $parameters');
    final String? data = parameters[1] as String?;

    final String? authError = await requestAuthorization(data);

    if (authError != null) {
      return authError;
    }

    final List<ChainKeyModel> keys = wcKeyService
        .getKeysForChain(appStore.wallet!);

    return EthSigUtil.signTypedData(
      privateKey: keys[0].privateKey,
      jsonData: data ?? '',
      version: TypedDataVersion.V4,
    );
  }

  String _convertToReadable(Map<String, dynamic> data) {
    final tokenName = getTokenNameBasedOnWalletType(appStore.wallet!.type);
    String gas = int.parse((data['gas'] as String).substring(2), radix: 16).toString();
    String value = data['value'] != null
        ? (int.parse((data['value'] as String).substring(2), radix: 16) / 1e18).toString() +
            ' $tokenName'
        : '0 $tokenName';
    String from = data['from'] as String;
    String to = data['to'] as String;

    return '''
 Gas: $gas\n
 Value: $value\n
 From: $from\n
 To: $to
             ''';
  }
}
