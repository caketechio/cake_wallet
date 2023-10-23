import 'package:cake_wallet/core/auth_service.dart';
import 'package:cake_wallet/entities/contact_base.dart';
import 'package:cake_wallet/entities/contact_record.dart';
import 'package:cake_wallet/themes/extensions/cake_text_theme.dart';
import 'package:cake_wallet/themes/extensions/exchange_page_theme.dart';
import 'package:cake_wallet/utils/icon_from_path.dart';
import 'package:cake_wallet/utils/show_bar.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/view_model/contact_list/contact_list_view_model.dart';
import 'package:cake_wallet/src/widgets/collapsible_standart_list.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ContactListPage extends BasePage {
  ContactListPage(this.contactListViewModel, this.authService);

  final ContactListViewModel contactListViewModel;
  final AuthService authService;

  @override
  String get title => S.current.address_book;

  @override
  Widget? trailing(BuildContext context) {
    return MergeSemantics(
      child: Container(
        width: 32.0,
        height: 32.0,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).extension<ExchangePageTheme>()!.buttonBackgroundColor),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              Icons.add,
              color: Theme.of(context).appBarTheme.titleTextStyle!.color,
              size: 22.0,
            ),
            ButtonTheme(
              minWidth: 32.0,
              height: 32.0,
              child: TextButton(
                  // FIX-ME: Style
                  //shape: CircleBorder(),
                  onPressed: () async {
                    if (contactListViewModel.shouldRequireTOTP2FAForAddingContacts) {
                      authService.authenticateAction(
                        context,
                        route: Routes.addressBookAddContact,
                        conditionToDetermineIfToUse2FA:
                            contactListViewModel.shouldRequireTOTP2FAForAddingContacts,
                      );
                    } else {
                      await Navigator.of(context).pushNamed(Routes.addressBookAddContact);
                    }
                  },
                  child: Offstage()),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget body(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(20.0),
        child: Observer(builder: (_) {
          final contacts = contactListViewModel.contactsToShow;
          final walletContacts = contactListViewModel.walletContactsToShow;
          return CollapsibleSectionList(
            sectionCount: 2,
            sectionTitleBuilder: (int sectionIndex) {
              var title = S.current.contact_list_contacts;

              if (sectionIndex == 0) {
                title = S.current.contact_list_wallets;
              }

              return Container(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(title, style: TextStyle(fontSize: 36)));
            },
            itemCounter: (int sectionIndex) =>
                sectionIndex == 0 ? walletContacts.length : contacts.length,
            itemBuilder: (int sectionIndex, index) {
              if (sectionIndex == 0) {
                final walletInfo = walletContacts[index];
                return generateRaw(context, walletInfo);
              }

              final contact = contacts[index];
              final content = generateRaw(context, contact);
              return contactListViewModel.isEditable
                  ? Slidable(
                      key: Key('${contact.key}'),
                      endActionPane: _actionPane(context, contact),
                      child: content,
                    )
                  : content;
            },
          );
        }));
  }

  Widget generateRaw(BuildContext context, ContactBase contact) {
    final currencyIcon = buildIconFromPath(contact.type.iconPath);

    return GestureDetector(
      onTap: () async {
        if (!contactListViewModel.isEditable) {
          Navigator.of(context).pop(contact);
          return;
        }

        final isCopied = await showNameAndAddressDialog(context, contact.name, contact.address);

        if (isCopied) {
          await Clipboard.setData(ClipboardData(text: contact.address));
          await showBar<void>(context, S.of(context).copied_to_clipboard);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(top: 16, bottom: 16, right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            currencyIcon,
            Expanded(
                child: Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                contact.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).extension<CakeTextTheme>()!.titleColor,
                ),
              ),
            ))
          ],
        ),
      ),
    );
  }

  Future<bool> showAlertDialog(BuildContext context) async {
    return await showPopUp<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithTwoActions(
                  alertTitle: S.of(context).address_remove_contact,
                  alertContent: S.of(context).address_remove_content,
                  rightButtonText: S.of(context).remove,
                  leftButtonText: S.of(context).cancel,
                  actionRightButton: () => Navigator.of(context).pop(true),
                  actionLeftButton: () => Navigator.of(context).pop(false));
            }) ??
        false;
  }

  Future<bool> showNameAndAddressDialog(BuildContext context, String name, String address) async {
    return await showPopUp<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertWithTwoActions(
                  alertTitle: name,
                  alertContent: address,
                  rightButtonText: S.of(context).copy,
                  leftButtonText: S.of(context).cancel,
                  actionRightButton: () => Navigator.of(context).pop(true),
                  actionLeftButton: () => Navigator.of(context).pop(false));
            }) ??
        false;
  }

  ActionPane _actionPane(BuildContext context, ContactRecord contact) => ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) async => await Navigator.of(context)
                .pushNamed(Routes.addressBookAddContact, arguments: contact),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: S.of(context).edit,
          ),
          SlidableAction(
            onPressed: (_) async {
              final isDelete = await showAlertDialog(context);

              if (isDelete) {
                await contactListViewModel.delete(contact);
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: S.of(context).delete,
          ),
        ],
      );
}
