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

  /// Fetches physical sensors, wifi, bluetooth, NFC and infrared details from device.
  static Future<Map<String, dynamic>> getDeviceHardwareInfo() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getDeviceHardwareInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Checks if BIND_NOTIFICATION_LISTENER_SERVICE permission is active.
  static Future<bool> isNotificationServiceEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isNotificationServiceEnabled');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Directs user to Android settings page to allow notification access.
  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  /// Retrieves list of current active notifications.
  static Future<List<Map<String, String>>> getNotifications() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getNotifications');
      if (result != null) {
        return result.map((item) => Map<String, String>.from(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Cancels/dismisses a single notification by key.
  static Future<void> dismissNotification(String key) async {
    try {
      await _channel.invokeMethod('dismissNotification', {'key': key});
    } catch (_) {}
  }

  /// Opens the system clock application.
  static Future<bool> openClockApp() async {
    try {
      final bool result = await _channel.invokeMethod('openClockApp');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Opens a web page URL in the browser.
  static Future<void> openUrl(String url) async {
    try {
      await _channel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  /// Toggles Wi-Fi status.
  static Future<void> toggleWifi(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleWifi', {'enabled': enabled});
    } catch (_) {}
  }

  /// Toggles Bluetooth status.
  static Future<void> toggleBluetooth(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleBluetooth', {'enabled': enabled});
    } catch (_) {}
  }

  /// Opens system mobile network settings panel.
  static Future<void> toggleCellular() async {
    try {
      await _channel.invokeMethod('toggleCellular');
    } catch (_) {}
  }

  /// Opens system NFC settings.
  static Future<void> openNfcSettings() async {
    try {
      await _channel.invokeMethod('openNfcSettings');
    } catch (_) {}
  }
}
