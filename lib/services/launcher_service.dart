import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LauncherService {
  static const _channel = MethodChannel('com.portal/launcher_setup');

  /// Checks if the current app is set as the default home app.
  static Future<bool> isDefaultHome() async {
    try {
      final bool result = await _channel.invokeMethod('isDefaultHome');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Triggers the Android OS prompt/settings page to set this app as the default home app.
  static Future<void> requestDefaultHome() async {
    try {
      await _channel.invokeMethod('requestDefaultHome');
    } on PlatformException catch (e) {
      debugPrint("Error requesting default home: ${e.message}");
    }
  }
}
