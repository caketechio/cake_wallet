import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class WebViewPage extends BasePage {
  WebViewPage(this._title, this._url);

  final String _title;
  final Uri _url;

  @override
  String get title => _title;

  @override
  Widget body(BuildContext context) {
    return WebViewPageBody(_url);
  }
}

class WebViewPageBody extends StatefulWidget {
  WebViewPageBody(this.uri);

  final Uri uri;

  @override
  WebViewPageBodyState createState() => WebViewPageBodyState();
}

class WebViewPageBodyState extends State<WebViewPageBody> {
  WebViewPageBodyState();

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          transparentBackground: true,
          javaScriptEnabled: true,
          cacheEnabled: true,
          resourceCustomSchemes: ["cakewallet"],
          useShouldOverrideUrlLoading: true,
        ),
      ),
      initialUrlRequest: URLRequest(url: widget.uri),
      onLoadResource: (controller, resource) async {},
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        return NavigationActionPolicy.ALLOW;
      },
      onLoadResourceCustomScheme: (controller, uri) async {
        final url = await controller.getUrl();
        if (url.toString().startsWith("cakewallet://wc")) {
          if (getIt.get<AppStore>().wallet!.type != WalletType.ethereum) {
            Fluttertoast.showToast(
              msg: S.current.switchToETHWallet,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.SNACKBAR,
              backgroundColor: Colors.black,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return;
          }
          // required because fully loading the custom url scheme will result in an error page:
          await controller.stopLoading();
          // navigate to the wallet connect screen:
          Navigator.of(context).pushNamed(Routes.walletConnectConnectionsListing, arguments: url);
          return null;
        }
      },
      androidOnPermissionRequest: (_, __, resources) async {
        bool permissionGranted = await Permission.camera.status == PermissionStatus.granted;
        if (!permissionGranted) {
          permissionGranted = await Permission.camera.request().isGranted;
        }

        return PermissionRequestResponse(
          resources: resources,
          action: permissionGranted
              ? PermissionRequestResponseAction.GRANT
              : PermissionRequestResponseAction.DENY,
        );
      },
    );
  }
}
