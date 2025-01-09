import 'package:flutter/foundation.dart';

class FeatureFlag {
  static const bool isCakePayEnabled = false;
  static const bool isExolixEnabled = true;
  static const bool isInAppTorEnabled = true;
  static const bool isBackgroundSyncEnabled = false;
  static const int verificationWordsCount = kDebugMode ? 0 : 2;
}