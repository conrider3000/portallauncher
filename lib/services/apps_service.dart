import 'package:flutter/services.dart';
import '../utils/platform_helper.dart';

class AppInfo {
  final String label;
  final String packageName;
  final String className;

  AppInfo({
    required this.label,
    required this.packageName,
    required this.className,
  });

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      label: map['label'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      className: map['className'] as String? ?? '',
    );
  }
}

class AppsService {
  static const _channel = MethodChannel('com.portal/apps');
  static final Map<String, Uint8List?> _iconCache = {};

  /// Retrieves a sorted list of all installed launcher apps.
  static Future<List<AppInfo>> getInstalledApps() async {
    if (!isAndroidNative) {
      // Mock data for testing on Windows/Desktop platforms
      final mockApps = [
        {'label': 'WhatsApp', 'packageName': 'com.whatsapp', 'className': ''},
        {'label': 'Instagram', 'packageName': 'com.instagram.android', 'className': ''},
        {'label': 'Spotify', 'packageName': 'com.spotify.music', 'className': ''},
        {'label': 'Gmail', 'packageName': 'com.google.android.gm', 'className': ''},
        {'label': 'Google Agenda', 'packageName': 'com.google.android.calendar', 'className': ''},
        {'label': 'Google Maps', 'packageName': 'com.google.android.apps.maps', 'className': ''},
        {'label': 'Uber', 'packageName': 'com.ubercab', 'className': ''},
        {'label': 'Chrome', 'packageName': 'com.android.chrome', 'className': ''},
        {'label': 'Configurações', 'packageName': 'com.android.settings', 'className': ''},
        {'label': 'Câmera', 'packageName': 'com.android.camera', 'className': ''},
        {'label': 'YouTube', 'packageName': 'com.google.android.youtube', 'className': ''},
        {'label': 'Slack', 'packageName': 'com.slack', 'className': ''},
        {'label': 'Trello', 'packageName': 'com.trello', 'className': ''},
        {'label': 'Zoom', 'packageName': 'com.zoom', 'className': ''},
      ];
      mockApps.sort((a, b) => (a['label'] as String).toLowerCase().compareTo((b['label'] as String).toLowerCase()));
      return mockApps.map((item) => AppInfo.fromMap(item)).toList();
    }

    try {
      final List<dynamic>? result = await _channel.invokeMethod('getInstalledApps');
      if (result == null) return [];
      return result.map((item) => AppInfo.fromMap(item as Map)).toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Fetches application icon bytes on demand, caching it in memory.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    if (!isAndroidNative) return null;

    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getAppIcon', {
        'packageName': packageName,
      });
      _iconCache[packageName] = bytes;
      return bytes;
    } on PlatformException catch (_) {
      _iconCache[packageName] = null;
      return null;
    }
  }

  /// Launches specified app using packageName and className.
  static Future<bool> launchApp(String packageName, String className) async {
    if (!isAndroidNative) {
      print("Simulando lançamento do app: $packageName");
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod('launchApp', {
        'packageName': packageName,
        'className': className,
      });
      return success ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
