import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Predefined viewport breakpoints matching Claimly target devices and boundary viewports.
enum ResponsiveBreakpoint {
  narrowMobile(Size(320, 568), 'Narrow Mobile (320x568)'),
  mobile360(Size(360, 640), 'Mobile 360 (360x640)'),
  mobile(Size(390, 844), 'Mobile (390x844)'),
  tabletBoundary(Size(600, 960), 'Tablet Boundary (600x960)'),
  tablet(Size(768, 1024), 'Tablet (768x1024)'),
  desktopBoundary(Size(1024, 768), 'Desktop Boundary (1024x768)'),
  desktop(Size(1280, 800), 'Desktop (1280x800)');

  final Size size;
  final String label;
  const ResponsiveBreakpoint(this.size, this.label);

  static const Size narrowMobile320 = Size(320, 568);
  static const Size narrowMobile360 = Size(360, 640);
  static const Size tabletBoundary600x800 = Size(600, 800);
  static const Size tabletBoundary600x960 = Size(600, 960);
  static const Size desktopBoundary1024x768 = Size(1024, 768);
  static const Size desktopBoundary1024x800 = Size(1024, 800);
}

/// Helper extensions for setting up simulated viewports in widget tests.
extension ResponsiveTestHelper on WidgetTester {
  /// Sets simulated viewport to [size] and registers automatic teardown cleanup.
  Future<void> setViewport(Size size, {double devicePixelRatio = 1.0}) async {
    view.physicalSize = Size(size.width * devicePixelRatio, size.height * devicePixelRatio);
    view.devicePixelRatio = devicePixelRatio;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  }

  /// Sets simulated viewport to the dimensions defined by [breakpoint].
  Future<void> setBreakpoint(ResponsiveBreakpoint breakpoint, {double devicePixelRatio = 1.0}) async {
    await setViewport(breakpoint.size, devicePixelRatio: devicePixelRatio);
  }
}

/// Asserts that no RenderFlex overflow exception or layout error occurred.
void expectNoRenderFlexOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception is FlutterError) {
    debugPrint('RENDER_FLEX_EXCEPTION:\n${exception.toStringDeep()}');
  }
  expect(
    exception,
    isNull,
    reason: 'Detected unexpected RenderFlex overflow or layout error: $exception',
  );
}
