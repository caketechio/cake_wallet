import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cw_core/receive_page_option.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'receive_option_view_model.g.dart';

class ReceiveOptionViewModel = ReceiveOptionViewModelBase with _$ReceiveOptionViewModel;

abstract class ReceiveOptionViewModelBase with Store {
  ReceiveOptionViewModelBase(this._wallet, this.initialPageOption)
      : selectedReceiveOption = initialPageOption ??
            (_wallet.type == WalletType.bitcoin
                ? bitcoin!.getSelectedAddressType(_wallet)
                : ReceivePageOption.mainnet),
        _options = [] {
    final walletType = _wallet.type;

    switch (walletType) {
      case WalletType.haven:
        _options = [ReceivePageOption.mainnet];
        break;
      case WalletType.lightning:
        _options = [...lightning!.getLightningReceivePageOptions()];
        break;
      case WalletType.bitcoin:
        _options = [
          ...bitcoin!.getBitcoinReceivePageOptions(),
          ...ReceivePageOptions.where((element) => element != ReceivePageOption.mainnet)
        ];
        break;
      default:
        _options = [
          ReceivePageOption.mainnet,
          ReceivePageOption.anonPayDonationLink,
          ReceivePageOption.anonPayInvoice
        ];
        break;
    }
  }

  final WalletBase _wallet;

  final ReceivePageOption? initialPageOption;

  List<ReceivePageOption> _options;

  @observable
  ReceivePageOption selectedReceiveOption;

  List<ReceivePageOption> get options => _options;

  @action
  void selectReceiveOption(ReceivePageOption option) {
    selectedReceiveOption = option;
  }
}
