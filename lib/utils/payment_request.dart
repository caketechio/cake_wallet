import 'package:cake_wallet/nano/nano.dart';

class PaymentRequest {
  PaymentRequest(this.address, this.amount, this.note, this.scheme, this.pjUri,
      {this.callbackUrl, this.callbackMessage});

  factory PaymentRequest.fromUri(Uri? uri) {
    var address = "";
    var amount = "";
    var note = "";
    var scheme = "";
    String? walletType;
    String? callbackUrl;
    String? callbackMessage;
    String? pjUri;

    if (uri != null) {
      if (uri.queryParameters['pj'] != null) {
        pjUri = uri.toString();
      }

      address = uri.queryParameters['address'] ?? uri.path;
      amount = uri.queryParameters['tx_amount'] ?? uri.queryParameters['amount'] ?? "";
      note = uri.queryParameters['tx_description'] ?? uri.queryParameters['message'] ?? "";
      scheme = uri.scheme;
      callbackUrl = uri.queryParameters['callback'];
      callbackMessage = uri.queryParameters['callbackMessage'];
      walletType = uri.queryParameters['type'];
    }

    if (scheme == "nano-gpt") {
      scheme = walletType ?? "nano";
    }

    if (nano != null) {
      if (amount.isNotEmpty) {
        if (address.contains("nano")) {
          amount = nanoUtil!.getRawAsUsableString(amount, nanoUtil!.rawPerNano);
        } else if (address.contains("ban")) {
          amount = nanoUtil!.getRawAsUsableString(amount, nanoUtil!.rawPerBanano);
        }
      }
    }

    return PaymentRequest(
      address,
      amount,
      note,
      scheme,
      pjUri,
      callbackUrl: callbackUrl,
      callbackMessage: callbackMessage,
    );
  }

  final String address;
  final String amount;
  final String note;
  final String scheme;
  final String? pjUri;
  final String? callbackUrl;
  final String? callbackMessage;
}
