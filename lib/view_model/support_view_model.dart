import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/view_model/settings/link_list_item.dart';
import 'package:cake_wallet/view_model/settings/settings_list_item.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

part 'support_view_model.g.dart';

class SupportViewModel = SupportViewModelBase with _$SupportViewModel;

abstract class SupportViewModelBase with Store {
  SupportViewModelBase()
      : items = [
          LinkListItem(
              title: 'Email',
              icon: 'assets/images/support_icon.png',
              linkTitle: 'support@cakewallet.com',
              link: 'mailto:support@cakewallet.com'),
          LinkListItem(
              title: 'Website',
              icon: 'assets/images/global.png',
              linkTitle: 'cakewallet.com',
              link: 'https://cakewallet.com'),
          LinkListItem(
              title: 'Forum',
              icon: 'assets/images/discourse.png',
              linkTitle: 'forum.cakewallet.com',
              link: 'https://forum.cakewallet.com'),
          LinkListItem(
              title: 'GitHub',
              icon: 'assets/images/github.png',
              hasIconColor: true,
              linkTitle: S.current.apk_update,
              link: 'https://github.com/cake-tech/cake_wallet/releases'),
          LinkListItem(
              title: 'Discord',
              icon: 'assets/images/discord.png',
              linkTitle: 'discord.gg/pwmWa6aFpX',
              link: 'https://discord.gg/pwmWa6aFpX'),
          LinkListItem(
              title: 'Telegram',
              icon: 'assets/images/Telegram.png',
              linkTitle: 't.me/cakewallet',
              link: 'https://t.me/cakewalletannouncements'),
          LinkListItem(
              title: 'Telegram Support Bot',
              icon: 'assets/images/Telegram.png',
              linkTitle: '@cakewallet_bot',
              link: 'https://t.me/cakewallet_bot'),
          LinkListItem(
              title: 'ChangeNow',
              icon: 'assets/images/change_now.png',
              linkTitle: 'support@changenow.io',
              link: 'mailto:support@changenow.io'),
          LinkListItem(
              title: 'SideShift',
              icon: 'assets/images/sideshift.png',
              linkTitle: 'help.sideshift.ai',
              link: 'https://help.sideshift.ai/en/'),
          LinkListItem(
              title: 'SimpleSwap',
              icon: 'assets/images/simpleSwap.png',
              linkTitle: 'support@simpleswap.io',
              link: 'mailto:support@simpleswap.io'),
          LinkListItem(
              title: 'Exolix',
              icon: 'assets/images/exolix.png',
              linkTitle: 'support@exolix.com',
              link: 'mailto:support@exolix.com'),
          LinkListItem(
              title: 'SwapTrade',
              icon: 'assets/images/swapTrade.png',
              linkTitle: 'help.swaptrade.io',
              link: 'mailto:support@exolix.com'),
          LinkListItem(
              title: 'Trocador',
              icon: 'assets/images/trocador.png',
              linkTitle: 'mail@trocador.app',
              link: 'mailto:mail@trocador.app'),
          LinkListItem(
              title: 'Onramper',
              icon: 'assets/images/onramper_dark.png',
              lightIcon: 'assets/images/onramper_light.png',
              linkTitle: 'View exchanges',
              link: 'https://docs.cakewallet.com/support/buy/#onramper'),
          LinkListItem(
              title: 'DFX',
              icon: 'assets/images/dfx_dark.png',
              lightIcon: 'assets/images/dfx_light.png',
              linkTitle: 'support@dfx.swiss',
              link: 'mailto:support@dfx.swiss'),
          if (!isMoneroOnly) ...[
            LinkListItem(
                title: 'MoonPay',
                icon: 'assets/images/moonpay.png',
                linkTitle: S.current.submit_request,
                link: 'https://support.moonpay.com/hc/en-gb/requests/new'),
            LinkListItem(
                title: 'Robinhood Connect',
                icon: 'assets/images/robinhood_dark.png',
                lightIcon: 'assets/images/robinhood_light.png',
                linkTitle: S.current.submit_request,
                link: 'https://robinhood.com/contact')
          ]
        ];

  final docsUrl = 'https://docs.cakewallet.com';

  String fetchUrl({String locale = "en", String authToken = ""}) {
    var supportUrl =
        "https://app.chatwoot.com/widget?website_token=${secrets.chatwootWebsiteToken}&locale=${locale}";

    if (authToken.isNotEmpty) supportUrl += "&cw_conversation=$authToken";

    return supportUrl;
  }

  List<SettingsListItem> items;
}
