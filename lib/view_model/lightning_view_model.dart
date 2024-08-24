import 'dart:async';
import 'package:breez_sdk/breez_sdk.dart';
import 'package:breez_sdk/bridge_generated.dart' as BZG;
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:mobx/mobx.dart';

part 'lightning_view_model.g.dart';

class LightningViewModel = LightningViewModelBase with _$LightningViewModel;

abstract class LightningViewModelBase with Store {
  LightningViewModelBase() {
    _sdk = BreezSDK();
  }

  late final BreezSDK _sdk;

  Future<ReceiveOnchainResult> receiveOnchain() async {
    BZG.ReceiveOnchainRequest req = const BZG.ReceiveOnchainRequest();
    BZG.SwapInfo swapInfo = await _sdk.receiveOnchain(req: req);
    print("Minimum amount allowed to deposit in sats: ${swapInfo.minAllowedDeposit}");
    print("Maximum amount allowed to deposit in sats: ${swapInfo.maxAllowedDeposit}");

    int fee = 0;
    double feePercent = 0;

    try {
      final nodeState = (await _sdk.nodeInfo())!;
      int inboundLiquidity = nodeState.inboundLiquidityMsats ~/ 1000;
      final openingFees = await _sdk.openChannelFee(
          req: BZG.OpenChannelFeeRequest(amountMsat: inboundLiquidity + 1));
      feePercent = (openingFees.feeParams.proportional * 100) / 1000000;
      fee = openingFees.feeParams.minMsat ~/ 1000;
    } catch (_) {}

    return ReceiveOnchainResult(
      bitcoinAddress: swapInfo.bitcoinAddress,
      minAllowedDeposit: swapInfo.minAllowedDeposit,
      maxAllowedDeposit: swapInfo.maxAllowedDeposit,
      feePercent: feePercent,
      fee: fee,
    );
  }

  Future<String> createInvoice({required String amountSats, String? description}) async {
    final req = BZG.ReceivePaymentRequest(
      amountMsat: (double.parse(amountSats) * 1000).round(),
      description: description ?? '',
    );
    final res = await _sdk.receivePayment(req: req);

    return res.lnInvoice.bolt11;
  }

  Future<InvoiceSoftLimitsResult> invoiceSoftLimitsSats() async {
    double feePercent = 0.4;
    int minFee = (2500 * 1000) ~/ 1000; // 2500 sats
    int inboundLiquidity = 1000000000 * 1000 * 10; // 10 BTC
    int balance = 0;

    try {
      final nodeState = (await _sdk.nodeInfo())!;
      inboundLiquidity = nodeState.inboundLiquidityMsats ~/ 1000;

      final openingFees = await _sdk.openChannelFee(
          req: BZG.OpenChannelFeeRequest(amountMsat: inboundLiquidity + 1));

      feePercent = (openingFees.feeParams.proportional * 100) / 1000000;
      minFee = openingFees.feeParams.minMsat ~/ 1000;
      balance = nodeState.channelsBalanceMsat ~/ 1000;
    } catch (_) {
      minFee = 0;
    }

    return InvoiceSoftLimitsResult(
      minFee: minFee,
      inboundLiquidity: inboundLiquidity,
      feePercent: feePercent,
      balance: balance,
    );
  }

  Future<int> getBalanceSats() async {
    try {
      final nodeState = (await _sdk.nodeInfo())!;
      return nodeState.channelsBalanceMsat ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  Future<BZG.HealthCheckStatus> serviceHealthCheck() async {
    try {
      BZG.ServiceHealthCheckResponse response =
          await _sdk.serviceHealthCheck(apiKey: lightning!.getBreezApiKey());
      return response.status;
    } catch (_) {
      return BZG.HealthCheckStatus.ServiceDisruption;
    }
  }
}

class ReceiveOnchainResult {
  final String bitcoinAddress;
  final int minAllowedDeposit;
  final int maxAllowedDeposit;
  final int fee;
  final double feePercent;

  ReceiveOnchainResult({
    required this.bitcoinAddress,
    required this.minAllowedDeposit,
    required this.maxAllowedDeposit,
    required this.fee,
    required this.feePercent,
  });
}

class InvoiceSoftLimitsResult {
  final double feePercent;
  final int minFee;
  final int inboundLiquidity;
  final int balance;

  InvoiceSoftLimitsResult({
    required this.inboundLiquidity,
    required this.feePercent,
    required this.minFee,
    required this.balance,
  });
}
