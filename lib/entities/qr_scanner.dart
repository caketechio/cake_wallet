import 'dart:math';

import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/src/widgets/alert_with_two_actions.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:fast_scanner/fast_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

var isQrScannerShown = false;

Future<String> presentQRScanner(BuildContext context) async {
  isQrScannerShown = true;
  try {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:(context) {
          return BarcodeScannerSimple();
        },
      ),
    );
    isQrScannerShown = false;
    return result!;
  } catch (e) {
    isQrScannerShown = false;
    rethrow;
  }
}

// https://github.com/MrCyjaneK/fast_scanner/blob/master/example/lib/barcode_scanner_simple.dart
class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({super.key});

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> {
  Barcode? _barcode;
  bool popped = false;

  List<String> urCodes = [];
  late var ur = URQRToURQRData(urCodes);

  void _handleBarcode(BarcodeCapture barcodes) {
    try {
      _handleBarcodeInternal(barcodes);
    } catch (e) {
      showPopUp<void>(
        context: context,
        builder: (context) {
          return AlertWithOneAction(
            alertTitle: S.of(context).error,
            alertContent: S.of(context).error_dialog_content,
            buttonText: 'ok',
            buttonAction: () {
              Navigator.of(context).pop();
            },
          );
        },
      );
      printV(e);
    }
  }

  void _handleBarcodeInternal(BarcodeCapture barcodes) {
    for (final barcode in barcodes.barcodes) {
      // don't handle unknown QR codes
      if (barcode.rawValue?.trim().isEmpty??false == false) continue;
      if (barcode.rawValue!.startsWith("ur:")) {
        if (urCodes.contains(barcode.rawValue)) continue;
        setState(() {
          urCodes.add(barcode.rawValue!);
          ur = URQRToURQRData(urCodes);
        });
        if (ur.progress == 1) {
          setState(() {
            popped = true;
          });
          SchedulerBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop(ur.inputs.join("\n"));
          });
        };
      }
    }
    if (urCodes.isNotEmpty) return;
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
      if (_barcode != null && popped != true) {
        setState(() {
          popped = true;
        });
        Navigator.of(context).pop(_barcode!.rawValue ?? _barcode!.rawBytes);
      }
    }
  }

  final MobileScannerController ctrl = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          SwitchCameraButton(controller: ctrl),
          ToggleFlashlightButton(controller: ctrl),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _handleBarcode,
            controller: ctrl,
          ),
          if (ur.inputs.length != 0) 
            Center(child:
              Text(
                "${ur.inputs.length}/${ur.count}",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white)
              ),
            ),
          SizedBox(
            child: Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: CustomPaint(
                  painter: ProgressPainter(
                    urQrProgress: URQrProgress(
                      expectedPartCount: ur.count - 1,
                      processedPartsCount: ur.inputs.length,
                      receivedPartIndexes: _urParts(),
                      percentage: ur.progress,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _urParts() {
    List<int> l = [];
    for (var inp in ur.inputs) {
      try {
        l.add(int.parse(inp.split("/")[1].split("-")[0]));
      } catch (e) {}
    }
    return l;
  }
}


class ToggleFlashlightButton extends StatelessWidget {
  const ToggleFlashlightButton({required this.controller, super.key});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, child) {
        if (!state.isInitialized || !state.isRunning) {
          return const SizedBox.shrink();
        }

        switch (state.torchState) {
          case TorchState.auto:
            return IconButton(
              iconSize: 32.0,
              icon: const Icon(Icons.flash_auto),
              onPressed: () async {
                await controller.toggleTorch();
              },
            );
          case TorchState.off:
            return IconButton(
              iconSize: 32.0,
              icon: const Icon(Icons.flash_off),
              onPressed: () async {
                await controller.toggleTorch();
              },
            );
          case TorchState.on:
            return IconButton(
              iconSize: 32.0,
              icon: const Icon(Icons.flash_on),
              onPressed: () async {
                await controller.toggleTorch();
              },
            );
          case TorchState.unavailable:
            return const Icon(
              Icons.no_flash,
              color: Colors.grey,
            );
        }
      },
    );
  }
}

