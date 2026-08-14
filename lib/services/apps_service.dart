import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static List<AppInfo>? _installedAppsCache;

  /// Retrieves a sorted list of all installed launcher apps.
  static Future<List<AppInfo>> getInstalledApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _installedAppsCache != null && _installedAppsCache!.isNotEmpty) {
      return _installedAppsCache!;
    }
    if (!isAndroidNative) {
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
      _installedAppsCache = mockApps.map((item) => AppInfo.fromMap(item)).toList();
      return _installedAppsCache!;
    }

    try {
      final List<dynamic>? result = await _channel.invokeMethod('getInstalledApps');
      if (result == null) return [];
      _installedAppsCache = result.map((item) => AppInfo.fromMap(item as Map)).toList();
      return _installedAppsCache!;
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

  static Future<void> _incrementLaunchCount(String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countsJson = prefs.getString('apps_launch_counts') ?? '{}';
      final Map<String, dynamic> counts = Map<String, dynamic>.from(jsonDecode(countsJson));
      counts[packageName] = (counts[packageName] as int? ?? 0) + 1;
      await prefs.setString('apps_launch_counts', jsonEncode(counts));
    } catch (_) {}
  }

  static Future<void> _addToRecentApps(String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentsJson = prefs.getString('apps_recent_history') ?? '[]';
      final List<dynamic> recents = List<dynamic>.from(jsonDecode(recentsJson));
      recents.remove(packageName);
      recents.insert(0, packageName);
      if (recents.length > 10) {
        recents.removeLast();
      }
      await prefs.setString('apps_recent_history', jsonEncode(recents));
    } catch (_) {}
  }

  /// Launches specified app using packageName and className.
  static Future<bool> launchApp(String packageName, String className) async {
    _incrementLaunchCount(packageName);
    _addToRecentApps(packageName);
    if (!isAndroidNative) {
      debugPrint("Simulando lançamento do app: $packageName");
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

  /// Returns a list of the most used apps sorted by launch counts and intelligent system popularity fallback.
  static Future<List<AppInfo>> getMostUsedApps(List<AppInfo> allApps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countsJson = prefs.getString('apps_launch_counts') ?? '{}';
      final Map<String, dynamic> counts = Map<String, dynamic>.from(jsonDecode(countsJson));
      
      const priorityPatterns = [
        'com.whatsapp',
        'com.instagram.android',
        'com.google.android.youtube',
        'com.android.chrome',
        'com.google.android.dialer',
        'com.samsung.android.dialer',
        'com.sec.android.app.camera',
        'com.sec.android.gallery3d',
        'com.google.android.apps.photos',
        'com.spotify.music',
        'com.sec.android.app.popupcalculator',
        'com.google.android.calculator',
        'com.google.android.apps.maps',
        'com.google.android.gm',
        'com.android.settings',
        'com.facebook.katana',
        'com.twitter.android',
        'org.telegram.messenger',
      ];

      final sorted = List<AppInfo>.from(allApps);
      sorted.sort((a, b) {
        final countA = counts[a.packageName] as int? ?? 0;
        final countB = counts[b.packageName] as int? ?? 0;
        
        if (countA != countB) {
          return countB.compareTo(countA);
        }

        final indexA = priorityPatterns.indexWhere((p) => a.packageName.contains(p));
        final indexB = priorityPatterns.indexWhere((p) => b.packageName.contains(p));
        
        final scoreA = indexA >= 0 ? (100 - indexA) : 0;
        final scoreB = indexB >= 0 ? (100 - indexB) : 0;

        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }

        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
      
      return sorted.take(10).toList();
    } catch (_) {
      return allApps.take(10).toList();
    }
  }

  /// Returns a chronological list of recent apps.
  static Future<List<AppInfo>> getRecentApps(List<AppInfo> allApps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentsJson = prefs.getString('apps_recent_history') ?? '[]';
      final List<dynamic> recents = List<dynamic>.from(jsonDecode(recentsJson));
      
      final List<AppInfo> result = [];
      for (final package in recents) {
        final app = allApps.firstWhere(
          (a) => a.packageName == package,
          orElse: () => AppInfo(label: '', packageName: '', className: ''),
        );
        if (app.packageName.isNotEmpty) {
          result.add(app);
        }
      }
      
      if (result.isEmpty) {
        return getMostUsedApps(allApps);
      }
      return result;
    } catch (_) {
      return getMostUsedApps(allApps);
    }
  }

  /// Triggers the Android system app uninstallation dialog.
  static Future<void> uninstallApp(String packageName) async {
    if (!isAndroidNative) return;
    try {
      await _channel.invokeMethod('uninstallApp', {'packageName': packageName});
    } catch (_) {}
  }

  /// Opens the app's Google Play Store page.
  static Future<void> updateApp(String packageName) async {
    if (!isAndroidNative) return;
    try {
      await _channel.invokeMethod('updateApp', {'packageName': packageName});
    } catch (_) {}
  }

  /// Opens the Android settings details page for the app.
  static Future<void> showAppDetails(String packageName) async {
    if (!isAndroidNative) return;
    try {
      await _channel.invokeMethod('showAppDetails', {'packageName': packageName});
    } catch (_) {}
  }
}
