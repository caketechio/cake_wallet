import 'package:cake_wallet/tron/tron.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/entities/transaction_description.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/src/screens/transaction_details/blockexplorer_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/rbf_details_list_fee_picker_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/textfield_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/transaction_details_list_item.dart';
import 'package:cake_wallet/src/screens/transaction_details/transaction_expandable_list_item.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/date_formatter.dart';
import 'package:cake_wallet/view_model/send/send_view_model.dart';
import 'package:collection/collection.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:hive/hive.dart';
import 'package:intl/src/intl/date_format.dart';
import 'package:mobx/mobx.dart';
import 'package:url_launcher/url_launcher.dart';

part 'transaction_details_view_model.g.dart';

class TransactionDetailsViewModel = TransactionDetailsViewModelBase
    with _$TransactionDetailsViewModel;

abstract class TransactionDetailsViewModelBase with Store {
  TransactionDetailsViewModelBase(
      {required this.transactionInfo,
      required this.transactionDescriptionBox,
      required this.wallet,
      required this.settingsStore,
      required this.sendViewModel})
      : items = [],
        RBFListItems = [],
        newFee = 0,
        isRecipientAddressShown = false,
        showRecipientAddress = settingsStore.shouldSaveRecipientAddress {
    final dateFormat = DateFormatter.withCurrentLocal();
    final tx = transactionInfo;

    switch (wallet.type) {
      case WalletType.monero:
        _addMoneroListItems(tx, dateFormat);
        break;
      case WalletType.bitcoin:
        _addElectrumListItems(tx, dateFormat);
        _addBumpFeesListItems(tx);
        _checkForRBF(tx);
        break;
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        _addElectrumListItems(tx, dateFormat);
        break;
      case WalletType.lightning:
        _addLightningListItems(tx, dateFormat);
        break;
      case WalletType.haven:
        _addHavenListItems(tx, dateFormat);
        break;
      case WalletType.ethereum:
        _addEthereumListItems(tx, dateFormat);
        break;
      case WalletType.nano:
        _addNanoListItems(tx, dateFormat);
        break;
      case WalletType.polygon:
        _addPolygonListItems(tx, dateFormat);
        break;
      case WalletType.solana:
        _addSolanaListItems(tx, dateFormat);
        break;
      case WalletType.tron:
        _addTronListItems(tx, dateFormat);
        break;
      case WalletType.wownero:
        _addWowneroListItems(tx, dateFormat);
        break;
      default:
        break;
    }

    if (showRecipientAddress && !isRecipientAddressShown) {
      try {
        final recipientAddress = transactionDescriptionBox.values
            .firstWhere((val) => val.id == transactionInfo.txHash)
            .recipientAddress;

        if (recipientAddress?.isNotEmpty ?? false) {
          items.add(StandartListItem(
              title: S.current.transaction_details_recipient_address, value: recipientAddress!));
        }
      } catch (_) {
        // FIX-ME: Unhandled exception
      }
    }

    final type = wallet.type;

    if (_explorerDescription(type) != '') {
      items.add(BlockExplorerListItem(
          title: S.current.view_in_block_explorer,
          value: _explorerDescription(type),
          onTap: () async {
            try {
              final uri = Uri.parse(_explorerUrl(type, tx.txHash));
              if (await canLaunchUrl(uri))
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e) {}
          }));
    }

    final description = transactionDescriptionBox.values.firstWhere(
        (val) => val.id == transactionInfo.txHash,
        orElse: () => TransactionDescription(id: transactionInfo.txHash));

    items.add(TextFieldListItem(
        title: S.current.note_tap_to_change,
        value: description.note,
        onSubmitted: (value) {
          description.transactionNote = value;

          if (description.isInBox) {
            description.save();
          } else {
            transactionDescriptionBox.add(description);
          }
        }));
  }

  final TransactionInfo transactionInfo;
  final Box<TransactionDescription> transactionDescriptionBox;
  final SettingsStore settingsStore;
  final WalletBase wallet;
  final SendViewModel sendViewModel;

  final List<TransactionDetailsListItem> items;
  final List<TransactionDetailsListItem> RBFListItems;
  bool showRecipientAddress;
  bool isRecipientAddressShown;
  int newFee;
  TransactionPriority? transactionPriority;