class SwitchCameraButton extends StatelessWidget {
  const SwitchCameraButton({required this.controller, super.key});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, child) {
        if (!state.isInitialized || !state.isRunning) {
          return const SizedBox.shrink();
        }

        final int? availableCameras = state.availableCameras;

        if (availableCameras != null && availableCameras < 2) {
          return const SizedBox.shrink();
        }

        final Widget icon;

        switch (state.cameraDirection) {
          case CameraFacing.front:
            icon = const Icon(Icons.camera_front);
          case CameraFacing.back:
            icon = const Icon(Icons.camera_rear);
        }

        return IconButton(
          iconSize: 32.0,
          icon: icon,
          onPressed: () async {
            await controller.switchCamera();
          },
        );
      },
    );
  }
}

class URQRData {
  URQRData(
      {required this.tag,
      required this.str,
      required this.progress,
      required this.count,
      required this.error,
      required this.inputs});
  final String tag;
  final String str;
  final double progress;
  final int count;
  final String error;
  final List<String> inputs;
  Map<String, dynamic> toJson() {
    return {
      "tag": tag,
      "str": str,
      "progress": progress,
      "count": count,
      "error": error,
      "inputs": inputs,
    };
  }
}

URQRData URQRToURQRData(List<String> urqr_) {
  final urqr = urqr_.toSet().toList();
  urqr.sort((s1, s2) {
    final s1s = s1.split("/");
    final s1frameStr = s1s[1].split("-");
    final s1curFrame = int.parse(s1frameStr[0]);
    final s2s = s2.split("/");
    final s2frameStr = s2s[1].split("-");
    final s2curFrame = int.parse(s2frameStr[0]);
    return s1curFrame - s2curFrame;
  });

  String tag = '';
  int count = 0;
  String bw = '';
  for (var elm in urqr) {
    final s = elm.substring(elm.indexOf(":") + 1); // strip down ur: prefix
    final s2 = s.split("/");
    tag = s2[0];
    final frameStr = s2[1].split("-");
    // final curFrame = int.parse(frameStr[0]);
    count = int.parse(frameStr[1]);
    final byteWords = s2[2];
    bw += byteWords;
  }
  String? error;

  return URQRData(
    tag: tag,
    str: bw,
    progress: count == 0 ? 0 : (urqr.length / count),
    count: count,
    error: error ?? "",
    inputs: urqr,
  );
}

class ProgressPainter extends CustomPainter {
  final URQrProgress urQrProgress;

  ProgressPainter({required this.urQrProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2.0, size.height / 2.0);
    final radius = size.width * 0.9;
    final rect = Rect.fromCenter(center: c, width: radius, height: radius);
    const fullAngle = 360.0;
    var startAngle = 0.0;
    for (int i = 0; i < urQrProgress.expectedPartCount.toInt(); i++) {
      var sweepAngle =
          (1 / urQrProgress.expectedPartCount) * fullAngle * pi / 180.0;
      drawSector(canvas, urQrProgress.receivedPartIndexes.contains(i), rect,
          startAngle, sweepAngle);
      startAngle += sweepAngle;
    }
  }

  void drawSector(Canvas canvas, bool isActive, Rect rect, double startAngle,
      double sweepAngle) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = isActive ? const Color(0xffff6600) : Colors.white70;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant ProgressPainter oldDelegate) {
    return urQrProgress != oldDelegate.urQrProgress;
  }
}

class URQrProgress {
  int expectedPartCount;
  int processedPartsCount;
  List<int> receivedPartIndexes;
  double percentage;

  URQrProgress({
    required this.expectedPartCount,
    required this.processedPartsCount,
    required this.receivedPartIndexes,
    required this.percentage,
  });

  bool equals(URQrProgress? progress) {
    if (progress == null) {
      return false;
    }
    return processedPartsCount == progress.processedPartsCount;
  }
}
