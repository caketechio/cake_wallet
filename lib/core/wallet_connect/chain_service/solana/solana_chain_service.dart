import 'dart:convert';
import 'dart:developer';

import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cake_wallet/core/wallet_connect/chain_service/solana/entities/solana_sign_message.dart';
import 'package:cake_wallet/core/wallet_connect/chain_service/solana/solana_chain_id.dart';
import 'package:cake_wallet/core/wallet_connect/wc_bottom_sheet_service.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/message_display_widget.dart';
import 'package:cake_wallet/core/wallet_connect/models/connection_model.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/connection_widget.dart';
import 'package:cake_wallet/src/screens/wallet_connect/widgets/modals/web3_request_modal.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_solana/solana_rpc_service.dart';
import 'package:on_chain/solana/solana.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import '../chain_service.dart';
import '../../wallet_connect_key_service.dart';
import 'entities/solana_sign_transaction.dart';

class SolanaChainServiceImpl implements ChainService {
  final BottomSheetService bottomSheetService;
  final Web3Wallet wallet;
  final WalletConnectKeyService wcKeyService;

  static const namespace = 'solana';
  static const solSignTransaction = 'solana_signTransaction';
  static const solSignMessage = 'solana_signMessage';

  final SolanaChainId reference;

  final SolanaRPC solanaProvider;

  final SolanaPrivateKey? ownerPrivateKey;

  SolanaChainServiceImpl({
    required this.reference,
    required this.wcKeyService,
    required this.bottomSheetService,
    required this.wallet,
    required this.ownerPrivateKey,
    required String formattedRPCUrl,
    SolanaRPC? solanaProvider,
  }) : solanaProvider = solanaProvider ?? SolanaRPC(SolanaRPCHTTPService(url: formattedRPCUrl)) {
    for (final String event in getEvents()) {
      wallet.registerEventEmitter(chainId: getChainId(), event: event);
    }
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: solSignTransaction,
      handler: solanaSignTransaction,
    );
    wallet.registerRequestHandler(
      chainId: getChainId(),
      method: solSignMessage,
      handler: solanaSignMessage,
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

  Future<String> solanaSignTransaction(String topic, dynamic parameters) async {
    log('received solana sign transaction request $parameters');

    final solanaSignTx = SolanaSignTransaction.fromJson(parameters as Map<String, dynamic>);

    final String? authError = await requestAuthorization('Confirm request to sign transaction?');

    if (authError != null) {
      return authError;
    }

    try {
      // Convert transaction string to bytes
      List<int> transactionBytes = base64Decode(solanaSignTx.transaction);

      final message = SolanaTransactionUtils.deserializeMessageLegacy(transactionBytes);

      ownerPrivateKey!.sign(message.serialize());

      final signature = solanaProvider.request(
        SolanaRPCSendTransaction(
          encodedTransaction: message.serializeHex(),
          commitment: Commitment.confirmed,
        ),
      );

      printV(signature);

      bottomSheetService.queueBottomSheet(
        isModalDismissible: true,
        widget: BottomSheetMessageDisplayWidget(
          message: S.current.awaitDAppProcessing,
          isError: false,
        ),
      );

      return signature;
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

  Future<String> solanaSignMessage(String topic, dynamic parameters) async {
    log('received solana sign message request: $parameters');

    final solanaSignMessage = SolanaSignMessage.fromJson(parameters as Map<String, dynamic>);

    final String? authError = await requestAuthorization('Confirm request to sign message?');

    if (authError != null) {
      return authError;
    }
    List<int>? sign;

    try {
      sign = ownerPrivateKey!.sign(Base58Decoder.decode(solanaSignMessage.message));
    } catch (e) {
      printV(e);
    }

    if (sign == null) {
      return '';
    }

    final signature = Base58Encoder.encode(sign);

    return signature;
  }
}