  @observable
  bool _canReplaceByFee = false;

  @computed
  bool get canReplaceByFee => _canReplaceByFee /*&& transactionInfo.confirmations <= 0*/;

  String _explorerUrl(WalletType type, String txId) {
    switch (type) {
      case WalletType.monero:
        return 'https://monero.com/tx/${txId}';
      case WalletType.bitcoin:
        return 'https://mempool.space/${wallet.isTestnet ? "testnet/" : ""}tx/${txId}';
      case WalletType.litecoin:
        return 'https://blockchair.com/litecoin/transaction/${txId}';
      case WalletType.bitcoinCash:
        return 'https://blockchair.com/bitcoin-cash/transaction/${txId}';
      case WalletType.haven:
        return 'https://explorer.havenprotocol.org/search?value=${txId}';
      case WalletType.ethereum:
        return 'https://etherscan.io/tx/${txId}';
      case WalletType.nano:
        return 'https://nanolooker.com/block/${txId}';
      case WalletType.banano:
        return 'https://bananolooker.com/block/${txId}';
      case WalletType.polygon:
        return 'https://polygonscan.com/tx/${txId}';
      case WalletType.solana:
        return 'https://solscan.io/tx/${txId}';
      case WalletType.tron:
        return 'https://tronscan.org/#/transaction/${txId}';
      case WalletType.wownero:
        return 'https://explore.wownero.com/tx/${txId}';
      case WalletType.lightning:
      case WalletType.none:
        return '';
    }
  }

  String _explorerDescription(WalletType type) {
    switch (type) {
      case WalletType.monero:
        return S.current.view_transaction_on + 'Monero.com';
      case WalletType.bitcoin:
        return S.current.view_transaction_on + 'mempool.space';
      case WalletType.litecoin:
      case WalletType.bitcoinCash:
        return S.current.view_transaction_on + 'Blockchair.com';
      case WalletType.haven:
        return S.current.view_transaction_on + 'explorer.havenprotocol.org';
      case WalletType.ethereum:
        return S.current.view_transaction_on + 'etherscan.io';
      case WalletType.nano:
        return S.current.view_transaction_on + 'nanolooker.com';
      case WalletType.banano:
        return S.current.view_transaction_on + 'bananolooker.com';
      case WalletType.polygon:
        return S.current.view_transaction_on + 'polygonscan.com';
      case WalletType.solana:
        return S.current.view_transaction_on + 'solscan.io';
      case WalletType.tron:
        return S.current.view_transaction_on + 'tronscan.org';
      case WalletType.wownero:
        return S.current.view_transaction_on + 'Wownero.com';
      case WalletType.lightning:
      case WalletType.none:
        return '';
    }
  }

  void _addMoneroListItems(TransactionInfo tx, DateFormat dateFormat) {
    final key = tx.additionalInfo['key'] as String?;
    final accountIndex = tx.additionalInfo['accountIndex'] as int;
    final addressIndex = tx.additionalInfo['addressIndex'] as int;
    final feeFormatted = tx.feeFormatted();
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (feeFormatted != null)
        StandartListItem(title: S.current.transaction_details_fee, value: feeFormatted),
      if (key?.isNotEmpty ?? false) StandartListItem(title: S.current.transaction_key, value: key!),
    ];

    if (tx.direction == TransactionDirection.incoming) {
      try {
        final address = monero!.getTransactionAddress(wallet, accountIndex, addressIndex);
        final label = monero!.getSubaddressLabel(wallet, accountIndex, addressIndex);

        if (address.isNotEmpty) {
          isRecipientAddressShown = true;
          _items.add(StandartListItem(
            title: S.current.transaction_details_recipient_address,
            value: address,
          ));
        }

        if (label.isNotEmpty) {
          _items.add(StandartListItem(title: S.current.address_label, value: label));
        }
      } catch (e) {
        print(e.toString());
      }
    }

