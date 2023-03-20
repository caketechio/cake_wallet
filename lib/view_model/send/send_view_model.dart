import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/entities/format_amount.dart';
import 'package:cake_wallet/entities/transaction_description.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cake_wallet/view_model/send/output.dart';
import 'package:cake_wallet/view_model/send/send_template_view_model.dart';
import 'package:hive/hive.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/entities/template.dart';
import 'package:cake_wallet/core/address_validator.dart';
import 'package:cake_wallet/core/amount_validator.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cake_wallet/core/validator.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/entities/calculate_fiat_amount.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/send/send_view_model_state.dart';
import 'package:cake_wallet/entities/parsed_address.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/entities/calculate_fiat_amount_raw.dart';

part 'send_view_model.g.dart';

class SendViewModel = SendViewModelBase with _$SendViewModel;

abstract class SendViewModelBase with Store {
  SendViewModelBase(
      this._wallet,
      this._settingsStore,
      this.sendTemplateViewModel,
      this._fiatConversationStore,
      this.balanceViewModel,
      this.transactionDescriptionBox)
      : state = InitialExecutionState(),
        currencies = _wallet.balance.keys.toList(),
        selectedCryptoCurrency = _wallet.currency,
        outputs = ObservableList<Output>(),
        fiatFromSettings = _settingsStore.fiatCurrency {
    final priority = _settingsStore.priority[_wallet.type];
    final priorities = priorityForWalletType(_wallet.type);

    if (!priorityForWalletType(_wallet.type).contains(priority)) {
      _settingsStore.priority[_wallet.type] = priorities.first;
    }

    outputs.add(Output(_wallet, _settingsStore, _fiatConversationStore, () => selectedCryptoCurrency));

    _settingsStore.priority.observe((change) async {
      if (change.newValue != null) {
        _wallet.feeEstimate.update(priority: change.newValue!, outputsCount: outputs.length);
      }
    });

    estimateFee();
  }

  @observable
  ExecutionState state;

  ObservableList<Output> outputs;

  @action
  void addOutput() {
    outputs.add(Output(_wallet, _settingsStore, _fiatConversationStore, () => selectedCryptoCurrency));
  }

  @action
  void removeOutput(Output output) {
    if (isBatchSending) {
      outputs.remove(output);
    }
  }

  @action
  void clearOutputs() {
    outputs.clear();
    addOutput();
  }

  @computed
  bool get isBatchSending => outputs.length > 1;

  @computed
  String get pendingTransactionFiatAmount {
    try {
      if (pendingTransaction != null) {
        return _calculateFiatAmount(pendingTransaction!.amountFormatted);
      } else {
        return '0.00';
      }
    } catch (_) {
      return '0.00';
    }
  }

  @computed
  String get pendingTransactionFeeFiatAmount {
    try {
      if (pendingTransaction != null) {
        return _calculateFiatAmount(pendingTransaction!.feeFormatted);
      } else {
        return '0.00';
      }
    } catch (_) {
      return '0.00';
    }
  }

  String _calculateFiatAmount(String cryptoAmount) {
    return calculateFiatAmount(
          price: _fiatConversationStore.prices[selectedCryptoCurrency],
          cryptoAmount: cryptoAmount);
  }

  FiatCurrency get fiat => _settingsStore.fiatCurrency;

  TransactionPriority get transactionPriority {
    final priority = _settingsStore.priority[_wallet.type];

    if (priority == null) {
      throw Exception('Unexpected type ${_wallet.type}');
    }

    return priority;
  }

  CryptoCurrency get currency => _wallet.currency;

  Validator get amountValidator =>
      AmountValidator(currency: walletTypeToCryptoCurrency(_wallet.type));

  Validator get allAmountValidator => AllAmountValidator();

  Validator get addressValidator => AddressValidator(type: selectedCryptoCurrency);

  Validator get textValidator => TextValidator();

  final FiatCurrency fiatFromSettings;

  @observable
  PendingTransaction? pendingTransaction;

  @computed
  String get balance => balanceViewModel.availableBalance;

  @computed
  bool get isFiatDisabled => balanceViewModel.isFiatDisabled;

  @computed
  String get pendingTransactionFiatAmountFormatted =>
      isFiatDisabled ? '' : pendingTransactionFiatAmount +
          ' ' + fiat.title;

  @computed
  String get pendingTransactionFeeFiatAmountFormatted =>
      isFiatDisabled ? '' : pendingTransactionFeeFiatAmount +
          ' ' + fiat.title;

  @computed
  bool get isReadyForSend => _wallet.syncStatus is SyncedSyncStatus;

  @computed
  List<Template> get templates => sendTemplateViewModel.templates
      .where((template) => _isEqualCurrency(template.cryptoCurrency))
      .toList();

  @computed
  bool get isElectrumWallet =>
      _wallet.type == WalletType.bitcoin || _wallet.type == WalletType.litecoin;

  @observable
  CryptoCurrency selectedCryptoCurrency;

  List<CryptoCurrency> currencies;

  bool get hasMultiRecipient => _wallet.type != WalletType.haven;

