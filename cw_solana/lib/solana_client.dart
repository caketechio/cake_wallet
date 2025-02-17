import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_solana/pending_solana_transaction.dart';
import 'package:cw_solana/solana_balance.dart';
import 'package:cw_solana/solana_exceptions.dart';
import 'package:cw_solana/solana_transaction_model.dart';
import 'package:cw_solana/solana_rpc_service.dart';
import 'package:http/http.dart' as http;
import 'package:on_chain/solana/solana.dart';
import 'package:on_chain/solana/src/models/pda/pda.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import '.secrets.g.dart' as secrets;

class SolanaWalletClient {
  final httpClient = http.Client();
  SolanaRPC? _provider;

  bool connect(Node node) {
    try {
      String formattedUrl;
      String protocolUsed = node.isSSL ? "https" : "http";

      if (node.uriRaw == 'rpc.ankr.com') {
        String ankrApiKey = secrets.ankrApiKey;

        formattedUrl = '$protocolUsed://${node.uriRaw}/$ankrApiKey';
      } else if (node.uriRaw == 'solana-mainnet.core.chainstack.com') {
        String chainStackApiKey = secrets.chainStackApiKey;

        formattedUrl = '$protocolUsed://${node.uriRaw}/$chainStackApiKey';
      } else {
        formattedUrl = '$protocolUsed://${node.uriRaw}';
      }

      _provider = SolanaRPC(SolanaRPCHTTPService(url: formattedUrl));

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<double> getBalance(String walletAddress) async {
    try {
      final balance = await _provider!.requestWithContext(
        SolanaRPCGetBalance(
          account: SolAddress(walletAddress),
        ),
      );

      final balInLamp = balance.result.toDouble();

      final solBalance = balInLamp / SolanaUtils.lamportsPerSol;

      return solBalance;
    } catch (_) {
      return 0.0;
    }
  }

  Future<List<TokenAccountResponse>?> getSPLTokenAccounts(
      String mintAddress, String publicKey) async {
    try {
      final result = await _provider!.request(
        SolanaRPCGetTokenAccountsByOwner(
          account: SolAddress(publicKey),
          mint: SolAddress(mintAddress),
          commitment: Commitment.confirmed,
          encoding: SolanaRPCEncoding.base64,
        ),
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  Future<SolanaBalance?> getSplTokenBalance(String mintAddress, String walletAddress) async {
    // Fetch the token accounts (a token can have multiple accounts for various uses)
    final tokenAccounts = await getSPLTokenAccounts(mintAddress, walletAddress);

    // Handle scenario where there is no token account
    if (tokenAccounts == null || tokenAccounts.isEmpty) {
      return null;
    }

    // Sum the balances of all accounts with the specified mint address
    double totalBalance = 0.0;

    for (var tokenAccount in tokenAccounts) {
      final tokenAmountResult = await _provider!.request(
        SolanaRPCGetTokenAccountBalance(account: tokenAccount.pubkey),
      );

      final balance = tokenAmountResult.uiAmountString;

      final balanceAsDouble = double.tryParse(balance ?? '0.0') ?? 0.0;

      totalBalance += balanceAsDouble;
    }

    return SolanaBalance(totalBalance);
  }

  Future<double> getFeeForMessage(String message, Commitment commitment) async {
    try {
      final feeForMessage = await _provider!.request(
        SolanaRPCGetFeeForMessage(
          encodedMessage: message,
          commitment: commitment,
        ),
      );

      final fee = (feeForMessage?.toDouble() ?? 0.0) / SolanaUtils.lamportsPerSol;
      return fee;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> getEstimatedFee(SolanaPublicKey publicKey, Commitment commitment) async {
    final message = await _getMessageForNativeTransaction(
      publicKey: publicKey,
      destinationAddress: publicKey.toAddress().address,
      lamports: SolanaUtils.lamportsPerSol,
      commitment: commitment,
    );

    final estimatedFee = await _getFeeFromCompiledMessage(
      message,
      commitment,
    );
    return estimatedFee;
  }

  SolanaTransactionModel? parseTransaction({
    VersionedTransactionResponse? txResponse,
    required String address,
    String? tokenSymbol,
  }) {
    if (txResponse == null) return null;

    try {
      final blockTime = txResponse.blockTime;
      final meta = txResponse.meta;
      final transaction = txResponse.transaction;

      if (meta == null || transaction == null) return null;

      final int fee = meta.fee;

      final message = transaction.message;
      final instructions = message.compiledInstructions;

      String sender = "";
      String receiver = "";

      String signature = (txResponse.transaction?.signatures.isEmpty ?? true)
          ? ""
          : Base58Encoder.encode(txResponse.transaction!.signatures.first);

      for (final instruction in instructions) {
        final programId = message.accountKeys[instruction.programIdIndex];

        if (programId == SystemProgramConst.programId) {
          // For native solana transactions

          final senderIndex = instruction.accounts[0];
          final receiverIndex = instruction.accounts[1];

          sender = message.accountKeys[senderIndex].address;
          receiver = message.accountKeys[receiverIndex].address;

          final feeForTx = fee / SolanaUtils.lamportsPerSol;

          final preBalances = meta.preBalances;
          final postBalances = meta.postBalances;

          double amount =
              (((preBalances[senderIndex] - postBalances[senderIndex]) / BigInt.from(1e9))
                      .toDouble() -
                  feeForTx);

          return SolanaTransactionModel(
            isOutgoingTx: sender == address,
            from: sender,
            to: receiver,
            id: signature,
            amount: amount.abs(),
            programId: SystemProgramConst.programId.address,
            tokenSymbol: 'SOL',
            blockTimeInInt: blockTime?.toInt() ?? 0,
            fee: feeForTx,
          );
        } else if (programId == SPLTokenProgramConst.tokenProgramId) {
          // For SPL Token transactions
          if (instruction.accounts.length < 2) continue;

          final preBalances = meta.preTokenBalances;
          final postBalances = meta.postTokenBalances;

          double amount = 0.0;
          if (preBalances != null &&
              preBalances.isNotEmpty &&
              postBalances != null &&
              postBalances.isNotEmpty) {
            amount = ((preBalances.first.uiTokenAmount.uiAmount ?? 0) -
                    (postBalances.first.uiTokenAmount.uiAmount ?? 0))
                .toDouble();
          }

          sender = message.accountKeys[instruction.accounts[0]].address;
          receiver = message.accountKeys[instruction.accounts[1]].address;

          return SolanaTransactionModel(
            isOutgoingTx: sender == address,
            from: sender,
            to: receiver,
            id: signature,
            amount: amount,
            programId: SPLTokenProgramConst.tokenProgramId.address,
            blockTimeInInt: blockTime?.toInt() ?? 0,
            tokenSymbol: tokenSymbol ?? '',
            fee: fee / SolanaUtils.lamportsPerSol,
          );
        } else {
          return null;
        }
      }
    } catch (e, s) {
      printV("Error parsing transaction: $e\n$s");
    }

    return null;
  }

  /// Load the Address's transactions into the account
  Future<List<SolanaTransactionModel>> fetchTransactions(
    SolAddress address, {
    String? splTokenSymbol,
    int? splTokenDecimal,
    Commitment? commitment,
  }) async {
    List<SolanaTransactionModel> transactions = [];

    try {
      final signatures = await _provider!.request(
        SolanaRPCGetSignaturesForAddress(
          account: address,
          commitment: commitment,
        ),
      );

      final List<VersionedTransactionResponse?> transactionDetails = [];

      for (int i = 0; i < signatures.length; i += 20) {
        final batch = signatures.skip(i).take(20).toList(); // Get the next 20 signatures

        final batchResponses = await Future.wait(batch.map((signature) async {
          try {
            return await _provider!.request(
              SolanaRPCGetTransaction(
                transactionSignature: signature['signature'],
                encoding: SolanaRPCEncoding.jsonParsed,
                maxSupportedTransactionVersion: 0,
              ),
            );
          } catch (e) {
            printV("Error fetching transaction: $e");
            return null;
          }
        }));

        transactionDetails.addAll(batchResponses.whereType<VersionedTransactionResponse>());

        // to avoid reaching the node RPS limit
        if (i + 20 < signatures.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      for (final tx in transactionDetails) {
        final parsedTx = parseTransaction(
          txResponse: tx,
          tokenSymbol: splTokenSymbol,
          address: address.address,
        );
        if (parsedTx != null) {
          transactions.add(parsedTx);
        }
      }

      return transactions;
    } catch (err, s) {
      printV('Error fetching transactions: $err \n$s');
      return [];
    }
  }

  Future<List<SolanaTransactionModel>> getSPLTokenTransfers({
    required String address,
    required String splTokenSymbol,
    required int splTokenDecimal,
    required SolanaPrivateKey privateKey,
  }) async {
    ProgramDerivedAddress? associatedTokenAccount;

    try {
      associatedTokenAccount = await _getOrCreateAssociatedTokenAccount(
          payerPrivateKey: privateKey,
          mintAddress: SolAddress(address),
          ownerAddress: privateKey.publicKey().toAddress());
    } catch (e, s) {
      printV('$e \n $s');
    }

    if (associatedTokenAccount == null) return [];

    final accountPublicKey = associatedTokenAccount.address;

    final tokenTransactions = await fetchTransactions(
      accountPublicKey,
      splTokenSymbol: splTokenSymbol,
      splTokenDecimal: splTokenDecimal,
    );

    return tokenTransactions;
  }

  void stop() {}

  SolanaRPC? get getSolanaProvider => _provider;

  Future<PendingSolanaTransaction> signSolanaTransaction({
    required String tokenTitle,
    required int tokenDecimals,
    required double inputAmount,
    required String destinationAddress,
    required SolanaPrivateKey ownerPrivateKey,
    required bool isSendAll,
    required double solBalance,
    String? tokenMint,
    List<String> references = const [],
  }) async {
    const commitment = Commitment.confirmed;

    if (tokenTitle == CryptoCurrency.sol.title) {
      final pendingNativeTokenTransaction = await _signNativeTokenTransaction(
        inputAmount: inputAmount,
        destinationAddress: destinationAddress,
        ownerPrivateKey: ownerPrivateKey,
        commitment: commitment,
        isSendAll: isSendAll,
        solBalance: solBalance,
      );
      return pendingNativeTokenTransaction;
    } else {
      final pendingSPLTokenTransaction = _signSPLTokenTransaction(
        tokenDecimals: tokenDecimals,
        tokenMint: tokenMint!,
        inputAmount: inputAmount,
        ownerPrivateKey: ownerPrivateKey,
        destinationAddress: destinationAddress,
        commitment: commitment,
        solBalance: solBalance,
      );
      return pendingSPLTokenTransaction;
    }
  }

  Future<SolAddress> _getLatestBlockhash(Commitment commitment) async {
    final latestBlockhash = await _provider!.request(
      const SolanaRPCGetLatestBlockhash(),
    );

    return latestBlockhash.blockhash;
  }

  Future<Message> _getMessageForNativeTransaction({
    required SolanaPublicKey publicKey,
    required String destinationAddress,
    required int lamports,
    required Commitment commitment,
  }) async {
    final instructions = [
      SystemProgram.transfer(
        from: publicKey.toAddress(),
        layout: SystemTransferLayout(lamports: BigInt.from(lamports)),
        to: SolAddress(destinationAddress),
      ),
    ];

    final latestBlockhash = await _getLatestBlockhash(commitment);

    final message = Message.compile(
      transactionInstructions: instructions,
      payer: publicKey.toAddress(),
      recentBlockhash: latestBlockhash,
    );
    return message;
  }

  Future<Message> _getMessageForSPLTokenTransaction({
    required SolAddress ownerAddress,
    required SolAddress destinationAddress,
    required int tokenDecimals,
    required SolAddress mintAddress,
    required SolAddress sourceAccount,
    required int amount,
    required Commitment commitment,
  }) async {
    final instructions = [
      SPLTokenProgram.transferChecked(
        layout: SPLTokenTransferCheckedLayout(
          amount: BigInt.from(123456455345234234),
          decimals: tokenDecimals,
        ),
        mint: mintAddress,
        source: sourceAccount,
        destination: destinationAddress,
        owner: ownerAddress,
      )
    ];

    final latestBlockhash = await _getLatestBlockhash(commitment);

    final message = Message.compile(
      transactionInstructions: instructions,
      payer: ownerAddress,
      recentBlockhash: latestBlockhash,
    );
    return message;
  }

  Future<double> _getFeeFromCompiledMessage(Message message, Commitment commitment) async {
    final base64Message = base64Encode(message.serialize());

    final fee = await getFeeForMessage(base64Message, commitment);

    return fee;
  }

  Future<bool> hasSufficientFundsLeftForRent({
    required double inputAmount,
    required double solBalance,
    required double fee,
  }) async {
    final rent = await _provider!.request(
      SolanaRPCGetMinimumBalanceForRentExemption(
        size: SolanaTokenAccountUtils.accountSize,
      ),
    );

    final rentInSol = (rent.toDouble() / SolanaUtils.lamportsPerSol).toDouble();

    final remnant = solBalance - (inputAmount + fee);

    if (remnant > rentInSol) return true;

    return false;
  }

  Future<PendingSolanaTransaction> _signNativeTokenTransaction({
    required double inputAmount,
    required String destinationAddress,
    required SolanaPrivateKey ownerPrivateKey,
    required Commitment commitment,
    required bool isSendAll,
    required double solBalance,
  }) async {
    // Convert SOL to lamport
    int lamports = (inputAmount * SolanaUtils.lamportsPerSol).toInt();

    Message message = await _getMessageForNativeTransaction(
      publicKey: ownerPrivateKey.publicKey(),
      destinationAddress: destinationAddress,
      lamports: lamports,
      commitment: commitment,
    );

    SolAddress latestBlockhash = await _getLatestBlockhash(commitment);

    final fee = await _getFeeFromCompiledMessage(
      message,
      commitment,
    );

    bool hasSufficientFundsLeft = await hasSufficientFundsLeftForRent(
      inputAmount: inputAmount,
      fee: fee,
      solBalance: solBalance,
    );

    if (!hasSufficientFundsLeft) {
      throw SolanaSignNativeTokenTransactionRentException();
    }

    String serializedTransaction;
    if (isSendAll) {
      final feeInLamports = (fee * SolanaUtils.lamportsPerSol).toInt();
      final updatedLamports = lamports - feeInLamports;

      final transaction = _constructNativeTransaction(
        ownerPrivateKey: ownerPrivateKey,
        destinationAddress: destinationAddress,
        latestBlockhash: latestBlockhash,
        lamports: updatedLamports,
      );

      serializedTransaction = await _signTransactionInternal(
        ownerPrivateKey: ownerPrivateKey,
        transaction: transaction,
      );
    } else {
      final transaction = _constructNativeTransaction(
        ownerPrivateKey: ownerPrivateKey,
        destinationAddress: destinationAddress,
        latestBlockhash: latestBlockhash,
        lamports: lamports,
      );

      serializedTransaction = await _signTransactionInternal(
        ownerPrivateKey: ownerPrivateKey,
        transaction: transaction,
      );
    }

    sendTx() async => await sendTransaction(
          serializedTransaction: serializedTransaction,
          commitment: commitment,
        );

    final pendingTransaction = PendingSolanaTransaction(
      amount: inputAmount,
      serializedTransaction: serializedTransaction,
      destinationAddress: destinationAddress,
      sendTransaction: sendTx,
      fee: fee,
    );

    return pendingTransaction;
  }

  SolanaTransaction _constructNativeTransaction({
    required SolanaPrivateKey ownerPrivateKey,
    required String destinationAddress,
    required SolAddress latestBlockhash,
    required int lamports,
  }) {
    final owner = ownerPrivateKey.publicKey().toAddress();

    /// Create a transfer instruction to move funds from the owner to the receiver.
    final transferInstruction = SystemProgram.transfer(
      from: owner,
      layout: SystemTransferLayout(lamports: BigInt.from(lamports)),
      to: SolAddress(destinationAddress),
    );

    /// Construct a Solana transaction with the transfer instruction.
    return SolanaTransaction(
      instructions: [transferInstruction],
      recentBlockhash: latestBlockhash,
      payerKey: ownerPrivateKey.publicKey().toAddress(),
      type: TransactionType.v0,
    );
  }

  Future<ProgramDerivedAddress> _getOrCreateAssociatedTokenAccount({
    required SolanaPrivateKey payerPrivateKey,
    required SolAddress ownerAddress,
    required SolAddress mintAddress,
  }) async {
    final associatedTokenAccount = AssociatedTokenAccountProgramUtils.associatedTokenAccount(
      mint: mintAddress,
      owner: ownerAddress,
    );

    SolanaAccountInfo? accountInfo;
    try {
      accountInfo = await _provider!.request(
        SolanaRPCGetAccountInfo(account: associatedTokenAccount.address),
      );
    } catch (e) {
      accountInfo = null;
    }

    // If aacountInfo is null, signifies that the associatedTokenAccount has only been created locally and not been broadcasted to the blockchain.
    if (accountInfo != null) return associatedTokenAccount;

    final createAssociatedTokenAccount = AssociatedTokenAccountProgram.associatedTokenAccount(
      payer: payerPrivateKey.publicKey().toAddress(),
      associatedToken: associatedTokenAccount.address,
      owner: ownerAddress,
      mint: mintAddress,
    );

    final blockhash = await _getLatestBlockhash(Commitment.confirmed);

    final transaction = SolanaTransaction(
      payerKey: payerPrivateKey.publicKey().toAddress(),
      instructions: [createAssociatedTokenAccount],
      recentBlockhash: blockhash,
    );

    transaction.sign([payerPrivateKey]);

    await sendTransaction(
      serializedTransaction: transaction.serializeString(),
      commitment: Commitment.confirmed,
    );

    // Delay for propagation on the blockchain for newly created associated token addresses
    await Future.delayed(const Duration(seconds: 2));

    return associatedTokenAccount;
  }

  Future<PendingSolanaTransaction> _signSPLTokenTransaction({
    required int tokenDecimals,
    required String tokenMint,
    required double inputAmount,
    required String destinationAddress,
    required SolanaPrivateKey ownerPrivateKey,
    required Commitment commitment,
    required double solBalance,
  }) async {
    final mintAddress = SolAddress(tokenMint);

    // Input by the user
    final amount = (inputAmount * math.pow(10, tokenDecimals)).toInt();
    ProgramDerivedAddress? associatedSenderAccount;
    try {
      associatedSenderAccount = AssociatedTokenAccountProgramUtils.associatedTokenAccount(
        mint: mintAddress,
        owner: ownerPrivateKey.publicKey().toAddress(),
      );
    } catch (e) {
      associatedSenderAccount = null;
    }

    // Throw an appropriate exception if the sender has no associated
    // token account
    if (associatedSenderAccount == null) {
      throw SolanaNoAssociatedTokenAccountException(
        ownerPrivateKey.publicKey().toAddress().address,
        mintAddress.address,
      );
    }

    ProgramDerivedAddress? associatedRecipientAccount;
    try {
      associatedRecipientAccount = await _getOrCreateAssociatedTokenAccount(
        payerPrivateKey: ownerPrivateKey,
        mintAddress: mintAddress,
        ownerAddress: SolAddress(destinationAddress),
      );
    } catch (e) {
      associatedRecipientAccount = null;

      throw SolanaCreateAssociatedTokenAccountException(
        'Error fetching recipient associated token account: ${e.toString()}',
      );
    }

    final transferInstructions = SPLTokenProgram.transferChecked(
      layout: SPLTokenTransferCheckedLayout(
        amount: BigInt.from(amount),
        decimals: tokenDecimals,
      ),
      mint: mintAddress,
      source: associatedSenderAccount.address,
      destination: associatedRecipientAccount.address,
      owner: ownerPrivateKey.publicKey().toAddress(),
    );

    final latestBlockHash = await _getLatestBlockhash(commitment);

    final transaction = SolanaTransaction(
      payerKey: ownerPrivateKey.publicKey().toAddress(),
      instructions: [transferInstructions],
      recentBlockhash: latestBlockHash,
    );

    final message = await _getMessageForSPLTokenTransaction(
      ownerAddress: ownerPrivateKey.publicKey().toAddress(),
      tokenDecimals: tokenDecimals,
      mintAddress: mintAddress,
      destinationAddress: associatedRecipientAccount.address,
      sourceAccount: associatedSenderAccount.address,
      amount: amount,
      commitment: commitment,
    );

    final fee = await _getFeeFromCompiledMessage(message, commitment);

    bool hasSufficientFundsLeft = await hasSufficientFundsLeftForRent(
      inputAmount: 0,
      fee: fee,
      solBalance: solBalance,
    );

    if (!hasSufficientFundsLeft) {
      throw SolanaSignSPLTokenTransactionRentException();
    }

    final serializedTransaction = await _signTransactionInternal(
      ownerPrivateKey: ownerPrivateKey,
      transaction: transaction,
    );

    sendTx() async => await sendTransaction(
          serializedTransaction: serializedTransaction,
          commitment: commitment,
        );

    final pendingTransaction = PendingSolanaTransaction(
      amount: inputAmount,
      serializedTransaction: serializedTransaction,
      destinationAddress: destinationAddress,
      sendTransaction: sendTx,
      fee: fee,
    );
    return pendingTransaction;
  }

  Future<String> _signTransactionInternal({
    required SolanaPrivateKey ownerPrivateKey,
    required SolanaTransaction transaction,
  }) async {
    /// Sign the transaction with the owner's private key.
    final ownerSignature = ownerPrivateKey.sign(transaction.serializeMessage());
    transaction.addSignature(ownerPrivateKey.publicKey().toAddress(), ownerSignature);

    /// Serialize the transaction.
    final serializedTransaction = transaction.serializeString();

    return serializedTransaction;
  }

  Future<String> sendTransaction({
    required String serializedTransaction,
    required Commitment commitment,
  }) async {
    try {
      /// Send the transaction to the Solana network.
      final signature = await _provider!.request(
        SolanaRPCSendTransaction(
          encodedTransaction: serializedTransaction,
          commitment: commitment,
        ),
      );
      return signature;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<String?> getIconImageFromTokenUri(String uri) async {
    if (uri.isEmpty || uri == '…') return null;

    try {
      final response = await httpClient.get(Uri.parse(uri));

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonResponse['image'];
      } else {
        return null;
      }
    } catch (e) {
      printV('Error occurred while fetching token image: \n${e.toString()}');
      return null;
    }
  }
}
