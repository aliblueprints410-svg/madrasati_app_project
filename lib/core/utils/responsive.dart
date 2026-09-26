import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;

  // Breakpoints
  static bool isSmallPhone(BuildContext context) => width(context) < 360;
  static bool isMediumPhone(BuildContext context) => width(context) >= 360 && width(context) < 420;
  static bool isLargePhone(BuildContext context) => width(context) >= 420 && width(context) < 600;
  static bool isTablet(BuildContext context) => width(context) >= 600;

  // Responsive Grid Count for subjects / cards
  static int getGridCrossAxisCount(BuildContext context) {
    final w = width(context);
    if (w < 340) return 2; // Very small phone
    if (w < 600) return 2; // Standard phone
    if (w < 900) return 3; // Tablet portrait / foldable
    return 4; // Tablet landscape / desktop
  }

  // Responsive Aspect Ratio for Subject Cards
  static double getSubjectCardAspectRatio(BuildContext context) {
    final w = width(context);
    if (w < 340) return 0.85; // Taller card for tiny screens to prevent text overflow
    if (w < 380) return 0.90;
    if (w < 440) return 0.98;
    return 1.05;
  }

  // Dynamic Horizontal Page Padding
  static double getHorizontalPadding(BuildContext context) {
    final w = width(context);
    if (w < 360) return 12.0;
    if (w < 600) return 18.0;
    return 32.0;
  }
}
