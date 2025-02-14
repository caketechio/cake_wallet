import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/monero_accounts/monero_account_list_page.dart';
import 'package:cake_wallet/src/screens/nano_accounts/nano_account_list_page.dart';
import 'package:cake_wallet/src/screens/receive/widgets/address_cell.dart';
import 'package:cake_wallet/src/screens/receive/widgets/header_tile.dart';
import 'package:cake_wallet/src/widgets/section_divider.dart';
import 'package:cake_wallet/themes/extensions/receive_page_theme.dart';
import 'package:cake_wallet/utils/list_item.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_account_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_hidden_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_view_model.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class AddressList extends StatefulWidget {
  const AddressList({
    super.key,
    required this.addressListViewModel,
    this.onSelect,
  });

  final WalletAddressListViewModel addressListViewModel;
  final Function(String)? onSelect;

  @override
  State<AddressList> createState() => _AddressListState();
}

class _AddressListState extends State<AddressList> {
  bool showHiddenAddresses = false;

  void _toggleHiddenAddresses() {
    setState(() {
      showHiddenAddresses = !showHiddenAddresses;
    });
    updateItems();
  }

  List<ListItem> getItems(List<ListItem> list, bool showHidden) {
    return list.where((element) {
      if (element is WalletAddressListItem) {
        if (showHidden && element.isHidden) return true;
        if (!showHidden && !element.isHidden) return true;
        return false;
      }
      return true;
    }).toList();
  }

  List<ListItem> items = [];

  void updateItems() {
    setState(() {
      items = getItems(widget.addressListViewModel.items, showHiddenAddresses);
    });
  }

  @override
  void initState() {
    super.initState();

    items = getItems(widget.addressListViewModel.items, showHiddenAddresses);
  }

  @override
  Widget build(BuildContext context) {
    bool editable = widget.onSelect == null;
    return ListView.separated(
      padding: EdgeInsets.all(0),
      separatorBuilder: (context, _) => const HorizontalSectionDivider(),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        Widget cell = Container();

        if (item is WalletAccountListHeader) {
          cell = HeaderTile(
              showTrailingButton: true,
              walletAddressListViewModel: widget.addressListViewModel,
              trailingButtonTap: () async {
                if (widget.addressListViewModel.type == WalletType.monero ||
                    widget.addressListViewModel.type == WalletType.wownero ||
                    widget.addressListViewModel.type == WalletType.haven) {
                  await showPopUp<void>(
                      context: context, builder: (_) => getIt.get<MoneroAccountListPage>());
                  updateItems();
                } else {
                  await showPopUp<void>(
                      context: context, builder: (_) => getIt.get<NanoAccountListPage>());
                  updateItems();
                }
              },
              title: S.of(context).accounts,
              trailingIcon: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).extension<ReceivePageTheme>()!.iconsColor,
              ));
        }

        if (item is WalletAddressHiddenListHeader) {
          cell = HeaderTile(
              title: S.of(context).hidden_addresses,
              walletAddressListViewModel: widget.addressListViewModel,
              showTrailingButton: true,
              showSearchButton: false,
              trailingButtonTap: _toggleHiddenAddresses,
              trailingIcon: Icon(
                showHiddenAddresses ? Icons.toggle_on : Icons.toggle_off,
                size: 20,
                color: Theme.of(context).extension<ReceivePageTheme>()!.iconsColor,
              ));
        }

        if (item is WalletAddressListHeader) {
          cell = HeaderTile(
              title: S.of(context).addresses,
              walletAddressListViewModel: widget.addressListViewModel,
              showTrailingButton: widget.addressListViewModel.showAddManualAddresses,
              showSearchButton: true,
              onSearchCallback: updateItems,
              trailingButtonTap: () =>
                  Navigator.of(context).pushNamed(Routes.newSubaddress).then((value) {
                    updateItems(); // refresh the new address
                  }),
              trailingIcon: Icon(
                Icons.add,
                size: 20,
                color: Theme.of(context).extension<ReceivePageTheme>()!.iconsColor,
              ));
        }

        if (item is WalletAddressListItem) {
          if (item.isHidden && !showHiddenAddresses) {
            cell = Container();
          } else if (!item.isHidden && showHiddenAddresses) {
            cell = Container();
          } else {
            cell = Observer(builder: (_) {
              final isCurrent =
                  item.address == widget.addressListViewModel.address.address && editable;
              final backgroundColor = isCurrent
                  ? Theme.of(context).extension<ReceivePageTheme>()!.currentTileBackgroundColor
                  : Theme.of(context).extension<ReceivePageTheme>()!.tilesBackgroundColor;
              final textColor = isCurrent
                  ? Theme.of(context).extension<ReceivePageTheme>()!.currentTileTextColor
                  : Theme.of(context).extension<ReceivePageTheme>()!.tilesTextColor;

              return AddressCell.fromItem(
                item,
                isCurrent: isCurrent,
                hasBalance: widget.addressListViewModel.isBalanceAvailable,
                hasReceived: widget.addressListViewModel.isReceivedAvailable,
                // hasReceived:
                backgroundColor: (kDebugMode && item.isHidden)
                    ? Theme.of(context).colorScheme.error
                    : (kDebugMode && item.isManual)
                        ? Theme.of(context).colorScheme.error.withBlue(255)
                        : backgroundColor,
                textColor: textColor,
                onTap: (_) {
                  if (widget.onSelect != null) {
                    widget.onSelect!(item.address);
                    return;
                  }
                  widget.addressListViewModel.setAddress(item);
                },
                onEdit: editable
                    ? () => Navigator.of(context)
                            .pushNamed(Routes.newSubaddress, arguments: item)
                            .then((value) {
                          updateItems(); // refresh the new address
                        })
                    : null,
                isHidden: item.isHidden,
                onHide: () => _hideAddress(item),
              );
            });
          }
        }

        return index != 0
            ? cell
            : ClipRRect(
                borderRadius:
                    BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                child: cell,
              );
      },
    );
  }

  void _hideAddress(WalletAddressListItem item) async {
    await widget.addressListViewModel.toggleHideAddress(item);
    updateItems();
  }
}
