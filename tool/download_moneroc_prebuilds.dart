import 'dart:io';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';

final _dio = Dio();

final List<String> triplets = [
  "x86_64-linux-gnu", // linux desktop - majority of users onlinux 
  // "i686-linux-gnu", // not supported by cake
  // "i686-meego-linux-gnu", // sailfishos (emulator)- not supported by cake
  // "aarch64-linux-gnu", // not (yet) supported by cake - (mostly) mobile linux
  // "aarch64-meego-linux-gnu", // sailfishos - not supported by cake
  "x86_64-linux-android",
  // "i686-linux-android", // not supported by monero_c - mostly old android emulators
  "aarch64-linux-android",
  "armv7a-linux-androideabi",
  // "i686-w64-mingw32", // 32bit windows - not supported by monero_c
  "x86_64-w64-mingw32",
  // "x86_64-apple-darwin11", // Intel macbooks (contrib) - not used by cake 
  // "aarch64-apple-darwin11", // apple silicon macbooks (contrib) - not used by cake
  // "host-apple-darwin", // not available on CI (yet)
  // "x86_64-host-apple-darwin", // not available on CI (yet)
  "aarch64-host-apple-darwin", // apple silicon macbooks (local builds)
  "aarch64-apple-ios",
];

Future<void> main() async {
  final resp = await _dio.get("https://api.github.com/repos/mrcyjanek/monero_c/releases");
  final data = resp.data[0];
  final tagName = data['tag_name'];
  printV("Downloading artifacts for: ${tagName}");
  final assets = data['assets'] as List<dynamic>;
  for (var i = 0; i < assets.length; i++) {
    for (var triplet in triplets) {
      final asset = assets[i];
      final filename = asset["name"] as String;
      if (!filename.contains(triplet)) continue;
      final coin = filename.split("_")[0];
      String localFilename = filename.replaceAll("${coin}_${triplet}_", "");
      localFilename = "scripts/monero_c/release/${coin}/${triplet}_${localFilename}";
      final url = asset["browser_download_url"] as String;
      printV("- downloading $localFilename");
      await _dio.download(url, localFilename);
      printV("  extracting $localFilename");
      final inputStream = InputFileStream(localFilename);
      final archive = XZDecoder().decodeBuffer(inputStream);
      final outputStream = OutputFileStream(localFilename.replaceAll(".xz", ""));
      outputStream.writeBytes(archive);
    }
  }
  if (Platform.isMacOS) {
    printV("Generating ios framework");
    final result = Process.runSync("bash", [
      "-c",
      "cd scripts/ios && ./gen_framework.sh && cd ../.."
    ]);
    printV((result.stdout+result.stderr).toString().trim());
  }
}