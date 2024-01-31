part of 'nano.dart';

class CWNanoAccountList extends NanoAccountList {
  CWNanoAccountList(this._wallet);
  final Object _wallet;

  @override
  @computed
  ObservableList<NanoAccount> get accounts {
    final nanoWallet = _wallet as NanoWallet;
    final accounts = nanoWallet.walletAddresses.accountList.accounts
        .map((acc) => NanoAccount(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
    return ObservableList<NanoAccount>.of(accounts);
  }

  @override
  void update(Object wallet) {
    final nanoWallet = wallet as NanoWallet;
    nanoWallet.walletAddresses.accountList.update(null);
  }

  @override
  void refresh(Object wallet) {
    final nanoWallet = wallet as NanoWallet;
    nanoWallet.walletAddresses.accountList.refresh();
  }

  @override
  Future<List<NanoAccount>> getAll(Object wallet) async {
    final nanoWallet = wallet as NanoWallet;
    return (await nanoWallet.walletAddresses.accountList.getAll())
        .map((acc) => NanoAccount(id: acc.id, label: acc.label, balance: acc.balance))
        .toList();
  }

  @override
  Future<void> addAccount(Object wallet, {required String label}) async {
    final nanoWallet = wallet as NanoWallet;
    await nanoWallet.walletAddresses.accountList.addAccount(label: label);
  }

  @override
  Future<void> setLabelAccount(Object wallet,
      {required int accountIndex, required String label}) async {
    final nanoWallet = wallet as NanoWallet;
    await nanoWallet.walletAddresses.accountList
        .setLabelAccount(accountIndex: accountIndex, label: label);
  }
}

class CWNano extends Nano {
  @override
  NanoAccountList getAccountList(Object wallet) {
    return CWNanoAccountList(wallet);
  }

  @override
  Account getCurrentAccount(Object wallet) {
    final nanoWallet = wallet as NanoWallet;
    final acc = nanoWallet.walletAddresses.account;
    return Account(id: acc!.id, label: acc.label, balance: acc.balance);
  }

  @override
  void setCurrentAccount(Object wallet, int id, String label, String? balance) {
    final nanoWallet = wallet as NanoWallet;
    nanoWallet.walletAddresses.account = NanoAccount(id: id, label: label, balance: balance);
    nanoWallet.regenerateAddress();
  }

  @override
  List<String> getNanoWordList(String language) {
    return NanoMnemomics.WORDLIST;
  }

  @override
  WalletService createNanoWalletService(
      Box<WalletInfo> walletInfoSource, bool isDirect, bool isFlatpak) {
    return NanoWalletService(walletInfoSource, isDirect, isFlatpak);
  }

  @override
  Map<String, String> getKeys(Object wallet) {
    final nanoWallet = wallet as NanoWallet;
    final keys = nanoWallet.keys;
    return <String, String>{
      "seedKey": keys.seedKey,
    };
  }

  @override
  WalletCredentials createNanoNewWalletCredentials({
    required String name,
    String? password,
  }) =>
      NanoNewWalletCredentials(
        name: name,
        password: password,
      );

  @override
  WalletCredentials createNanoRestoreWalletFromSeedCredentials({
    required String name,
    required String password,
    required String mnemonic,
    DerivationType? derivationType,
  }) {
    if (derivationType == null) {
      // figure out the derivation type as best we can, otherwise set it to "unknown"
      if (mnemonic.split(" ").length == 12) {
        derivationType = DerivationType.bip39;
      } else {
        derivationType = DerivationType.unknown;
      }
    }

    return NanoRestoreWalletFromSeedCredentials(
      name: name,
      password: password,
      mnemonic: mnemonic,
      derivationType: derivationType,
    );
  }

  @override
  WalletCredentials createNanoRestoreWalletFromKeysCredentials({
    required String name,
    required String password,
    required String seedKey,
    DerivationType? derivationType,
  }) {
    if (derivationType == null) {
      // figure out the derivation type as best we can, otherwise set it to "unknown"
      if (seedKey.length == 64) {
        derivationType = DerivationType.nano;
      } else {
        derivationType = DerivationType.unknown;
      }
    }

    return NanoRestoreWalletFromKeysCredentials(
      name: name,
      password: password,
      seedKey: seedKey,
      derivationType: derivationType,
    );
  }

  @override
  Object createNanoTransactionCredentials(List<Output> outputs) {
    return NanoTransactionCredentials(
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
              ))
          .toList(),
    );
  }

  @override
  Future<void> changeRep(Object wallet, String address) async {
    if ((wallet as NanoWallet).transactionHistory.transactions.isEmpty) {
      throw Exception("Can't change representative without an existing transaction history");
    }
    return wallet.changeRep(address);
  }

  @override
  Future<bool> updateTransactions(Object wallet) async {
    return (wallet as NanoWallet).updateTransactions();
  }

  @override
  BigInt getTransactionAmountRaw(TransactionInfo transactionInfo) {
    return (transactionInfo as NanoTransactionInfo).amountRaw;
  }

  @override
  String getRepresentative(Object wallet) {
    return (wallet as NanoWallet).representative;
  }
}

