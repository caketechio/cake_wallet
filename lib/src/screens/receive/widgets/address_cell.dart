import 'package:auto_size_text/auto_size_text.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/utils/responsive_layout_util.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class AddressCell extends StatelessWidget {
  AddressCell({
    required this.address,
    required this.derivationPath,
    required this.name,
    required this.isCurrent,
    required this.isPrimary,
    required this.backgroundColor,
    required this.textColor,
    this.onTap,
    this.onEdit,
    this.onHide,
    this.isHidden = false,
    this.onDelete,
    this.txCount,
    this.balance,
    this.isChange = false,
    this.hasBalance = false,
    this.hasReceived = false,
  });

  factory AddressCell.fromItem(
    WalletAddressListItem item, {
    required bool isCurrent,
    required Color backgroundColor,
    required Color textColor,
    Function(String)? onTap,
    bool hasBalance = false,
    bool hasReceived = false,
    Function()? onEdit,
    Function()? onHide,
    bool isHidden = false,
    Function()? onDelete,
  }) =>
      AddressCell(
        address: item.address,
        derivationPath: item.derivationPath,
        name: item.name ?? '',
        isCurrent: isCurrent,
        isPrimary: item.isPrimary,
        backgroundColor: backgroundColor,
        textColor: textColor,
        onTap: onTap,
        onEdit: onEdit,
        onHide: onHide,
        isHidden: isHidden,
        onDelete: onDelete,
        txCount: item.txCount,
        balance: item.balance,
        isChange: item.isChange,
        hasBalance: hasBalance,
        hasReceived: hasReceived,
      );

  final String address;
  final String derivationPath;
  final String name;
  final bool isCurrent;
  final bool isPrimary;
  final Color backgroundColor;
  final Color textColor;
  final Function(String)? onTap;
  final Function()? onEdit;
  final Function()? onHide;
  final bool isHidden;
  final Function()? onDelete;
  final int? txCount;
  final String? balance;
  final bool isChange;
  final bool hasBalance;
  final bool hasReceived;

  static const int addressPreviewLength = 8;

  String get formattedAddress {
    final formatIfCashAddr = address.replaceAll('bitcoincash:', '');

    if (formatIfCashAddr.length <= (name.isNotEmpty ? 16 : 43)) {
      return formatIfCashAddr;
    } else {
      return formatIfCashAddr.substring(0, addressPreviewLength) +
          '...' +
          formatIfCashAddr.substring(
              formatIfCashAddr.length - addressPreviewLength, formatIfCashAddr.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget cell = InkWell(
        onTap: () => onTap?.call(address),
        child: Container(
          width: double.infinity,
          color: backgroundColor,
          padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: name.isNotEmpty
                          ? MainAxisAlignment.spaceBetween
                          : MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Row(
                          children: [
                            if (isChange)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Container(
                                  height: 20,
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(8.5)),
                                      color: textColor),
                                  alignment: Alignment.center,
                                  child: Text(
                                    S.of(context).unspent_change,
                                    style: TextStyle(
                                      color: backgroundColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (name.isNotEmpty)
                              Text(
                                '$name',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                          ],
                        ),
                        Flexible(
                          child: AutoSizeText(
                            responsiveLayoutUtil.shouldRenderTabletUI ? address : formattedAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isChange ? 10 : 14,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (derivationPath.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: AutoSizeText(
                                derivationPath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isChange ? 10 : 14,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hasBalance || hasReceived)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              '${hasReceived ? S.of(context).received : S.of(context).balance}: $balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '${S.of(context).transactions.toLowerCase()}: $txCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ));
    return onEdit == null
        ? cell
        : Semantics(
            label: S.of(context).slidable,
            selected: isCurrent,
            enabled: !isCurrent,
            child: Slidable(
              key: Key(address),
              startActionPane: _actionPaneStart(context),
              endActionPane: _actionPaneEnd(context),
              child: cell,
            ),
          );
  }

  ActionPane _actionPaneEnd(BuildContext context) => ActionPane(
        motion: const ScrollMotion(),
        extentRatio: onDelete != null ? 0.4 : 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => onHide?.call(),
            backgroundColor: isHidden ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
            icon: isHidden ? CupertinoIcons.arrow_left : CupertinoIcons.arrow_right,
            label: isHidden ? S.of(context).show : S.of(context).hide,
          ),
        ],
      );

  ActionPane _actionPaneStart(BuildContext context) => ActionPane(
        motion: const ScrollMotion(),
        extentRatio: onDelete != null ? 0.4 : 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit?.call(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: S.of(context).edit,
          ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!.call(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: S.of(context).delete,
            ),
        ],
      );
}
