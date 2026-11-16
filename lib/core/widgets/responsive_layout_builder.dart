import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';

/// Builder signature for responsive widget construction based on [BoxConstraints].
typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
);

/// A widget that conditionally builds different UI layouts based on
/// the available width constraints (mobile, tablet, desktop).
class ResponsiveLayoutBuilder extends StatelessWidget {
  /// Builder invoked when viewport width < [AppBreakpoints.tabletMin] (or when tablet/desktop are omitted).
  final ResponsiveWidgetBuilder mobile;

  /// Optional builder invoked when viewport width >= [AppBreakpoints.tabletMin] and < [AppBreakpoints.desktopMin].
  final ResponsiveWidgetBuilder? tablet;

  /// Optional builder invoked when viewport width >= [AppBreakpoints.desktopMin].
  final ResponsiveWidgetBuilder? desktop;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.desktopMin) {
          if (desktop != null) {
            return desktop!(context, constraints);
          }
          if (tablet != null) {
            return tablet!(context, constraints);
          }
          return mobile(context, constraints);
        }

        if (constraints.maxWidth >= AppBreakpoints.tabletMin) {
          if (tablet != null) {
            return tablet!(context, constraints);
          }
          return mobile(context, constraints);
        }

        return mobile(context, constraints);
      },
    );
  }
}
