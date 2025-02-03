import 'package:flutter/foundation.dart';
import 'dart:io';

class FeatureFlag {
  static const bool isCakePayEnabled = false;
  static const bool isExolixEnabled = true;
  static final bool isInAppTorEnabled = (Platform.isAndroid || Platform.isIOS);
  static const bool isBackgroundSyncEnabled = false;
  static const int verificationWordsCount = kDebugMode ? 0 : 2;
}