    items.addAll(_items);
  }

  void _addElectrumListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.confirmations, value: tx.confirmations.toString()),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
    ];

    items.addAll(_items);
  }

  void _addLightningListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.id),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
    ];

    items.addAll(_items);
  }

  void _addHavenListItems(TransactionInfo tx, DateFormat dateFormat) {
    items.addAll([
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
    ]);
  }

  void _addEthereumListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.confirmations, value: tx.confirmations.toString()),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
      if (showRecipientAddress && tx.to != null)
        StandartListItem(title: S.current.transaction_details_recipient_address, value: tx.to!),
      if (tx.direction == TransactionDirection.incoming && tx.from != null)
        StandartListItem(title: S.current.transaction_details_source_address, value: tx.from!),
    ];

    items.addAll(_items);
  }

  void _addNanoListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      if (showRecipientAddress && tx.to != null)
        StandartListItem(title: S.current.transaction_details_recipient_address, value: tx.to!),
      if (showRecipientAddress && tx.from != null)
        StandartListItem(title: S.current.transaction_details_source_address, value: tx.from!),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.confirmed_tx, value: (tx.confirmations > 0).toString()),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
    ];

    items.addAll(_items);
  }

  void _addPolygonListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.confirmations, value: tx.confirmations.toString()),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
      if (showRecipientAddress && tx.to != null && tx.direction == TransactionDirection.outgoing)
        StandartListItem(title: S.current.transaction_details_recipient_address, value: tx.to!),
      if (tx.direction == TransactionDirection.incoming && tx.from != null)
        StandartListItem(title: S.current.transaction_details_source_address, value: tx.from!),
    ];

    items.addAll(_items);
  }

  void _addSolanaListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
      if (showRecipientAddress && tx.to != null)
        StandartListItem(title: S.current.transaction_details_recipient_address, value: tx.to!),
      if (tx.from != null)
        StandartListItem(title: S.current.transaction_details_source_address, value: tx.from!),
    ];

    items.addAll(_items);
  }

  void _addBumpFeesListItems(TransactionInfo tx) {
    transactionPriority = bitcoin!.getBitcoinTransactionPriorityMedium();
    final inputsCount = (transactionInfo.inputAddresses?.isEmpty ?? true)
        ? 1
        : transactionInfo.inputAddresses!.length;
    final outputsCount = (transactionInfo.outputAddresses?.isEmpty ?? true)
        ? 1
        : transactionInfo.outputAddresses!.length;

    newFee = bitcoin!.getFeeAmountForPriority(
        wallet, bitcoin!.getBitcoinTransactionPriorityMedium(), inputsCount, outputsCount);

    RBFListItems.add(StandartListItem(title: S.current.old_fee, value: tx.feeFormatted() ?? '0.0'));

    final priorities = priorityForWalletType(wallet.type);
    final selectedItem = priorities.indexOf(sendViewModel.transactionPriority);
    final customItem = priorities
        .firstWhereOrNull((element) => element == sendViewModel.bitcoinTransactionPriorityCustom);
    final customItemIndex = customItem != null ? priorities.indexOf(customItem) : null;
    final maxCustomFeeRate = sendViewModel.maxCustomFeeRate?.toDouble();

    RBFListItems.add(StandardPickerListItem(
        title: S.current.estimated_new_fee,
        value: bitcoin!.formatterBitcoinAmountToString(amount: newFee) +
            ' ${walletTypeToCryptoCurrency(wallet.type)}',
        items: priorityForWalletType(wallet.type),
        customValue: settingsStore.customBitcoinFeeRate.toDouble(),
        maxValue: maxCustomFeeRate,
        selectedIdx: selectedItem,
        customItemIndex: customItemIndex ?? 0,
        displayItem: (dynamic priority, double sliderValue) =>
            sendViewModel.displayFeeRate(priority, sliderValue.round()),
        onSliderChanged: (double newValue) =>
            setNewFee(value: newValue, priority: transactionPriority!),
        onItemSelected: (dynamic item, double sliderValue) {
          transactionPriority = item as TransactionPriority;
          return setNewFee(value: sliderValue, priority: transactionPriority!);
        }));

    if (transactionInfo.inputAddresses != null && transactionInfo.inputAddresses!.isNotEmpty) {
      RBFListItems.add(StandardExpandableListItem(
          title: S.current.inputs, expandableItems: transactionInfo.inputAddresses!));
    }

    if (transactionInfo.outputAddresses != null && transactionInfo.outputAddresses!.isNotEmpty) {
      final outputAddresses = transactionInfo.outputAddresses!.map((element) {
        if (element.contains('OP_RETURN:') && element.length > 40) {
            return element.substring(0, 40) + '...';
        }
        return element;
      }).toList();

      RBFListItems.add(
          StandardExpandableListItem(title: S.current.outputs, expandableItems: outputAddresses));
    }
  }

  void _addTronListItems(TransactionInfo tx, DateFormat dateFormat) {
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (tx.feeFormatted()?.isNotEmpty ?? false)
        StandartListItem(title: S.current.transaction_details_fee, value: tx.feeFormatted()!),
      if (showRecipientAddress && tx.to != null)
        StandartListItem(
            title: S.current.transaction_details_recipient_address,
            value: tron!.getTronBase58Address(tx.to!, wallet)),
      if (tx.from != null)
        StandartListItem(
            title: S.current.transaction_details_source_address,
            value: tron!.getTronBase58Address(tx.from!, wallet)),
    ];

    items.addAll(_items);
  }

  @action
  Future<void> _checkForRBF(TransactionInfo tx) async {
    if (wallet.type == WalletType.bitcoin &&
        transactionInfo.direction == TransactionDirection.outgoing) {
      if (await bitcoin!.canReplaceByFee(wallet, tx)) {
        _canReplaceByFee = true;
      }
    }
  }

  String setNewFee({double? value, required TransactionPriority priority}) {
    newFee = priority == bitcoin!.getBitcoinTransactionPriorityCustom() && value != null
        ? bitcoin!.feeAmountWithFeeRate(
            wallet,
            value.round(),
            transactionInfo.inputAddresses?.length ?? 1,
            transactionInfo.outputAddresses?.length ?? 1)
        : bitcoin!.getFeeAmountForPriority(
            wallet,
            priority,
            transactionInfo.inputAddresses?.length ?? 1,
            transactionInfo.outputAddresses?.length ?? 1);

    return bitcoin!.formatterBitcoinAmountToString(amount: newFee);
  }

  void replaceByFee(String newFee) => sendViewModel.replaceByFee(transactionInfo, newFee,);

  @computed
  String get pendingTransactionFiatAmountValueFormatted => sendViewModel.isFiatDisabled
      ? ''
      : sendViewModel.pendingTransactionFiatAmount + ' ' + sendViewModel.fiat.title;

  @computed
  String get pendingTransactionFeeFiatAmountFormatted => sendViewModel.isFiatDisabled
      ? ''
      : sendViewModel.pendingTransactionFeeFiatAmount + ' ' + sendViewModel.fiat.title;

  void _addWowneroListItems(TransactionInfo tx, DateFormat dateFormat) {
    final key = tx.additionalInfo['key'] as String?;
    final accountIndex = tx.additionalInfo['accountIndex'] as int;
    final addressIndex = tx.additionalInfo['addressIndex'] as int;
    final feeFormatted = tx.feeFormatted();
    final _items = [
      StandartListItem(title: S.current.transaction_details_transaction_id, value: tx.txHash),
      StandartListItem(
          title: S.current.transaction_details_date, value: dateFormat.format(tx.date)),
      StandartListItem(title: S.current.transaction_details_height, value: '${tx.height}'),
      StandartListItem(title: S.current.transaction_details_amount, value: tx.amountFormatted()),
      if (feeFormatted != null)
        StandartListItem(title: S.current.transaction_details_fee, value: feeFormatted),
      if (key?.isNotEmpty ?? false) StandartListItem(title: S.current.transaction_key, value: key!),
    ];

    if (tx.direction == TransactionDirection.incoming) {
      try {
        final address = wownero!.getTransactionAddress(wallet, accountIndex, addressIndex);
        final label = wownero!.getSubaddressLabel(wallet, accountIndex, addressIndex);

        if (address.isNotEmpty) {
          isRecipientAddressShown = true;
          _items.add(StandartListItem(
            title: S.current.transaction_details_recipient_address,
            value: address,
          ));
        }

        if (label.isNotEmpty) {
          _items.add(StandartListItem(title: S.current.address_label, value: label));
        }
      } catch (e) {
        print(e.toString());
      }
    }

    items.addAll(_items);
  }
}
