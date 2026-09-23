import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/launcher_service.dart';

class InboxController extends ChangeNotifier {
  List<Map<String, String>> notifications = [];
  bool permissionEnabled = false;
  bool isLoading = true;
  Timer? _notificationTimer;
  int selectedFilter = 0; // 0 = Pessoais, 1 = Apps

  InboxController() {
    _init();
  }

  Future<void> _init() async {
    await _checkPermission();
    if (permissionEnabled) {
      _startNotificationPolling();
    }
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void setFilter(int index) {
    selectedFilter = index;
    notifyListeners();
  }

  Future<void> _checkPermission() async {
    permissionEnabled = await LauncherService.isNotificationServiceEnabled();
    notifyListeners();
  }

  void _startNotificationPolling() {
    _fetchNotifications();
    _notificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final hasPerm = await LauncherService.isNotificationServiceEnabled();
      if (hasPerm != permissionEnabled) {
        permissionEnabled = hasPerm;
        notifyListeners();
      }
      if (permissionEnabled) {
        _fetchNotifications();
      } else {
        notifications.clear();
        notifyListeners();
      }
    });
  }

  Future<void> _fetchNotifications() async {
    try {
      final active = await LauncherService.getNotifications();
      final currentKeys = notifications.map((n) => n['key'] ?? '').toSet();
      final newKeys = active.map((n) => n['key'] ?? '').toSet();

      bool changed = false;

      // Add new notifications
      for (final notif in active) {
        if (!currentKeys.contains(notif['key'])) {
          notifications.add(notif);
          changed = true;
        }
      }

      int initialLength = notifications.length;
      notifications.removeWhere((n) => !newKeys.contains(n['key']));
      if (notifications.length != initialLength) {
        changed = true;
      }

      // Update existing notifications
      for (int i = 0; i < notifications.length; i++) {
        final existing = notifications[i];
        final updated = active.firstWhere((n) => n['key'] == existing['key'], orElse: () => {});
        if (updated.isNotEmpty) {
          if (existing['title'] != updated['title'] || existing['text'] != updated['text']) {
            notifications[i] = updated;
            changed = true;
          }
        }
      }

      // Sort: newest first
      if (changed) {
        notifications.sort((a, b) {
          final aTime = int.tryParse(a['postTime'] ?? '0') ?? 0;
          final bTime = int.tryParse(b['postTime'] ?? '0') ?? 0;
          return bTime.compareTo(aTime);
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> dismiss(String key) async {
    try {
      notifications.removeWhere((n) => n['key'] == key);
      notifyListeners();
      await LauncherService.dismissNotification(key);
    } catch (e) {
      debugPrint('Error dismissing notification $key: $e');
    }
  }

  Future<void> clearFilterList(List<Map<String, String>> listToClear) async {
    for (var n in listToClear) {
      try {
        if (n['key'] != null) {
          await LauncherService.dismissNotification(n['key']!);
        }
      } catch (e) {
        debugPrint('Error dismissing notification: $e');
      }
    }
    final keysToRemove = listToClear.map((e) => e['key']).toSet();
    notifications.removeWhere((n) => keysToRemove.contains(n['key']));
    notifyListeners();
  }

  bool isHumanMessage(Map<String, String> notification) {
    final pkg = notification['packageName']?.toLowerCase() ?? '';
    final channel = notification['channelId']?.toLowerCase() ?? '';
    final title = notification['title']?.toLowerCase() ?? '';

    final commPackages = [
      'com.whatsapp',
      'com.whatsapp.w4b',
      'org.telegram.messenger',
      'com.instagram.android',
      'com.twitter.android',
      'com.facebook.orca',
      'com.google.android.apps.messaging',
      'com.samsung.android.messaging',
      'com.discord',
      'com.skype.raider',
      'com.viber.voip',
      'com.tencent.mm',
      'jp.naver.line.android',
      'com.snapchat.android',
      'com.zhiliaoapp.musically',
      'com.linkedin.android',
      'com.google.android.gm',
      'com.microsoft.office.outlook'
    ];

    if (commPackages.contains(pkg)) {
      if (pkg == 'com.instagram.android' && !channel.contains('direct')) return false;
      if (title.contains('checking for new messages') ||
          title.contains('whatsapp web') ||
          title.contains('backup') ||
          title.contains('syncing')) {
        return false;
      }
      return true;
    }
    return false;
  }

  String getAppName(String packageName) {
    final map = {
      'com.whatsapp': 'WhatsApp',
      'com.whatsapp.w4b': 'WA Business',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.twitter.android': 'X (Twitter)',
      'com.facebook.orca': 'Messenger',
      'com.google.android.apps.messaging': 'Mensagens',
      'com.samsung.android.messaging': 'Mensagens',
      'com.discord': 'Discord',
      'com.skype.raider': 'Skype',
      'com.google.android.gm': 'Gmail',
      'com.microsoft.office.outlook': 'Outlook',
      'com.google.android.youtube': 'YouTube',
      'com.spotify.music': 'Spotify',
      'com.android.vending': 'Play Store',
      'com.google.android.dialer': 'Telefone',
      'com.google.android.apps.photos': 'Fotos',
    };
    return map[packageName] ?? packageName.split('.').last.toUpperCase();
  }
}
