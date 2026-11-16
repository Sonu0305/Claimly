import 'package:flutter/material.dart';

/// Screen classification based on viewport width.
enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}

/// Unified breakpoint constants and viewport classification helpers for Claimly.
class AppBreakpoints {
  AppBreakpoints._();

  /// Maximum viewport width considered mobile (<600px).
  static const double mobileMax = 599.0;

  /// Minimum viewport width considered tablet (600px).
  static const double tabletMin = 600.0;

  /// Maximum viewport width considered tablet (1023px).
  static const double tabletMax = 1023.0;

  /// Minimum viewport width considered desktop (1024px).
  static const double desktopMin = 1024.0;

  /// Recommended maximum layout width for dashboards and general content.
  static const double maxContentWidth = 1200.0;

  /// Recommended maximum layout width for focused forms.
  static const double maxFormWidth = 720.0;

  /// Recommended maximum layout width for single cards.
  static const double maxCardWidth = 480.0;

  /// Determines [DeviceScreenType] given a specific viewport [width].
  static DeviceScreenType getDeviceType(double width) {
    if (width < tabletMin) return DeviceScreenType.mobile;
    if (width < desktopMin) return DeviceScreenType.tablet;
    return DeviceScreenType.desktop;
  }

  /// Returns true if the current context's viewport is mobile width (<600px).
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletMin;

  /// Returns true if the current context's viewport is tablet width (600px–1023px).
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMin && width < desktopMin;
  }

  /// Returns true if the current context's viewport is desktop width (>=1024px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;
}
