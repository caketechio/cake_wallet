part of 'bitcoin.dart';

class CWBitcoin extends Bitcoin {
  WalletCredentials createBitcoinRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
    required DerivationType derivationType,
    required String derivationPath,
    String? passphrase,
  }) =>
      BitcoinRestoreWalletFromSeedCredentials(
        name: name,
        mnemonic: mnemonic,
        password: password,
        derivationType: derivationType,
        derivationPath: derivationPath,
        passphrase: passphrase,
      );

  @override
  WalletCredentials createBitcoinRestoreWalletFromWIFCredentials(
          {required String name,
          required String password,
          required String wif,
          WalletInfo? walletInfo}) =>
      BitcoinRestoreWalletFromWIFCredentials(
          name: name, password: password, wif: wif, walletInfo: walletInfo);

  @override
  WalletCredentials createBitcoinNewWalletCredentials({
    required String name,
    WalletInfo? walletInfo,
    String? password,
    String? passphrase,
    String? mnemonic,
    String? parentAddress,
  }) =>
      BitcoinNewWalletCredentials(
        name: name,
        walletInfo: walletInfo,
        password: password,
        passphrase: passphrase,
        mnemonic: mnemonic,
        parentAddress: parentAddress,
      );

  @override
  WalletCredentials createBitcoinHardwareWalletCredentials(
          {required String name,
          required HardwareAccountData accountData,
          WalletInfo? walletInfo}) =>
      BitcoinRestoreWalletFromHardware(
          name: name, hwAccountData: accountData, walletInfo: walletInfo);

  @override
  TransactionPriority getMediumTransactionPriority() => BitcoinTransactionPriority.medium;

  @override
  List<String> getWordList() => wordlist;

  @override
  Map<String, String?> getWalletKeys(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    final keys = bitcoinWallet.keys;

    return <String, String?>{
      'wif': keys.wif,
      'privateKey': keys.privateKey,
      'publicKey': keys.publicKey,
      'p2wpkhMainnetPubKey': keys.p2wpkhMainnetPubKey,
      'p2wpkhMainnetPrivKey': keys.p2wpkhMainnetPrivKey,
    };
  }

  @override
  List<TransactionPriority> getTransactionPriorities() => BitcoinTransactionPriority.all;

  @override
  List<TransactionPriority> getLitecoinTransactionPriorities() => LitecoinTransactionPriority.all;

  @override
  TransactionPriority deserializeBitcoinTransactionPriority(int raw) =>
      BitcoinTransactionPriority.deserialize(raw: raw);

  @override
  TransactionPriority deserializeLitecoinTransactionPriority(int raw) =>
      LitecoinTransactionPriority.deserialize(raw: raw);

  @override
  int getFeeRate(Object wallet, TransactionPriority priority) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeRate(priority);
  }

  @override
  Future<void> generateNewAddress(Object wallet, String label) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.walletAddresses.generateNewAddress(label: label);
    await wallet.save();
  }

  @override
  Future<void> updateAddress(Object wallet, String address, String label) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    bitcoinWallet.walletAddresses.updateAddress(address, label);
    await wallet.save();
  }

  @override
  Object createBitcoinTransactionCredentials(
    List<Output> outputs, {
    required TransactionPriority priority,
    int? feeRate,
    UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any,
  }) {
    final bitcoinFeeRate =
        priority == BitcoinTransactionPriority.custom && feeRate != null ? feeRate : null;
    return BitcoinTransactionCredentials(
      outputs
          .map((out) => OutputInfo(
              fiatAmount: out.fiatAmount,
              cryptoAmount: out.cryptoAmount,
              address: out.address,
              note: out.note,
              sendAll: out.sendAll,
              extractedAddress: out.extractedAddress,
              isParsedAddress: out.isParsedAddress,
              formattedCryptoAmount: out.formattedCryptoAmount,
              memo: out.memo))
          .toList(),
      priority: priority as BitcoinTransactionPriority,
      feeRate: bitcoinFeeRate,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
    );
  }

  @override
  @computed
  List<ElectrumSubAddress> getSubAddresses(Object wallet) {
    final electrumWallet = wallet as ElectrumWallet;
    return electrumWallet.walletAddresses.addressesByReceiveType
        .map((BaseBitcoinAddressRecord addr) => ElectrumSubAddress(
            id: addr.index,
            name: addr.name,
            address: addr.address,
            txCount: addr.txCount,
            balance: addr.balance,
            isChange: addr.isHidden))
        .toList();
  }

  @override
  Future<int> estimateFakeSendAllTxAmount(Object wallet, TransactionPriority priority) async {
    try {
      final sk = ECPrivate.random();
      final electrumWallet = wallet as ElectrumWallet;

      if (wallet.type == WalletType.bitcoinCash) {
        final p2pkhAddr = sk.getPublic().toP2pkhAddress();
        final estimatedTx = await electrumWallet.estimateSendAllTx(
          [BitcoinOutput(address: p2pkhAddr, value: BigInt.zero)],
          getFeeRate(wallet, priority as BitcoinCashTransactionPriority),
        );

        return estimatedTx.amount;
      }

      final p2shAddr = sk.getPublic().toP2pkhInP2sh();
      final estimatedTx = await electrumWallet.estimateSendAllTx(
        [BitcoinOutput(address: p2shAddr, value: BigInt.zero)],
        getFeeRate(
          wallet,
          wallet.type == WalletType.litecoin
              ? priority as LitecoinTransactionPriority
              : priority as BitcoinTransactionPriority,
        ),
      );

      return estimatedTx.amount;
    } catch (_) {
      return 0;
    }
  }

  @override
  String getAddress(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.address;
  }

  @override
  String formatterBitcoinAmountToString({required int amount}) =>
      bitcoinAmountToString(amount: amount);

  @override
  double formatterBitcoinAmountToDouble({required int amount}) =>
      bitcoinAmountToDouble(amount: amount);

  @override
  int formatterStringDoubleToBitcoinAmount(String amount) => stringDoubleToBitcoinAmount(amount);

  @override
  String bitcoinTransactionPriorityWithLabel(TransactionPriority priority, int rate,
          {int? customRate}) =>
      (priority as BitcoinTransactionPriority).labelWithRate(rate, customRate);

  @override
  List<BitcoinUnspent> getUnspents(Object wallet,
      {UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any}) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.unspentCoins.where((element) {
      switch (coinTypeToSpendFrom) {
        case UnspentCoinType.mweb:
          return element.bitcoinAddressRecord.type == SegwitAddresType.mweb;
        case UnspentCoinType.nonMweb:
          return element.bitcoinAddressRecord.type != SegwitAddresType.mweb;
        case UnspentCoinType.any:
          return true;
      }
    }).toList();
  }

  Future<void> updateUnspents(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.updateAllUnspents();
  }

  WalletService createBitcoinWalletService(Box<WalletInfo> walletInfoSource,
      Box<UnspentCoinsInfo> unspentCoinSource, bool alwaysScan, bool isDirect) {
    return BitcoinWalletService(walletInfoSource, unspentCoinSource, alwaysScan, isDirect);
  }

  WalletService createLitecoinWalletService(Box<WalletInfo> walletInfoSource,
      Box<UnspentCoinsInfo> unspentCoinSource, bool alwaysScan, bool isDirect) {
    return LitecoinWalletService(walletInfoSource, unspentCoinSource, alwaysScan, isDirect);
  }

  @override
  TransactionPriority getBitcoinTransactionPriorityMedium() => BitcoinTransactionPriority.medium;

  @override
  TransactionPriority getBitcoinTransactionPriorityCustom() => BitcoinTransactionPriority.custom;

  @override
  TransactionPriority getLitecoinTransactionPriorityMedium() => LitecoinTransactionPriority.medium;

  @override
  TransactionPriority getBitcoinTransactionPrioritySlow() => BitcoinTransactionPriority.slow;

  @override
  TransactionPriority getLitecoinTransactionPrioritySlow() => LitecoinTransactionPriority.slow;

  @override
  Future<void> setAddressType(Object wallet, dynamic option) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.walletAddresses.setAddressType(option as BitcoinAddressType);
  }

  @override
  ReceivePageOption getSelectedAddressType(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return BitcoinReceivePageOption.fromType(bitcoinWallet.walletAddresses.addressPageType);
  }

  @override
  bool hasSelectedSilentPayments(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.addressPageType == SilentPaymentsAddresType.p2sp;
  }

  @override
  List<ReceivePageOption> getBitcoinReceivePageOptions() => BitcoinReceivePageOption.all;

  @override
  List<ReceivePageOption> getLitecoinReceivePageOptions() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return BitcoinReceivePageOption.allLitecoin
          .where((element) => element != BitcoinReceivePageOption.mweb)
          .toList();
    }
    return BitcoinReceivePageOption.allLitecoin;
  }

  @override
  BitcoinAddressType getBitcoinAddressType(ReceivePageOption option) {
    switch (option) {
      case BitcoinReceivePageOption.p2pkh:
        return P2pkhAddressType.p2pkh;
      case BitcoinReceivePageOption.p2sh:
        return P2shAddressType.p2wpkhInP2sh;
      case BitcoinReceivePageOption.p2tr:
        return SegwitAddresType.p2tr;
      case BitcoinReceivePageOption.p2wsh:
        return SegwitAddresType.p2wsh;
      case BitcoinReceivePageOption.mweb:
        return SegwitAddresType.mweb;
      case BitcoinReceivePageOption.p2wpkh:
      default:
        return SegwitAddresType.p2wpkh;
    }
  }

  @override
  Future<List<DerivationType>> compareDerivationMethods(
      {required String mnemonic, required Node node}) async {
    if (await checkIfMnemonicIsElectrum2(mnemonic)) {
      return [DerivationType.electrum];
    }

    return [DerivationType.bip39, DerivationType.electrum];
  }

  int _countCharOccurrences(String str, String charToCount) {
    int count = 0;
    for (int i = 0; i < str.length; i++) {
      if (str[i] == charToCount) {
        count++;
      }
    }
    return count;
  }

  @override
  Future<List<DerivationInfo>> getDerivationsFromMnemonic({
    required String mnemonic,
    required Node node,
    String? passphrase,
  }) async {
    List<DerivationInfo> list = [];

    List<DerivationType> types = await compareDerivationMethods(mnemonic: mnemonic, node: node);
    if (types.length == 1 && types.first == DerivationType.electrum) {
      return [getElectrumDerivations()[DerivationType.electrum]!.first];
    }

    final electrumClient = ElectrumClient();
    await electrumClient.connectToUri(node.uri, useSSL: node.useSSL);

    late BasedUtxoNetwork network;
    switch (node.type) {
      case WalletType.litecoin:
        network = LitecoinNetwork.mainnet;
        break;
      case WalletType.bitcoin:
      default:
        network = BitcoinNetwork.mainnet;
        break;
    }

    for (DerivationType dType in electrum_derivations.keys) {
      late Uint8List seedBytes;
      if (dType == DerivationType.electrum) {
        seedBytes = await mnemonicToSeedBytes(mnemonic, passphrase: passphrase ?? "");
      } else if (dType == DerivationType.bip39) {
        seedBytes = bip39.mnemonicToSeed(mnemonic, passphrase: passphrase ?? '');
      }

      for (DerivationInfo dInfo in electrum_derivations[dType]!) {
        try {
          DerivationInfo dInfoCopy = DerivationInfo(
            derivationType: dInfo.derivationType,
            derivationPath: dInfo.derivationPath,
            description: dInfo.description,
            scriptType: dInfo.scriptType,
          );

          String balancePath = dInfoCopy.derivationPath!;
          int derivationDepth = _countCharOccurrences(balancePath, '/');

          // for BIP44
          if (derivationDepth == 3 || derivationDepth == 1) {
            // we add "/0" so that we generate account 0
            balancePath += "/0";
          }

          final hd = Bip32Slip10Secp256k1.fromSeed(seedBytes).derivePath(balancePath)
              as Bip32Slip10Secp256k1;

          // derive address at index 0:
          String? address;
          switch (dInfoCopy.scriptType) {
            case "p2wpkh":
              address = generateP2WPKHAddress(hd: hd, network: network, index: 0);
              break;
            case "p2pkh":
              address = generateP2PKHAddress(hd: hd, network: network, index: 0);
              break;
            case "p2wpkh-p2sh":
              address = generateP2SHAddress(hd: hd, network: network, index: 0);
              break;
            case "p2tr":
              address = generateP2TRAddress(hd: hd, network: network, index: 0);
              break;
            default:
              continue;
          }

          final sh = BitcoinAddressUtils.scriptHash(address, network: network);
          final history = await electrumClient.getHistory(sh);

          final balance = await electrumClient.getBalance(sh);
          dInfoCopy.balance = balance.entries.firstOrNull?.value.toString() ?? "0";
          dInfoCopy.address = address;
          dInfoCopy.transactionsCount = history.length;

          list.add(dInfoCopy);
        } catch (e, s) {
          print("derivationInfoError: $e");
          print("derivationInfoStack: $s");
        }
      }
    }

    // sort the list such that derivations with the most transactions are first:
    list.sort((a, b) => b.transactionsCount.compareTo(a.transactionsCount));

    return list;
  }

  @override
  Map<DerivationType, List<DerivationInfo>> getElectrumDerivations() {
    return electrum_derivations;
  }

  @override
  bool hasTaprootInput(PendingTransaction pendingTransaction) {
    return (pendingTransaction as PendingBitcoinTransaction).hasTaprootInputs;
  }

  @override
  Future<PendingBitcoinTransaction> replaceByFee(
      Object wallet, String transactionHash, String fee) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return await bitcoinWallet.replaceByFee(transactionHash, int.parse(fee));
  }

  @override
  Future<String?> canReplaceByFee(Object wallet, Object transactionInfo) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    final tx = transactionInfo as ElectrumTransactionInfo;
    return bitcoinWallet.canReplaceByFee(tx);
  }

  @override
  int getTransactionVSize(Object wallet, String transactionHex) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.transactionVSize(transactionHex);
  }

  @override
  Future<bool> isChangeSufficientForFee(Object wallet, String txId, String newFee) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.isChangeSufficientForFee(txId, int.parse(newFee));
  }

  @override
  int getFeeAmountForPriority(
      Object wallet, TransactionPriority priority, int inputsCount, int outputsCount,
      {int? size}) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeAmountForPriority(
        priority as BitcoinTransactionPriority, inputsCount, outputsCount);
  }

  @override
  int getEstimatedFeeWithFeeRate(Object wallet, int feeRate, int? amount,
      {int? outputsCount, int? size}) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.calculateEstimatedFeeWithFeeRate(
      feeRate,
      amount,
      outputsCount: outputsCount,
      size: size,
    );
  }

  @override
  int feeAmountWithFeeRate(Object wallet, int feeRate, int inputsCount, int outputsCount,
      {int? size}) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeAmountWithFeeRate(feeRate, inputsCount, outputsCount, size: size);
  }

  @override
  int getMaxCustomFeeRate(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return (bitcoinWallet.feeRate(BitcoinTransactionPriority.fast) * 10).round();
  }

  @override
  void setLedgerConnection(WalletBase wallet, ledger.LedgerConnection connection) {
    (wallet as ElectrumWallet).setLedgerConnection(connection);
  }

  @override
  Future<List<HardwareAccountData>> getHardwareWalletBitcoinAccounts(LedgerViewModel ledgerVM,
      {int index = 0, int limit = 5}) async {
    final hardwareWalletService = BitcoinHardwareWalletService(ledgerVM.connection);
    try {
      return hardwareWalletService.getAvailableAccounts(index: index, limit: limit);
    } catch (err) {
      print(err);
      throw err;
    }
  }

  @override
  Future<List<HardwareAccountData>> getHardwareWalletLitecoinAccounts(LedgerViewModel ledgerVM,
      {int index = 0, int limit = 5}) async {
    final hardwareWalletService = LitecoinHardwareWalletService(ledgerVM.connection);
    try {
      return hardwareWalletService.getAvailableAccounts(index: index, limit: limit);
    } catch (err) {
      print(err);
      throw err;
    }
  }

  @override
  List<ElectrumSubAddress> getSilentPaymentAddresses(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.silentAddresses
        .where((addr) => addr.type != SegwitAddresType.p2tr)
        .map((addr) => ElectrumSubAddress(
            id: addr.index,
            name: addr.name,
            address: addr.address,
            txCount: addr.txCount,
            balance: addr.balance,
            isChange: addr.isHidden))
        .toList();
  }

  @override
  List<ElectrumSubAddress> getSilentPaymentReceivedAddresses(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.walletAddresses.silentAddresses
        .where((addr) => addr.type == SegwitAddresType.p2tr)
        .map((addr) => ElectrumSubAddress(
            id: addr.index,
            name: addr.name,
            address: addr.address,
            txCount: addr.txCount,
            balance: addr.balance,
            isChange: addr.isHidden))
        .toList();
  }

  @override
  bool isBitcoinReceivePageOption(ReceivePageOption option) {
    return option is BitcoinReceivePageOption;
  }

  @override
  BitcoinAddressType getOptionToType(ReceivePageOption option) {
    return (option as BitcoinReceivePageOption).toType();
  }

  @override
  @computed
  bool getScanningActive(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.silentPaymentsScanningActive;
  }

  @override
  Future<void> setScanningActive(Object wallet, bool active) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    bitcoinWallet.setSilentPaymentsScanning(active);
  }

  @override
  bool isTestnet(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.isTestnet;
  }

  @override
  Future<bool> checkIfMempoolAPIIsEnabled(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return await bitcoinWallet.checkIfMempoolAPIIsEnabled();
  }

  @override
  Future<int> getHeightByDate({required DateTime date, bool? bitcoinMempoolAPIEnabled}) async {
    if (bitcoinMempoolAPIEnabled ?? false) {
      try {
        return await getBitcoinHeightByDateAPI(date: date);
      } catch (_) {}
    }
    return await getBitcoinHeightByDate(date: date);
  }

  @override
  int getLitecoinHeightByDate({required DateTime date}) => getLtcHeightByDate(date: date);

  @override
  Future<void> rescan(Object wallet, {required int height, bool? doSingleScan}) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    bitcoinWallet.rescan(height: height, doSingleScan: doSingleScan);
  }

  @override
  Future<bool> getNodeIsElectrsSPEnabled(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.getNodeSupportsSilentPayments();
  }

  @override
  void deleteSilentPaymentAddress(Object wallet, String address) {
    final bitcoinWallet = wallet as ElectrumWallet;
    bitcoinWallet.walletAddresses.deleteSilentPaymentAddress(address);
  }

  @override
  Future<void> updateFeeRates(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.updateFeeRates();
  }

  @override
  Future<void> setMwebEnabled(Object wallet, bool enabled) async {
    final litecoinWallet = wallet as LitecoinWallet;
    litecoinWallet.setMwebEnabled(enabled);
  }

  @override
  bool getMwebEnabled(Object wallet) {
    final litecoinWallet = wallet as LitecoinWallet;
    return litecoinWallet.mwebEnabled;
  }

  List<Output> updateOutputs(PendingTransaction pendingTransaction, List<Output> outputs) {
    final pendingTx = pendingTransaction as PendingBitcoinTransaction;

    if (!pendingTx.hasSilentPayment) {
      return outputs;
    }

    final updatedOutputs = outputs.map((output) {
      try {
        final pendingOut = pendingTx.outputs[outputs.indexOf(output)];
        final updatedOutput = output;

        updatedOutput.stealthAddress = P2trAddress.fromScriptPubkey(script: pendingOut.scriptPubKey)
            .toAddress(BitcoinNetwork.mainnet);
        return updatedOutput;
      } catch (_) {}

      return output;
    }).toList();

    return updatedOutputs;
  }

  @override
  bool txIsReceivedSilentPayment(TransactionInfo txInfo) {
    final tx = txInfo as ElectrumTransactionInfo;
    return tx.isReceivedSilentPayment;
  }

  @override
  bool txIsMweb(TransactionInfo txInfo) {
    final tx = txInfo as ElectrumTransactionInfo;

    List<String> inputAddresses = tx.inputAddresses ?? [];
    List<String> outputAddresses = tx.outputAddresses ?? [];
    bool inputAddressesContainMweb = false;
    bool outputAddressesContainMweb = false;

    for (var address in inputAddresses) {
      if (address.toLowerCase().contains('mweb')) {
        inputAddressesContainMweb = true;
        break;
      }
    }

    for (var address in outputAddresses) {
      if (address.toLowerCase().contains('mweb')) {
        outputAddressesContainMweb = true;
        break;
      }
    }

    // TODO: this could be improved:
    return inputAddressesContainMweb || outputAddressesContainMweb;
  }

  String? getUnusedMwebAddress(Object wallet) {
    try {
      final electrumWallet = wallet as ElectrumWallet;
      final mwebAddress =
          electrumWallet.walletAddresses.mwebAddresses.firstWhere((element) => !element.isUsed);
      return mwebAddress.address;
    } catch (_) {
      return null;
    }
  }

  String? getUnusedSegwitAddress(Object wallet) {
    try {
      final electrumWallet = wallet as ElectrumWallet;
      final segwitAddress = electrumWallet.walletAddresses.allAddresses
          .firstWhere((element) => !element.isUsed && element.type == SegwitAddresType.p2wpkh);
      return segwitAddress.address;
    } catch (_) {
      return null;
    }
  }
}
