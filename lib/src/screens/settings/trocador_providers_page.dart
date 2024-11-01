import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/screens/settings/widgets/settings_switcher_cell.dart';
import 'package:cake_wallet/view_model/settings/trocador_providers_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class TrocadorProvidersPage extends BasePage {
  TrocadorProvidersPage(this.trocadorProvidersViewModel);

  @override
  String get title => 'Trocador Providers';

  final TrocadorProvidersViewModel trocadorProvidersViewModel;

  @override
  Widget body(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10),
      child: Observer(
        builder: (_) {
          if (trocadorProvidersViewModel.isLoading) {
            return Center(child: CircularProgressIndicator());
          }
          var providerStates = trocadorProvidersViewModel.providerStates;
          final providerRatings = trocadorProvidersViewModel.providerRatings;
          if (providerStates.isEmpty) {
            return Center(child: Text(S.of(context).no_providers_available));
          }
          return ListView.builder(
            itemCount: providerStates.length,
            itemBuilder: (_, index) {
              final providerName = providerStates.keys.elementAt(index);
              final providerEnabled = providerStates[providerName] ?? true;
              return SettingsSwitcherCell(
                title: providerName,
                value: providerEnabled,
                leading: Badge(
                  title: 'KYC \nRATING',
                  subTitle: providerRatings[providerName] ?? 'N/A',
                  textColor: Colors.white,
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                onValueChange: (BuildContext _, value) =>
                    trocadorProvidersViewModel.toggleProviderState(providerName),
              );
            },
          );
        },
      ),
    );
  }
}

class Badge extends StatelessWidget {
  Badge({required this.textColor, required this.backgroundColor, required this.title, required this.subTitle});

  final String title;
  final String subTitle;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FittedBox(
        fit: BoxFit.fitHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(24)), color: backgroundColor),
          alignment: Alignment.center,
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                VerticalDivider(
                  color: textColor,
                  thickness: 1,
                ),
                Text(
                  subTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
