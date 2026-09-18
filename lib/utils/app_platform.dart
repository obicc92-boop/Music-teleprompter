import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What kind of device the app runs on. Uses [defaultTargetPlatform], so
/// tests can pretend to be a phone with `debugDefaultTargetPlatformOverride`.
class AppPlatform {
  AppPlatform._();

  /// Windows, macOS or Linux: a resizable window, a mouse and a keyboard.
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Android or iOS: touch first, full screen, no window to manage.
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Nothing to hover over: controls that desktop shows on hover stay visible.
  static bool get isTouch => isMobile;

  /// A phone-sized screen in either orientation; tablets are wider.
  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < 600;

  /// Narrow enough that the phone layouts are used (a phone upright, or a
  /// very narrow window).
  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;
}
