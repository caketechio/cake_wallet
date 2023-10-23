import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

Widget buildIconFromPath(String? iconPath, {double height = 24.0, double width = 24.0}) {
  if (iconPath != null && iconPath.contains('svg')) {
    return SvgPicture.asset(
      iconPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
    );
  } else if (iconPath != null && iconPath.isNotEmpty) {
    return Image.asset(
      iconPath,
      height: height,
      width: width,
    );
  } else {
    return SizedBox(height: height, width: width);
  }
}
