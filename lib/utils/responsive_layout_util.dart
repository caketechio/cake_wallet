import 'package:flutter/material.dart';

class ResponsiveLayoutUtil {
  static const double _kMobileThreshold = 550;
  static const double kDesktopMaxWidthConstraint = 400;
  static const double kPopupWidth = 400;
  static const double kPopupSpaceHeight = 100;
  static const _kIpadMaxWidth = 2560.0;

  const ResponsiveLayoutUtil._();

  static final instance = ResponsiveLayoutUtil._();

  bool get isMobile => MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.shortestSide <= _kMobileThreshold;

  bool shouldRenderMobileUI(BuildContext context) {
     final orientation = MediaQuery.of(context).orientation;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    if (isMobile || orientation == Orientation.portrait && width < height) {
      return true;
    } else if (orientation == Orientation.landscape && width < height) {
      return true;
    } else {
      return false;
    }
  }

  bool get isIpad {
    final width = MediaQueryData.fromWindow(WidgetsBinding.instance.window).size.width;
    return width >= _kMobileThreshold && !(width > _kIpadMaxWidth);
  }

  /// Returns dynamic size.
  ///
  /// If screen size is mobile, it returns 66% ([scale]) of the [originalValue].
  double getDynamicSize(
    double originalValue, {
    double? mobileSize,
    double? scale,
  }) {
    scale ??= 2 / 3;
    mobileSize ??= originalValue * scale;
    final value = isMobile ? mobileSize : originalValue;

    return value.roundToDouble();
  }
}
