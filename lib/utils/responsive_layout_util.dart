import 'package:flutter/material.dart';

class ResponsiveLayoutUtil {
  static const double _kMobileThreshold = 768;
  static const double kDesktopMaxWidthConstraint = 400;
  static const double kPopupWidth = 400;
  static const double kPopupSpaceHeight = 100;
  static const _kIpadMaxWidth = 1024;

  const ResponsiveLayoutUtil._();

  static final instance = ResponsiveLayoutUtil._();

  bool isMobile(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    return mediaQueryData.size.width < _kMobileThreshold;
  }

  bool isIpad(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    return mediaQueryData.size.width >= _kMobileThreshold &&
        !(mediaQueryData.size.width > _kIpadMaxWidth);
  }

  /// Returns dynamic size.
  ///
  /// If screen size is mobile, it returns 66% ([scale]) of the [originalValue].
  double getDynamicSize(
    BuildContext context,
    double originalValue, {
    double? mobileSize,
    double? scale,
  }) {
    scale ??= 2 / 3;
    mobileSize ??= originalValue * scale;
    final value = isMobile(context) ? mobileSize : originalValue;

    return value.roundToDouble();
  }
}
