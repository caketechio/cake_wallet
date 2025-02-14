part of 'bitcoin.dart';

class CWBitcoin extends Bitcoin {
  WalletCredentials createBitcoinRestoreWalletFromSeedCredentials({
    required String name,
    required String mnemonic,
    required String password,
    required List<DerivationInfo>? derivations,
    String? passphrase,
  }) =>
      BitcoinRestoreWalletFromSeedCredentials(
        name: name,
        mnemonic: mnemonic,
        password: password,
        passphrase: passphrase,
        derivations: derivations,
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
  TransactionPriority getMediumTransactionPriority() => ElectrumTransactionPriority.medium;

  @override
  List<String> getWordList() => wordlist;

  @override
  Map<String, String> getWalletKeys(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    final keys = bitcoinWallet.keys;

    return <String, String>{
      'wif': keys.wif,
      'privateKey': keys.privateKey,
      'publicKey': keys.publicKey
    };
  }

  @override
  List<TransactionPriority> getElectrumTransactionPriorities() =>
      BitcoinElectrumTransactionPriority.all;

  @override
  List<TransactionPriority> getBitcoinAPITransactionPriorities() =>
      BitcoinAPITransactionPriority.all;

  @override
  List<TransactionPriority> getTransactionPriorities(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeRates is ElectrumTransactionPriorities
        ? BitcoinElectrumTransactionPriority.all
        : BitcoinAPITransactionPriority.all;
  }

  @override
  List<TransactionPriority> getLitecoinTransactionPriorities() => LitecoinTransactionPriority.all;

  @override
  TransactionPriority deserializeBitcoinTransactionPriority(int raw) {
    try {
      return ElectrumTransactionPriority.deserialize(raw: raw);
    } catch (_) {
      return BitcoinAPITransactionPriority.deserialize(raw: raw);
    }
  }

  @override
  TransactionPriority deserializeLitecoinTransactionPriority(int raw) =>
      ElectrumTransactionPriority.deserialize(raw: raw);

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
        priority == ElectrumTransactionPriority.custom && feeRate != null ? feeRate : null;
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
      priority: priority,
      feeRate: bitcoinFeeRate,
      coinTypeToSpendFrom: coinTypeToSpendFrom,
    );
  }

  @override
  @computed
  List<ElectrumSubAddress> getSubAddresses(Object wallet) {
    final electrumWallet = wallet as ElectrumWallet;
    return [
      ...electrumWallet.walletAddresses.selectedReceiveAddresses,
      ...electrumWallet.walletAddresses.selectedChangeAddresses
    ]
        .map(
          (addr) => ElectrumSubAddress(
            id: addr.index,
            name: addr.name,
            address: addr.address,
            derivationPath: addr.derivationPath,
            txCount: addr.txCount,
            balance: addr.balance,
            isChange: addr.isChange,
          ),
        )
        .toList();
  }

  @override
  Future<int> estimateFakeSendAllTxAmount(Object wallet, TransactionPriority priority,
      {UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any}) async {
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
        getFeeRate(wallet, priority),
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
      BitcoinAmountUtils.bitcoinAmountToString(amount: amount);

  @override
  double formatterBitcoinAmountToDouble({required int amount}) =>
      BitcoinAmountUtils.bitcoinAmountToDouble(amount: amount);

  @override
  int formatterStringDoubleToBitcoinAmount(String amount) =>
      BitcoinAmountUtils.stringDoubleToBitcoinAmount(amount);

  @override
  TransactionPriorityLabel getTransactionPriorityWithLabel(
    TransactionPriority priority,
    int rate, {
    int? customRate,
  }) =>
      priority.getLabelWithRate(rate, customRate);

  @override
  String bitcoinTransactionPriorityWithLabel(
    TransactionPriority priority,
    int rate, {
    int? customRate,
  }) =>
      priority.labelWithRate(rate, customRate);

  @override
  List<BitcoinUnspent> getUnspents(Object wallet,
      {UnspentCoinType coinTypeToSpendFrom = UnspentCoinType.any}) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.unspentCoins.where((element) {
      switch (coinTypeToSpendFrom) {
        case UnspentCoinType.mweb:
          return element.bitcoinAddressRecord.type == SegwitAddressType.mweb;
        case UnspentCoinType.nonMweb:
          return element.bitcoinAddressRecord.type != SegwitAddressType.mweb;
        case UnspentCoinType.any:
          return true;
      }
    }).toList();
  }

  Future<void> updateUnspents(Object wallet) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    await bitcoinWallet.updateAllUnspents();
  }

  WalletService createBitcoinWalletService(
    Box<WalletInfo> walletInfoSource,
    Box<UnspentCoinsInfo> unspentCoinSource,
    bool alwaysScan,
    bool isDirect,
  ) {
    return BitcoinWalletService(
      walletInfoSource,
      unspentCoinSource,
      alwaysScan,
      isDirect,
    );
  }

  WalletService createLitecoinWalletService(
    Box<WalletInfo> walletInfoSource,
    Box<UnspentCoinsInfo> unspentCoinSource,
    bool alwaysScan,
    bool isDirect,
  ) {
    return LitecoinWalletService(
      walletInfoSource,
      unspentCoinSource,
      alwaysScan,
      isDirect,
    );
  }

  @override
  TransactionPriority getBitcoinTransactionPriorityMedium() => ElectrumTransactionPriority.fast;

  @override
  TransactionPriority getBitcoinTransactionPriorityCustom() => ElectrumTransactionPriority.custom;

  @override
  TransactionPriority getLitecoinTransactionPriorityMedium() => ElectrumTransactionPriority.medium;

  @override
  TransactionPriority getBitcoinTransactionPrioritySlow() => ElectrumTransactionPriority.medium;

  @override
  TransactionPriority getLitecoinTransactionPrioritySlow() => ElectrumTransactionPriority.slow;

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
  bool isReceiveOptionSP(ReceivePageOption option) {
    return option.value == BitcoinReceivePageOption.silent_payments.value;
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
        return SegwitAddressType.p2tr;
      case BitcoinReceivePageOption.p2wsh:
        return SegwitAddressType.p2wsh;
      case BitcoinReceivePageOption.mweb:
        return SegwitAddressType.mweb;
      case BitcoinReceivePageOption.p2wpkh:
      default:
        return SegwitAddressType.p2wpkh;
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
    return BtcTransaction.fromRaw(transactionHex).getVSize();
  }

  @override
  Future<bool> isChangeSufficientForFee(Object wallet, String txId, String newFee) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.isChangeSufficientForFee(txId, int.parse(newFee));
  }

  @override
  int getFeeAmountForOutputsWithFeeRate(
    Object wallet, {
    required int feeRate,
    required List<String> inputAddresses,
    required List<String> outputAddresses,
    String? memo,
    bool enableRBF = true,
  }) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeAmountWithFeeRate(
      feeRate,
      inputTypes: inputAddresses
          .map((addr) => BitcoinAddressUtils.addressTypeFromStr(addr, bitcoinWallet.network))
          .toList(),
      outputTypes: outputAddresses
          .map((addr) => BitcoinAddressUtils.addressTypeFromStr(addr, bitcoinWallet.network))
          .toList(),
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  @override
  int getFeeAmountForOutputsWithPriority(
    Object wallet, {
    required TransactionPriority priority,
    required List<String> inputAddresses,
    required List<String> outputAddresses,
    String? memo,
    bool enableRBF = true,
  }) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.feeAmountForPriority(
      priority,
      inputTypes: inputAddresses
          .map((addr) => BitcoinAddressUtils.addressTypeFromStr(addr, bitcoinWallet.network))
          .toList(),
      outputTypes: outputAddresses
          .map((addr) => BitcoinAddressUtils.addressTypeFromStr(addr, bitcoinWallet.network))
          .toList(),
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  @override
  Future<int> calculateEstimatedFee(
    Object wallet, {
    required TransactionPriority priority,
    required String outputAddress,
    String? memo,
    bool enableRBF = true,
  }) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.calculateEstimatedFee(
      priority,
      outputAddresses: [outputAddress],
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  @override
  Future<int> estimatedFeeForOutputWithFeeRate(
    Object wallet, {
    required int feeRate,
    required String outputAddress,
    String? memo,
    bool enableRBF = true,
  }) async {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.estimatedFeeForOutputsWithFeeRate(
      feeRate: feeRate,
      outputAddresses: [outputAddress],
      memo: memo,
      enableRBF: enableRBF,
    );
  }

  @override
  int getMaxCustomFeeRate(Object wallet) {
    final electrumWallet = wallet as ElectrumWallet;
    final feeRates = electrumWallet.feeRates;
    final maxFee = electrumWallet.feeRates is ElectrumTransactionPriorities
        ? BitcoinElectrumTransactionPriority.fast
        : BitcoinAPITransactionPriority.fastest;

    return (electrumWallet.feeRate(maxFee) * 10).round();
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
      return hardwareWalletService.getAvailableAccounts(account: index, limit: limit);
    } catch (err) {
      printV(err);
      throw err;
    }
  }

  @override
  Future<List<HardwareAccountData>> getHardwareWalletLitecoinAccounts(LedgerViewModel ledgerVM,
      {int index = 0, int limit = 5}) async {
    final hardwareWalletService = LitecoinHardwareWalletService(ledgerVM.connection);
    try {
      return hardwareWalletService.getAvailableAccounts(account: index, limit: limit);
    } catch (err) {
      printV(err);
      throw err;
    }
  }

  @override
  List<ElectrumSubAddress> getSilentPaymentAddresses(Object wallet) {
    final walletAddresses = (wallet as BitcoinWallet).walletAddresses as BitcoinWalletAddresses;
    return walletAddresses.silentPaymentAddresses
        .map((addr) => ElectrumSubAddress(
              id: addr.index,
              name: addr.name,
              address: addr.address,
              derivationPath: addr.derivationPath,
              txCount: addr.txCount,
              balance: addr.balance,
              isChange: addr.isChange,
            ))
        .toList();
  }

  @override
  List<ElectrumSubAddress> getSilentPaymentReceivedAddresses(Object wallet) {
    final walletAddresses = (wallet as BitcoinWallet).walletAddresses as BitcoinWalletAddresses;
    return walletAddresses.receivedSPAddresses
        .map((addr) => ElectrumSubAddress(
              id: addr.index,
              name: addr.name,
              address: addr.address,
              derivationPath: addr.derivationPath,
              txCount: addr.txCount,
              balance: addr.balance,
              isChange: addr.isChange,
            ))
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
    final bitcoinWallet = wallet as BitcoinWallet;
    return bitcoinWallet.silentPaymentsScanningActive;
  }

  @override
  Future<void> setScanningActive(Object wallet, bool active) async {
    final bitcoinWallet = wallet as BitcoinWallet;
    bitcoinWallet.setSilentPaymentsScanning(active);
  }

  @override
  Future<void> allowToSwitchNodesForScanning(Object wallet, bool allow) async {
    final bitcoinWallet = wallet as BitcoinWallet;
    bitcoinWallet.allowedToSwitchNodesForScanning = allow;
  }

  @override
  bool isTestnet(Object wallet) {
    final bitcoinWallet = wallet as ElectrumWallet;
    return bitcoinWallet.isTestnet;
  }

  @override
  Future<bool> checkIfMempoolAPIIsEnabled(Object wallet) async {
    final bitcoinWallet = wallet as BitcoinWallet;
    return await bitcoinWallet.mempoolAPIEnabled;
  }

  @override
  Future<int> getHeightByDate({required DateTime date, bool? bitcoinMempoolAPIEnabled}) async {
    if (bitcoinMempoolAPIEnabled ?? false) {
      try {
        final mempoolApi = ApiProvider.fromMempool(
          BitcoinNetwork.mainnet,
          baseUrl: "http://mempool.cakewallet.com:8999/api/v1",
        );

        return (await mempoolApi.getBlockTimestamp(date))["height"] as int;
      } catch (_) {}
    }
    return await getBitcoinHeightByDate(date: date);
  }

  @override
  int getLitecoinHeightByDate({required DateTime date}) => getLtcHeightByDate(date: date);

  @override
  Future<void> rescan(Object wallet, {required int height, bool? doSingleScan}) async {
    final bitcoinWallet = wallet as BitcoinWallet;
    bitcoinWallet.rescan(height: height, doSingleScan: doSingleScan);
  }

  @override
  Future<bool> getNodeIsElectrsSPEnabled(Object wallet) async {
    final bitcoinWallet = wallet as BitcoinWallet;
    return bitcoinWallet.getNodeSupportsSilentPayments();
  }

  @override
  void deleteSilentPaymentAddress(Object wallet, String address) {
    final walletAddresses = (wallet as BitcoinWallet).walletAddresses as BitcoinWalletAddresses;
    walletAddresses.deleteSilentPaymentAddress(address);
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

    //
    // TODO: this could be improved:
    return inputAddressesContainMweb || outputAddressesContainMweb;
  }

  String? getUnusedMwebAddress(Object wallet) {
    try {
      final electrumWallet = wallet as ElectrumWallet;
      final mwebAddress = (electrumWallet.walletAddresses as LitecoinWalletAddresses)
          .mwebAddresses
          .firstWhere((element) => !element.isUsed);
      return mwebAddress.address;
    } catch (_) {
      return null;
    }
  }

  String? getUnusedSegwitAddress(Object wallet) {
    try {
      final electrumWallet = wallet as ElectrumWallet;
      final segwitAddress = electrumWallet.walletAddresses.allAddresses
          .firstWhere((element) => !element.isUsed && element.type == SegwitAddressType.p2wpkh);
      return segwitAddress.address;
    } catch (_) {
      return null;
    }
  }
}
