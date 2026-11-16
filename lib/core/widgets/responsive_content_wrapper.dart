import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';

/// A wrapper widget that constrains content to a maximum width, centers it,
/// and applies adaptive horizontal padding based on the screen width.
class ResponsiveContentWrapper extends StatelessWidget {
  /// The content to wrap and constrain.
  final Widget child;

  /// Maximum allowed width for the inner content. Defaults to [AppBreakpoints.maxContentWidth].
  final double maxWidth;

  /// Explicit padding to apply. If null, adaptive padding is used based on screen width.
  final EdgeInsetsGeometry? padding;

  /// Alignment of the constrained child within available space. Defaults to [Alignment.topCenter].
  final AlignmentGeometry alignment;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final effectivePadding = padding ?? _defaultPaddingForWidth(width);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }

  static EdgeInsetsGeometry _defaultPaddingForWidth(double width) {
    if (width >= AppBreakpoints.desktopMin) {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 0.0);
    }
    if (width >= AppBreakpoints.tabletMin) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0);
    }
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0);
  }
}