class CWNanoUtil extends NanoUtil {
  @override
  bool isValidBip39Seed(String seed) {
    return NanoDerivations.isValidBip39Seed(seed);
  }

  // number util:

  static const int maxDecimalDigits = 6; // Max digits after decimal
  BigInt rawPerNano = BigInt.parse("1000000000000000000000000000000");
  BigInt rawPerNyano = BigInt.parse("1000000000000000000000000");
  BigInt rawPerBanano = BigInt.parse("100000000000000000000000000000");
  BigInt rawPerXMR = BigInt.parse("1000000000000");
  BigInt convertXMRtoNano = BigInt.parse("1000000000000000000");

  @override
  String getRawAsUsableString(String? raw, BigInt rawPerCur) {
    return NanoAmounts.getRawAsUsableString(raw, rawPerCur);
  }

  @override
  String getRawAccuracy(String? raw, BigInt rawPerCur) {
    return NanoAmounts.getRawAccuracy(raw, rawPerCur);
  }

  @override
  String getAmountAsRaw(String amount, BigInt rawPerCur) {
    return NanoAmounts.getAmountAsRaw(amount, rawPerCur);
  }

  @override
  Future<AccountInfoResponse?> getInfoFromSeedOrMnemonic(
    DerivationType derivationType, {
    String? seedKey,
    String? mnemonic,
    required Node node,
  }) async {
    NanoClient nanoClient = NanoClient();
    nanoClient.connect(node);
    late String publicAddress;

    if (seedKey != null) {
      if (seedKey.length == 64) {
        try {
          mnemonic = NanoDerivations.standardSeedToMnemonic(seedKey);
        } catch (e) {
          print("not a valid 'nano' seed key");
        }
      }
      if (derivationType == DerivationType.bip39) {
        publicAddress = await NanoDerivations.hdSeedToAddress(seedKey, index: 0);
      } else if (derivationType == DerivationType.nano) {
        publicAddress = await NanoDerivations.standardSeedToAddress(seedKey, index: 0);
      }
    }

    if (derivationType == DerivationType.bip39) {
      if (mnemonic != null) {
        seedKey = await NanoDerivations.hdMnemonicListToSeed(mnemonic.split(' '));
        publicAddress = await NanoDerivations.hdSeedToAddress(seedKey, index: 0);
      }
    }

    if (derivationType == DerivationType.nano) {
      if (mnemonic != null) {
        seedKey = await NanoDerivations.standardMnemonicToSeed(mnemonic);
        publicAddress = await NanoDerivations.standardSeedToAddress(seedKey, index: 0);
      }
    }

    AccountInfoResponse? accountInfo = await nanoClient.getAccountInfo(publicAddress);
    if (accountInfo == null) {
      accountInfo = AccountInfoResponse(
          frontier: "", balance: "0", representative: "", confirmationHeight: 0);
    }
    accountInfo.address = publicAddress;
    return accountInfo;
  }

  @override
  Future<List<DerivationType>> compareDerivationMethods({
    String? mnemonic,
    String? privateKey,
    required Node node,
  }) async {
    String? seedKey = privateKey;

    if (mnemonic?.split(' ').length == 12) {
      return [DerivationType.bip39];
    }
    if (seedKey?.length == 128) {
      return [DerivationType.bip39];
    } else if (seedKey?.length == 64) {
      try {
        mnemonic = NanoDerivations.standardSeedToMnemonic(seedKey!);
      } catch (e) {
        print("not a valid 'nano' seed key");
      }
    }

    late String publicAddressStandard;
    late String publicAddressBip39;

    try {
      NanoClient nanoClient = NanoClient();
      nanoClient.connect(node);

      if (mnemonic != null) {
        seedKey = await NanoDerivations.hdMnemonicListToSeed(mnemonic.split(' '));
        publicAddressBip39 = await NanoDerivations.hdSeedToAddress(seedKey, index: 0);

        seedKey = await NanoDerivations.standardMnemonicToSeed(mnemonic);
        publicAddressStandard = await NanoDerivations.standardSeedToAddress(seedKey, index: 0);
      } else if (seedKey != null) {
        try {
          publicAddressBip39 = await NanoDerivations.hdSeedToAddress(seedKey, index: 0);
        } catch (e) {
          return [DerivationType.nano];
        }
        try {
          publicAddressStandard = await NanoDerivations.standardSeedToAddress(seedKey, index: 0);
        } catch (e) {
          return [DerivationType.bip39];
        }
      }

      // check if account has a history:
      AccountInfoResponse? bip39Info;
      AccountInfoResponse? standardInfo;

      try {
        bip39Info = await nanoClient.getAccountInfo(publicAddressBip39);
      } catch (e) {
        bip39Info = null;
      }
      try {
        standardInfo = await nanoClient.getAccountInfo(publicAddressStandard);
      } catch (e) {
        standardInfo = null;
      }

      // one of these is *probably* null:
      if (bip39Info == null && standardInfo != null) {
        return [DerivationType.nano];
      } else if (standardInfo == null && bip39Info != null) {
        return [DerivationType.bip39];
      }

      // we don't know for sure:
      return [DerivationType.nano, DerivationType.bip39];
    } catch (e) {
      return [DerivationType.nano, DerivationType.bip39];
    }
  }
}
