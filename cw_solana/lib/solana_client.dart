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
import 'package:http/http.dart' as http;
import 'package:solana/dto.dart';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import '.secrets.g.dart' as secrets;

class SolanaWalletClient {
  final httpClient = http.Client();
  SolanaClient? _client;

  bool connect(Node node) {
    try {
      Uri rpcUri = node.uri;
      String webSocketUrl = 'wss://${node.uriRaw}';

      if (node.uriRaw == 'rpc.ankr.com') {
        String ankrApiKey = secrets.ankrApiKey;

        rpcUri = Uri.https(node.uriRaw, '/solana/$ankrApiKey');
        webSocketUrl = 'wss://${node.uriRaw}/solana/ws/$ankrApiKey';
      } else if (node.uriRaw == 'solana-mainnet.core.chainstack.com') {
        String chainStackApiKey = secrets.chainStackApiKey;

        rpcUri = Uri.https(node.uriRaw, '/$chainStackApiKey');
        webSocketUrl = 'wss://${node.uriRaw}/$chainStackApiKey';
      }

      _client = SolanaClient(
        rpcUrl: rpcUri,
        websocketUrl: Uri.parse(webSocketUrl),
        timeout: const Duration(minutes: 2),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<double> getBalance(String address) async {
    try {
      final balance = await _client!.rpcClient.getBalance(address);

      final solBalance = balance.value / lamportsPerSol;

      return solBalance;
    } catch (_) {
      return 0.0;
    }
  }

  Future<ProgramAccountsResult?> getSPLTokenAccounts(String mintAddress, String publicKey) async {
    try {
      final tokenAccounts = await _client!.rpcClient.getTokenAccountsByOwner(
        publicKey,
        TokenAccountsFilter.byMint(mintAddress),
        commitment: Commitment.confirmed,
        encoding: Encoding.jsonParsed,
      );
      return tokenAccounts;
    } catch (e) {
      return null;
    }
  }

  Future<SolanaBalance?> getSplTokenBalance(String mintAddress, String publicKey) async {
    // Fetch the token accounts (a token can have multiple accounts for various uses)
    final tokenAccounts = await getSPLTokenAccounts(mintAddress, publicKey);

    // Handle scenario where there is no token account
    if (tokenAccounts == null || tokenAccounts.value.isEmpty) {
      return null;
    }

    // Sum the balances of all accounts with the specified mint address
    double totalBalance = 0.0;

    for (var programAccount in tokenAccounts.value) {
      final tokenAmountResult =
          await _client!.rpcClient.getTokenAccountBalance(programAccount.pubkey);

      final balance = tokenAmountResult.value.uiAmountString;

      final balanceAsDouble = double.tryParse(balance ?? '0.0') ?? 0.0;

      totalBalance += balanceAsDouble;
    }

    return SolanaBalance(totalBalance);
  }

  Future<double> getFeeForMessage(String message, Commitment commitment) async {
    try {
      final feeForMessage =
          await _client!.rpcClient.getFeeForMessage(message, commitment: commitment);
      final fee = (feeForMessage ?? 0.0) / lamportsPerSol;
      return fee;
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> getEstimatedFee(Ed25519HDKeyPair ownerKeypair) async {
    const commitment = Commitment.confirmed;

    final message =
        _getMessageForNativeTransaction(ownerKeypair, ownerKeypair.address, lamportsPerSol);

    final latestBlockhash = await _getLatestBlockhash(commitment);

    final estimatedFee = _getFeeFromCompiledMessage(
      message,
      ownerKeypair.publicKey,
      latestBlockhash,
      commitment,
    );
    return estimatedFee;
  }

  /// Load the Address's transactions into the account
  Future<List<SolanaTransactionModel>> fetchTransactions(
    Ed25519HDPublicKey publicKey, {
    String? splTokenSymbol,
    int? splTokenDecimal,
  }) async {
    List<SolanaTransactionModel> transactions = [];

    try {
      final signatures = await _client!.rpcClient.getSignaturesForAddress(
        publicKey.toBase58(),
        commitment: Commitment.confirmed,
      );

      final List<TransactionDetails> transactionDetails = [];
      for (int i = 0; i < signatures.length; i += 20) {
        final response = await _client!.rpcClient.getMultipleTransactions(
          signatures.sublist(i, math.min(i + 20, signatures.length)),
          commitment: Commitment.confirmed,
          encoding: Encoding.jsonParsed,
        );
        transactionDetails.addAll(response);

        // to avoid reaching the node RPS limit
        await Future.delayed(const Duration(milliseconds: 500));
      }

      for (final tx in transactionDetails) {
        if (tx.transaction is ParsedTransaction) {
          final parsedTx = (tx.transaction as ParsedTransaction);
          final message = parsedTx.message;

          final fee = (tx.meta?.fee ?? 0) / lamportsPerSol;

          for (final instruction in message.instructions) {
            if (instruction is ParsedInstruction) {
              instruction.map(
                system: (systemData) {
                  systemData.parsed.map(
                    transfer: (transferData) {
                      ParsedSystemTransferInformation transfer = transferData.info;
                      bool isOutgoingTx = transfer.source == publicKey.toBase58();

                      double amount = transfer.lamports.toDouble() / lamportsPerSol;

                      transactions.add(
                        SolanaTransactionModel(
                          id: parsedTx.signatures.first,
                          from: transfer.source,
                          to: transfer.destination,
                          amount: amount,
                          isOutgoingTx: isOutgoingTx,
                          blockTimeInInt: tx.blockTime!,
                          fee: fee,
                          programId: SystemProgram.programId,
                          tokenSymbol: 'SOL',
                        ),
                      );
                    },
                    transferChecked: (_) {},
                    unsupported: (_) {},
                  );
                },
                splToken: (splTokenData) {
                  if (splTokenSymbol != null) {
                    splTokenData.parsed.map(
                      transfer: (transferData) {
                        SplTokenTransferInfo transfer = transferData.info;
                        bool isOutgoingTx = transfer.source == publicKey.toBase58();

                        double amount = (double.tryParse(transfer.amount) ?? 0.0) /
                            math.pow(10, splTokenDecimal ?? 9);

                        transactions.add(
                          SolanaTransactionModel(
                            id: parsedTx.signatures.first,
                            fee: fee,
                            from: transfer.source,
                            to: transfer.destination,
                            amount: amount,
                            isOutgoingTx: isOutgoingTx,
                            programId: TokenProgram.programId,
                            blockTimeInInt: tx.blockTime!,
                            tokenSymbol: splTokenSymbol,
                          ),
                        );
                      },
                      transferChecked: (transferCheckedData) {
                        SplTokenTransferCheckedInfo transfer = transferCheckedData.info;
                        bool isOutgoingTx = transfer.source == publicKey.toBase58();
                        double amount =
                            double.tryParse(transfer.tokenAmount.uiAmountString ?? '0.0') ?? 0.0;

                        transactions.add(
                          SolanaTransactionModel(
                            id: parsedTx.signatures.first,
                            fee: fee,
                            from: transfer.source,
                            to: transfer.destination,
                            amount: amount,
                            isOutgoingTx: isOutgoingTx,
                            programId: TokenProgram.programId,
                            blockTimeInInt: tx.blockTime!,
                            tokenSymbol: splTokenSymbol,
                          ),
                        );
                      },
                      generic: (genericData) {},
                    );
                  }
                },
                memo: (_) {},
                unsupported: (a) {},
              );
            }
          }
        }
      }

      return transactions;
    } catch (err) {
      return [];
    }
  }

  Future<List<SolanaTransactionModel>> getSPLTokenTransfers(
    String address,
    String splTokenSymbol,
    int splTokenDecimal,
    Ed25519HDKeyPair ownerKeypair,
  ) async {
    final tokenMint = Ed25519HDPublicKey.fromBase58(address);

    ProgramAccount? associatedTokenAccount;

    try {
      associatedTokenAccount = await _client!.getAssociatedTokenAccount(
        mint: tokenMint,
        owner: ownerKeypair.publicKey,
        commitment: Commitment.confirmed,
      );
    } catch (_) {}

    if (associatedTokenAccount == null) return [];

    final accountPublicKey = Ed25519HDPublicKey.fromBase58(associatedTokenAccount.pubkey);

    final tokenTransactions = await fetchTransactions(
      accountPublicKey,
      splTokenSymbol: splTokenSymbol,
      splTokenDecimal: splTokenDecimal,
    );

    return tokenTransactions;
  }

  void stop() {}

  SolanaClient? get getSolanaClient => _client;

  Future<PendingSolanaTransaction> signSolanaTransaction({
    required String tokenTitle,
    required int tokenDecimals,
    required double inputAmount,
    required String destinationAddress,
    required Ed25519HDKeyPair ownerKeypair,
    required bool isSendAll,
    required double solBalance,
    String? tokenMint,
    List<String> references = const [],
  }) async {
    const commitment = Commitment.confirmed;

    if (tokenTitle == CryptoCurrency.sol.title) {
      final pendingNativeTokenTransaction = await _signNativeTokenTransaction(
        tokenTitle: tokenTitle,
        tokenDecimals: tokenDecimals,
        inputAmount: inputAmount,
        destinationAddress: destinationAddress,
        ownerKeypair: ownerKeypair,
        commitment: commitment,
        isSendAll: isSendAll,
        solBalance: solBalance,
      );
      return pendingNativeTokenTransaction;
    } else {
      final pendingSPLTokenTransaction = _signSPLTokenTransaction(
        tokenTitle: tokenTitle,
        tokenDecimals: tokenDecimals,
        tokenMint: tokenMint!,
        inputAmount: inputAmount,
        destinationAddress: destinationAddress,
        ownerKeypair: ownerKeypair,
        commitment: commitment,
        solBalance: solBalance,
      );
      return pendingSPLTokenTransaction;
    }
  }

  Future<LatestBlockhash> _getLatestBlockhash(Commitment commitment) async {
    final latestBlockHashResult =
        await _client!.rpcClient.getLatestBlockhash(commitment: commitment).value;

    final latestBlockhash = LatestBlockhash(
      blockhash: latestBlockHashResult.blockhash,
      lastValidBlockHeight: latestBlockHashResult.lastValidBlockHeight,
    );

    return latestBlockhash;
  }

  Message _getMessageForNativeTransaction(
    Ed25519HDKeyPair ownerKeypair,
    String destinationAddress,
    int lamports,
  ) {
    final instructions = [
      SystemInstruction.transfer(
        fundingAccount: ownerKeypair.publicKey,
        recipientAccount: Ed25519HDPublicKey.fromBase58(destinationAddress),
        lamports: lamports,
      ),
    ];

    final message = Message(instructions: instructions);
    return message;
  }

  Future<double> _getFeeFromCompiledMessage(
    Message message,
    Ed25519HDPublicKey feePayer,
    LatestBlockhash latestBlockhash,
    Commitment commitment,
  ) async {
    final compile = message.compile(
      recentBlockhash: latestBlockhash.blockhash,
      feePayer: feePayer,
    );

    final base64Message = base64Encode(compile.toByteArray().toList());

    final fee = await getFeeForMessage(base64Message, commitment);

    return fee;
  }

  Future<bool> hasSufficientFundsLeftForRent({
    required double inputAmount,
    required double solBalance,
    required double fee,
  }) async {
    final rent =
        await _client!.getMinimumBalanceForMintRentExemption(commitment: Commitment.confirmed);

    final rentInSol = (rent / lamportsPerSol).toDouble();

    final remnant = solBalance - (inputAmount + fee);

    if (remnant > rentInSol) return true;

    return false;
  }

  Future<PendingSolanaTransaction> _signNativeTokenTransaction({
    required String tokenTitle,
    required int tokenDecimals,
    required double inputAmount,
    required String destinationAddress,
    required Ed25519HDKeyPair ownerKeypair,
    required Commitment commitment,
    required bool isSendAll,
    required double solBalance,
  }) async {
    // Convert SOL to lamport
    int lamports = (inputAmount * lamportsPerSol).toInt();

    Message message = _getMessageForNativeTransaction(ownerKeypair, destinationAddress, lamports);

    final signers = [ownerKeypair];

    LatestBlockhash latestBlockhash = await _getLatestBlockhash(commitment);

    final fee = await _getFeeFromCompiledMessage(
      message,
      signers.first.publicKey,
      latestBlockhash,
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

    SignedTx signedTx;
    if (isSendAll) {
      final feeInLamports = (fee * lamportsPerSol).toInt();
      final updatedLamports = lamports - feeInLamports;

      final updatedMessage =
          _getMessageForNativeTransaction(ownerKeypair, destinationAddress, updatedLamports);

      signedTx = await _signTransactionInternal(
        message: updatedMessage,
        signers: signers,
        commitment: commitment,
        latestBlockhash: latestBlockhash,
      );
    } else {
      signedTx = await _signTransactionInternal(
        message: message,
        signers: signers,
        commitment: commitment,
        latestBlockhash: latestBlockhash,
      );
    }

    sendTx() async => await sendTransaction(
          signedTransaction: signedTx,
          commitment: commitment,
        );

    final pendingTransaction = PendingSolanaTransaction(
      amount: inputAmount,
      signedTransaction: signedTx,
      destinationAddress: destinationAddress,
      sendTransaction: sendTx,
      fee: fee,
    );

    return pendingTransaction;
  }

  Future<PendingSolanaTransaction> _signSPLTokenTransaction({
    required String tokenTitle,
    required int tokenDecimals,
    required String tokenMint,
    required double inputAmount,
    required String destinationAddress,
    required Ed25519HDKeyPair ownerKeypair,
    required Commitment commitment,
    required double solBalance,
  }) async {
    final destinationOwner = Ed25519HDPublicKey.fromBase58(destinationAddress);
    final mint = Ed25519HDPublicKey.fromBase58(tokenMint);

    // Input by the user
    final amount = (inputAmount * math.pow(10, tokenDecimals)).toInt();

    ProgramAccount? associatedRecipientAccount;
    ProgramAccount? associatedSenderAccount;

    associatedRecipientAccount = await _client!.getAssociatedTokenAccount(
      mint: mint,
      owner: destinationOwner,
      commitment: commitment,
    );

    associatedSenderAccount = await _client!.getAssociatedTokenAccount(
      owner: ownerKeypair.publicKey,
      mint: mint,
      commitment: commitment,
    );

    // Throw an appropriate exception if the sender has no associated
    // token account
    if (associatedSenderAccount == null) {
      throw SolanaNoAssociatedTokenAccountException(ownerKeypair.address, mint.toBase58());
    }

    try {
      if (associatedRecipientAccount == null) {
        final derivedAddress = await findAssociatedTokenAddress(
          owner: destinationOwner,
          mint: mint,
        );

        final instruction = AssociatedTokenAccountInstruction.createAccount(
          mint: mint,
          address: derivedAddress,
          owner: destinationOwner,
          funder: ownerKeypair.publicKey,
        );

        final _signedTx = await _signTransactionInternal(
          message: Message.only(instruction),
          signers: [ownerKeypair],
          commitment: commitment,
          latestBlockhash: await _getLatestBlockhash(commitment),
        );

        await sendTransaction(
          signedTransaction: _signedTx,
          commitment: commitment,
        );

        associatedRecipientAccount = ProgramAccount(
          pubkey: derivedAddress.toBase58(),
          account: Account(
            owner: destinationOwner.toBase58(),
            lamports: 0,
            executable: false,
            rentEpoch: BigInt.zero,
            data: null,
          ),
        );

        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      throw SolanaCreateAssociatedTokenAccountException(e.toString());
    }

    final instruction = TokenInstruction.transfer(
      source: Ed25519HDPublicKey.fromBase58(associatedSenderAccount.pubkey),
      destination: Ed25519HDPublicKey.fromBase58(associatedRecipientAccount.pubkey),
      owner: ownerKeypair.publicKey,
      amount: amount,
    );

    final message = Message(instructions: [instruction]);

    final signers = [ownerKeypair];

    LatestBlockhash latestBlockhash = await _getLatestBlockhash(commitment);

    final fee = await _getFeeFromCompiledMessage(
      message,
      signers.first.publicKey,
      latestBlockhash,
      commitment,
    );

    bool hasSufficientFundsLeft = await hasSufficientFundsLeftForRent(
      inputAmount: 0,
      fee: fee,
      solBalance: solBalance,
    );

    if (!hasSufficientFundsLeft) {
      throw SolanaSignSPLTokenTransactionRentException();
    }

    final signedTx = await _signTransactionInternal(
      message: message,
      signers: signers,
      commitment: commitment,
      latestBlockhash: latestBlockhash,
    );

    sendTx() async {
      await Future.delayed(const Duration(seconds: 3));

      return await sendTransaction(
        signedTransaction: signedTx,
        commitment: commitment,
      );
    }

    final pendingTransaction = PendingSolanaTransaction(
      amount: inputAmount,
      signedTransaction: signedTx,
      destinationAddress: destinationAddress,
      sendTransaction: sendTx,
      fee: fee,
    );
    return pendingTransaction;
  }

  Future<SignedTx> _signTransactionInternal({
    required Message message,
    required List<Ed25519HDKeyPair> signers,
    required Commitment commitment,
    required LatestBlockhash latestBlockhash,
  }) async {
    final signedTx = await signTransaction(latestBlockhash, message, signers);

    return signedTx;
  }

  Future<String> sendTransaction({
    required SignedTx signedTransaction,
    required Commitment commitment,
  }) async {
    try {
      final signature = await _client!.rpcClient.sendTransaction(
        signedTransaction.encode(),
        preflightCommitment: commitment,
      );

      _client!.waitForSignatureStatus(signature, status: commitment);

      return signature;
    } catch (e) {
      printV('Error while sending transaction: ${e.toString()}');
      throw Exception(e);
    }
  }

  Future<String?> getIconImageFromTokenUri(String uri) async {
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
