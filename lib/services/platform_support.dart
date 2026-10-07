import 'dart:io';

/// Small helpers so the same code runs on phones (Android/iOS) and
/// computers (Windows/macOS/Linux).
class PlatformSupport {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Name shown for the device running the app.
  static String get localDeviceName =>
      isMobile ? 'This Mobile Device' : 'This Computer';
}
