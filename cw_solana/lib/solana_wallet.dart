import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_keys_file.dart';
import 'package:cw_solana/default_spl_tokens.dart';
import 'package:cw_solana/solana_balance.dart';
import 'package:cw_solana/solana_client.dart';
import 'package:cw_solana/solana_exceptions.dart';
import 'package:cw_solana/solana_transaction_credentials.dart';
import 'package:cw_solana/solana_transaction_history.dart';
import 'package:cw_solana/solana_transaction_info.dart';
import 'package:cw_solana/solana_transaction_model.dart';
import 'package:cw_solana/solana_wallet_addresses.dart';
import 'package:cw_solana/spl_token.dart';
import 'package:hex/hex.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_chain/solana/solana.dart' hide Store;
import 'package:bip39/bip39.dart' as bip39;
import 'package:blockchain_utils/blockchain_utils.dart';

part 'solana_wallet.g.dart';

class SolanaWallet = SolanaWalletBase with _$SolanaWallet;

abstract class SolanaWalletBase
    extends WalletBase<SolanaBalance, SolanaTransactionHistory, SolanaTransactionInfo>
    with Store, WalletKeysFile {
  SolanaWalletBase({
    required WalletInfo walletInfo,
    String? mnemonic,
    String? privateKey,
    required String password,
    SolanaBalance? initialBalance,
    required this.encryptionFileUtils,
    this.passphrase,
  })  : syncStatus = const NotConnectedSyncStatus(),
        _password = password,
        _mnemonic = mnemonic,
        _hexPrivateKey = privateKey,
        _client = SolanaWalletClient(),
        walletAddresses = SolanaWalletAddresses(walletInfo),
        balance = ObservableMap<CryptoCurrency, SolanaBalance>.of(
            {CryptoCurrency.sol: initialBalance ?? SolanaBalance(BigInt.zero.toDouble())}),
        super(walletInfo) {
    this.walletInfo = walletInfo;
    transactionHistory = SolanaTransactionHistory(
      walletInfo: walletInfo,
      password: password,
      encryptionFileUtils: encryptionFileUtils,
    );

    if (!CakeHive.isAdapterRegistered(SPLToken.typeId)) {
      CakeHive.registerAdapter(SPLTokenAdapter());
    }

    _sharedPrefs.complete(SharedPreferences.getInstance());
  }

  final String _password;
  final String? _mnemonic;
  final String? _hexPrivateKey;
  final EncryptionFileUtils encryptionFileUtils;

  late final SolanaWalletClient _client;

  @observable
  double? estimatedFee;

  Timer? _transactionsUpdateTimer;

  late final Box<SPLToken> splTokensBox;

  @override
  WalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, SolanaBalance> balance;

  final Completer<SharedPreferences> _sharedPrefs = Completer();

  @override
  Object get keys => throw UnimplementedError("keys");

  late final SolanaPrivateKey _solanaPrivateKey;

  late final SolanaPublicKey _solanaPublicKey;

  SolanaPublicKey get solanaPublicKey => _solanaPublicKey;

  SolanaPrivateKey get solanaPrivateKey => _solanaPrivateKey;

  String get solanaAddress => _solanaPublicKey.toAddress().address;

  @override
  String? get seed => _mnemonic;

  @override
  String get privateKey => _solanaPrivateKey.seedHex();

  @override
  WalletKeysData get walletKeysData => WalletKeysData(mnemonic: _mnemonic, privateKey: privateKey);

  Future<void> init() async {
    final boxName = "${walletInfo.name.replaceAll(" ", "_")}_${SPLToken.boxName}";

    splTokensBox = await CakeHive.openBox<SPLToken>(boxName);

    // Create the privatekey using either the mnemonic or the privateKey
    _solanaPrivateKey = await getPrivateKey(
      mnemonic: _mnemonic,
      privateKey: _hexPrivateKey,
    );

    // Extract the public key and wallet address
    _solanaPublicKey = _solanaPrivateKey.publicKey();

    walletInfo.address = _solanaPublicKey.toAddress().address;

    await walletAddresses.init();
    await transactionHistory.init();
    await save();
  }

  Future<SolanaPrivateKey> getPrivateKey({String? mnemonic, String? privateKey}) async {
    assert(mnemonic != null || privateKey != null);

    if (mnemonic != null) {
      final seed = bip39.mnemonicToSeed(mnemonic);

      // Derive a Solana private key from the seed
      final bip44 = Bip44.fromSeed(seed, Bip44Coins.solana);

      final childKey = bip44.deriveDefaultPath.change(Bip44Changes.chainExt);

      return SolanaPrivateKey.fromSeed(childKey.privateKey.raw);
    }

    try {
      final keypairBytes = Base58Decoder.decode(privateKey!);
      return SolanaPrivateKey.fromSeed(keypairBytes);
    } catch (_) {
      final privateKeyBytes = HEX.decode(privateKey!);
      return SolanaPrivateKey.fromBytes(privateKeyBytes);
    }
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) => 0;

  @override
  Future<void> changePassword(String password) => throw UnimplementedError("changePassword");

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    _client.stop();
    _transactionsUpdateTimer?.cancel();
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();

      final isConnected = _client.connect(node);

      if (!isConnected) {
        throw Exception("Solana Node connection failed");
      }

      _setTransactionUpdateTimer();

      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  Future<void> _getEstimatedFees() async {
    try {
      estimatedFee = await _client.getEstimatedFee(_solanaPublicKey, Commitment.confirmed);
      printV(estimatedFee.toString());
    } catch (e) {
      estimatedFee = 0.0;
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final solCredentials = credentials as SolanaTransactionCredentials;

    final outputs = solCredentials.outputs;

    final hasMultiDestination = outputs.length > 1;

    await _updateBalance();

    final CryptoCurrency transactionCurrency =
        balance.keys.firstWhere((element) => element.title == solCredentials.currency.title);

    final walletBalanceForCurrency = balance[transactionCurrency]!.balance;

    final solBalance = balance[CryptoCurrency.sol]!.balance;

    double totalAmount = 0.0;

    bool isSendAll = false;

    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw SolanaTransactionWrongBalanceException(transactionCurrency);
      }

      final totalAmountFromCredentials =
          outputs.fold(0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0));

      totalAmount = totalAmountFromCredentials.toDouble();

      if (walletBalanceForCurrency < totalAmount) {
        throw SolanaTransactionWrongBalanceException(transactionCurrency);
      }
    } else {
      final output = outputs.first;

      isSendAll = output.sendAll;

      if (isSendAll) {
        totalAmount = walletBalanceForCurrency;
      } else {
        final totalOriginalAmount = double.parse(output.cryptoAmount ?? '0.0');

        totalAmount = totalOriginalAmount;
      }

      if (walletBalanceForCurrency < totalAmount) {
        throw SolanaTransactionWrongBalanceException(transactionCurrency);
      }
    }

    String? tokenMint;
    // Token Mint is only needed for transactions that are not native tokens(non-SOL transactions)
    if (transactionCurrency.title != CryptoCurrency.sol.title) {
      tokenMint = (transactionCurrency as SPLToken).mintAddress;
    }

    final pendingSolanaTransaction = await _client.signSolanaTransaction(
      tokenMint: tokenMint,
      tokenTitle: transactionCurrency.title,
      inputAmount: totalAmount,
      ownerPrivateKey: _solanaPrivateKey,
      tokenDecimals: transactionCurrency.decimals,
      destinationAddress: solCredentials.outputs.first.isParsedAddress
          ? solCredentials.outputs.first.extractedAddress!
          : solCredentials.outputs.first.address,
      isSendAll: isSendAll,
      solBalance: solBalance,
    );

    return pendingSolanaTransaction;
  }

  @override
  Future<Map<String, SolanaTransactionInfo>> fetchTransactions() async => {};

  /// Fetches the native SOL transactions linked to the wallet Public Key
  Future<void> _updateNativeSOLTransactions() async {
    final transactions = await _client.fetchTransactions(_solanaPublicKey.toAddress());

    await _addTransactionsToTransactionHistory(transactions);
  }

  /// Fetches the SPL Tokens transactions linked to the token account Public Key
  Future<void> _updateSPLTokenTransactions() async {
    // List<SolanaTransactionModel> splTokenTransactions = [];

    // Make a copy of keys to avoid concurrent modification
    var tokenKeys = List<CryptoCurrency>.from(balance.keys);

    for (var token in tokenKeys) {
      if (token is SPLToken) {
        final tokenTxs = await _client.getSPLTokenTransfers(
          address: token.mintAddress,
          splTokenSymbol: token.symbol,
          splTokenDecimal: token.decimal,
          privateKey: _solanaPrivateKey,
        );

        // splTokenTransactions.addAll(tokenTxs);
        await _addTransactionsToTransactionHistory(tokenTxs);
      }
    }

    // await _addTransactionsToTransactionHistory(splTokenTransactions);
  }

  Future<void> _addTransactionsToTransactionHistory(
    List<SolanaTransactionModel> transactions,
  ) async {
    final Map<String, SolanaTransactionInfo> result = {};

    for (var transactionModel in transactions) {
      result[transactionModel.id] = SolanaTransactionInfo(
        id: transactionModel.id,
        to: transactionModel.to,
        from: transactionModel.from,
        blockTime: transactionModel.blockTime,
        direction: transactionModel.isOutgoingTx
            ? TransactionDirection.outgoing
            : TransactionDirection.incoming,
        solAmount: transactionModel.amount,
        isPending: false,
        txFee: transactionModel.fee,
        tokenSymbol: transactionModel.tokenSymbol,
      );
    }

    transactionHistory.addMany(result);

    await transactionHistory.save();
  }

  @override
  Future<void> rescan({required int height}) => throw UnimplementedError("rescan");

  @override
  Future<void> save() async {
    if (!(await WalletKeysFile.hasKeysFile(walletInfo.name, walletInfo.type))) {
      await saveKeysFile(_password, encryptionFileUtils);
      saveKeysFile(_password, encryptionFileUtils, true);
    }

    await walletAddresses.updateAddressesInBox();
    final path = await makePath();
    await encryptionFileUtils.write(path: path, password: _password, data: toJSON());
    await transactionHistory.save();
  }

  @action
  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();

      await Future.wait([
        _updateBalance(),
        _updateNativeSOLTransactions(),
        _updateSPLTokenTransactions(),
        _getEstimatedFees(),
      ]);

      syncStatus = SyncedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
    }
  }

  String toJSON() => json.encode({
        'mnemonic': _mnemonic,
        'private_key': _hexPrivateKey,
        'balance': balance[currency]!.toJSON(),
      });

  static Future<SolanaWallet> open({
    required String name,
    required String password,
    required WalletInfo walletInfo,
    required EncryptionFileUtils encryptionFileUtils,
  }) async {
    final hasKeysFile = await WalletKeysFile.hasKeysFile(name, walletInfo.type);
    final path = await pathForWallet(name: name, type: walletInfo.type);

    Map<String, dynamic>? data;
    try {
      final jsonSource = await encryptionFileUtils.read(path: path, password: password);

      data = json.decode(jsonSource) as Map<String, dynamic>;
    } catch (e) {
      if (!hasKeysFile) rethrow;
    }

    final balance = SolanaBalance.fromJSON(data?['balance'] as String) ?? SolanaBalance(0.0);

    final WalletKeysData keysData;
    // Migrate wallet from the old scheme to then new .keys file scheme
    if (!hasKeysFile) {
      final mnemonic = data!['mnemonic'] as String?;
      final privateKey = data['private_key'] as String?;

      keysData = WalletKeysData(mnemonic: mnemonic, privateKey: privateKey);
    } else {
      keysData = await WalletKeysFile.readKeysFile(
        name,
        walletInfo.type,
        password,
        encryptionFileUtils,
      );
    }

    return SolanaWallet(
      walletInfo: walletInfo,
      password: password,
      mnemonic: keysData.mnemonic,
      privateKey: keysData.privateKey,
      initialBalance: balance,
      encryptionFileUtils: encryptionFileUtils,
    );
  }

  Future<void> _updateBalance() async {
    balance[currency] = await _fetchSOLBalance();
    await _fetchSPLTokensBalances();
    await save();
  }

  Future<SolanaBalance> _fetchSOLBalance() async {
    final balance = await _client.getBalance(solanaAddress);

    return SolanaBalance(balance);
  }

  Future<void> _fetchSPLTokensBalances() async {
    for (var token in splTokensBox.values) {
      if (token.enabled) {
        try {
          final tokenBalance = await _client.getSplTokenBalance(token.mintAddress, solanaAddress) ??
              balance[token] ??
              SolanaBalance(0.0);
          balance[token] = tokenBalance;
        } catch (e) {
          printV('Error fetching spl token (${token.symbol}) balance ${e.toString()}');
        }
      } else {
        balance.remove(token);
      }
    }
  }

  @override
  Future<void>? updateBalance() async => await _updateBalance();

  List<SPLToken> get splTokenCurrencies => splTokensBox.values.toList();

  void addInitialTokens() {
    final initialSPLTokens = DefaultSPLTokens().initialSPLTokens;

    for (var token in initialSPLTokens) {
      splTokensBox.put(token.mintAddress, token);
    }
  }

  Future<void> addSPLToken(SPLToken token) async {
    await splTokensBox.put(token.mintAddress, token);

    if (token.enabled) {
      final tokenBalance = await _client.getSplTokenBalance(token.mintAddress, solanaAddress) ??
          balance[token] ??
          SolanaBalance(0.0);

      balance[token] = tokenBalance;
    } else {
      balance.remove(token);
    }
  }

  Future<void> deleteSPLToken(SPLToken token) async {
    await token.delete();

    balance.remove(token);
    await _removeTokenTransactionsInHistory(token);
    _updateBalance();
  }

  Future<void> _removeTokenTransactionsInHistory(SPLToken token) async {
    transactionHistory.transactions.removeWhere((key, value) => value.tokenSymbol == token.title);
    await transactionHistory.save();
  }

  Future<SPLToken?> getSPLToken(String mintAddress) async {
    try {
      final programAddress =
          MetaplexTokenMetaDataProgramUtils.findMetadataPda(mint: SolAddress(mintAddress));

      final token = await _client.getSolanaProvider!.request(
        SolanaRPCGetMetadataAccount(
          account: programAddress.address,
          commitment: Commitment.confirmed,
        ),
      );

      if (token == null) {
        return null;
      }

      final metadata = token.data;

      String? iconPath;
      //TODO(Further explore fetching images)
      // try {
      //   iconPath = await _client.getIconImageFromTokenUri(metadata.uri);
      // } catch (_) {}

      String filteredTokenSymbol = metadata.symbol.replaceFirst(RegExp('^\\\$'), '');

      return SPLToken.fromMetadata(
        name: metadata.name,
        mint: metadata.symbol,
        symbol: filteredTokenSymbol,
        mintAddress: token.mint.address,
        iconPath: iconPath,
      );
    } catch (e, s) {
      printV('Error fetching token: ${e.toString()}, ${s.toString()}');
      return null;
    }
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletPath = await pathForWallet(name: walletInfo.name, type: type);
    final currentWalletFile = File(currentWalletPath);

    final currentDirPath = await pathForWalletDir(name: walletInfo.name, type: type);
    final currentTransactionsFile = File('$currentDirPath/$transactionsHistoryFileName');

    // Copies current wallet files into new wallet name's dir and files
    if (currentWalletFile.existsSync()) {
      final newWalletPath = await pathForWallet(name: newWalletName, type: type);
      await currentWalletFile.copy(newWalletPath);
    }
    if (currentTransactionsFile.existsSync()) {
      final newDirPath = await pathForWalletDir(name: newWalletName, type: type);
      await currentTransactionsFile.copy('$newDirPath/$transactionsHistoryFileName');
    }

    // Delete old name's dir and files
    await Directory(currentDirPath).delete(recursive: true);
  }

  void _setTransactionUpdateTimer() {
    if (_transactionsUpdateTimer?.isActive ?? false) {
      _transactionsUpdateTimer!.cancel();
    }

    _transactionsUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBalance();
      _updateNativeSOLTransactions();
      _updateSPLTokenTransactions();
    });
  }

  @override
  Future<String> signMessage(String message, {String? address}) async {
    // Convert the message to bytes
    final messageBytes = utf8.encode(message);

    // Sign the message bytes with the wallet's private key
    final signature = (_solanaPrivateKey.sign(messageBytes)).toString();

    return HEX.encode(utf8.encode(signature)).toUpperCase();
  }

  List<List<int>> bytesFromSigString(String signatureString) {
    final regex = RegExp(r'Signature\(\[(.+)\], publicKey: (.+)\)');
    final match = regex.firstMatch(signatureString);

    if (match != null) {
      final bytesString = match.group(1)!;
      final base58EncodedPublicKeyString = match.group(2)!;
      final sigBytes = bytesString.split(', ').map(int.parse).toList();

      List<int> pubKeyBytes = SolAddrDecoder().decodeAddr(base58EncodedPublicKeyString);

      return [sigBytes, pubKeyBytes];
    } else {
      throw const FormatException('Invalid Signature string format');
    }
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address}) async {
    String signatureString = utf8.decode(HEX.decode(signature));

    List<List<int>> bytes = bytesFromSigString(signatureString);

    final messageBytes = utf8.encode(message);
    final sigBytes = bytes[0];
    final pubKeyBytes = bytes[1];

    if (address == null) {
      return false;
    }

    // make sure the address derived from the public key provided matches the one we expect
    final pub = SolanaPublicKey.fromBytes(pubKeyBytes);
    if (address != pub.toAddress().address) {
      return false;
    }

    return pub.verify(
      message: messageBytes,
      signature: sigBytes,
    );
  }

  SolanaRPC? get solanaProvider => _client.getSolanaProvider;

  @override
  String get password => _password;

  @override
  final String? passphrase;
}