  bool get hasYat => outputs.any((out) =>
      out.isParsedAddress &&
      out.parsedAddress.parseFrom == ParseFrom.yatRecord);

  WalletType get walletType => _wallet.type;

  String? get walletCurrencyName =>
      _wallet.currency.fullName?.toLowerCase() ?? _wallet.currency.name;

  bool get hasCurrecyChanger => walletType == WalletType.haven;

  @computed
  FiatCurrency get fiatCurrency => _settingsStore.fiatCurrency;

  final WalletBase _wallet;
  final SettingsStore _settingsStore;
  final SendTemplateViewModel sendTemplateViewModel;
  final BalanceViewModel balanceViewModel;
  final FiatConversionStore _fiatConversationStore;
  final Box<TransactionDescription> transactionDescriptionBox;

  @action
  Future<void> createTransaction() async {
    try {
      state = IsExecutingState();
      pendingTransaction = await _wallet.createTransaction(_credentials());
      state = ExecutedSuccessfullyState();
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  @action
  Future<void> commitTransaction() async {
    if (pendingTransaction == null) {
      throw Exception("Pending transaction doesn't exist. It should not be happened.");
    }

    String address = outputs.fold('', (acc, value) {
      return value.isParsedAddress
          ? acc + value.address + '\n' + value.extractedAddress + '\n\n'
          : acc + value.address + '\n\n';
    });

    address = address.trim();

    String note = outputs.fold('', (acc, value) {
      return acc + value.note + '\n';
    });

    note = note.trim();

    try {
      state = TransactionCommitting();
      await pendingTransaction!.commit();

      if (pendingTransaction!.id.isNotEmpty) {
        _settingsStore.shouldSaveRecipientAddress
            ? await transactionDescriptionBox.add(TransactionDescription(
                id: pendingTransaction!.id,
                recipientAddress: address,
                transactionNote: note))
            : await transactionDescriptionBox.add(TransactionDescription(
                id: pendingTransaction!.id, transactionNote: note));
      }

      state = TransactionCommitted();
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  @action
  void setTransactionPriority(TransactionPriority priority) =>
      _settingsStore.priority[_wallet.type] = priority;

  Object _credentials() {
    switch (_wallet.type) {
      case WalletType.bitcoin:
        final priority = _settingsStore.priority[_wallet.type];

        if (priority == null) {
          throw Exception('Priority is null for wallet type: ${_wallet.type}');
        }

        return bitcoin!.createBitcoinTransactionCredentials(outputs, priority: priority);
      case WalletType.litecoin:
        final priority = _settingsStore.priority[_wallet.type];

        if (priority == null) {
          throw Exception('Priority is null for wallet type: ${_wallet.type}');
        }

        return bitcoin!.createBitcoinTransactionCredentials(outputs, priority: priority);
      case WalletType.monero:
        final priority = _settingsStore.priority[_wallet.type];

        if (priority == null) {
          throw Exception('Priority is null for wallet type: ${_wallet.type}');
        }

        return monero!.createMoneroTransactionCreationCredentials(
            outputs: outputs, priority: priority);
      case WalletType.haven:
        final priority = _settingsStore.priority[_wallet.type];

        if (priority == null) {
          throw Exception('Priority is null for wallet type: ${_wallet.type}');
        }

        return haven!.createHavenTransactionCreationCredentials(
            outputs: outputs, priority: priority, assetType: selectedCryptoCurrency.title);
      default:
        throw Exception('Unexpected wallet type: ${_wallet.type}');
    }
  }

  String displayFeeRate(dynamic priority) {
    final _priority = priority as TransactionPriority;
    final wallet = _wallet;

    if (isElectrumWallet) {
      final rate = bitcoin!.getFeeRate(wallet, _priority);
      return bitcoin!.bitcoinTransactionPriorityWithLabel(_priority, rate);
    }

    return priority.toString();
  }

  bool _isEqualCurrency(String currency) =>
      currency.toLowerCase() == _wallet.currency.title.toLowerCase();

  @action
  void onClose() =>
      _settingsStore.fiatCurrency = fiatFromSettings;

  @action
  void setFiatCurrency(FiatCurrency fiat) =>
      _settingsStore.fiatCurrency = fiat;

  void estimateFee() {
    _wallet.feeEstimate.update(priority: _settingsStore.priority[_wallet.type]!, outputsCount: outputs.length);
  }

  @computed
  double get estimatedFee {
    try {
      var totalFormattedCryptoAmount = 0;
      for (final output in outputs) {
        totalFormattedCryptoAmount += output.formattedCryptoAmount;
      }

      final fee = _wallet.feeEstimate.get(
        priority: _settingsStore.priority[_wallet.type]!,
        amount: totalFormattedCryptoAmount,
        outputsCount: outputs.length,
      );

      return formatAmountToDouble(type: _wallet.type, amount: fee);
    } catch (e) {
      print(e.toString());
    }

    return 0;
  }

  @computed
  String get estimatedFeeFiatAmount {
    try {
      final fiat = calculateFiatAmountRaw(
          price: _fiatConversationStore.prices[_wallet.currency],
          cryptoAmount: this.estimatedFee);
      return fiat;
    } catch (_) {
      return '0.00';
    }
  }
}
