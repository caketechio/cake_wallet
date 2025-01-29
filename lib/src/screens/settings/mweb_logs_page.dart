import 'dart:io';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cake_wallet/utils/share_util.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/settings/mweb_settings_view_model.dart';
import 'package:cw_core/root_dir.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class MwebLogsPage extends BasePage {
  MwebLogsPage(this.mwebSettingsViewModelBase);

  final MwebSettingsViewModelBase mwebSettingsViewModelBase;

  @override
  String get title => S.current.litecoin_mweb_logs;

  @override
  Widget body(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<String>(
          future: mwebSettingsViewModelBase.getAbbreviatedLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('No logs found'));
            } else {
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    snapshot.data!,
                    style: TextStyle(fontFamily: 'Monospace'),
                  ),
                ),
              );
            }
          },
        ),
        Positioned(
          child: LoadingPrimaryButton(
            onPressed: () => onExportLogs(context),
            text: S.of(context).export_logs,
            color: Theme.of(context).primaryColor,
            textColor: Colors.white,
          ),
          bottom: 24,
          left: 24,
          right: 24,
        )
      ],
    );
  }

  void onExportLogs(BuildContext context) {
    if (Platform.isAndroid) {
      onExportAndroid(context);
    } else if (Platform.isIOS) {
      share(context);
    } else {
      _saveFile();
    }
  }

  void onExportAndroid(BuildContext context) {
    showPopUp<void>(
        context: context,
        builder: (dialogContext) {
          return AlertWithTwoActions(
              alertTitle: S.of(context).export_backup,
              alertContent: S.of(context).select_destination,
              rightButtonText: S.of(context).save,
              leftButtonText: S.of(context).cancel,
              actionLeftButton: () async {
                Navigator.of(dialogContext).pop();
              },
              actionRightButton: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await share(context);
                } catch (e, s) {
                  ExceptionHandler.onError(FlutterErrorDetails(
                    exception: e,
                    stack: s,
                    library: "Export Logs",
                  ));
                }
              });
        });
  }

  Future<void> share(BuildContext context) async {
    final inAppPath = "${(await getApplicationSupportDirectory()).path}/logs/debug.log";
    await ShareUtil.shareFile(filePath: inAppPath, fileName: "debug.log", context: context);
  }

  Future<void> _saveFile() async {
    String? outputFile = await FilePicker.platform
        .saveFile(dialogTitle: 'Save Your File to desired location', fileName: "debug.log");

    try {
      final filePath = (await getApplicationSupportDirectory()).path + "/debug.log";
      File debugLogFile = File(filePath);
      await debugLogFile.copy(outputFile!);
    } catch (exception, stackTrace) {
      ExceptionHandler.onError(FlutterErrorDetails(
        exception: exception,
        stack: stackTrace,
        library: "Export Logs",
      ));
    }
  }
}
