import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/launcher_service.dart';
import '../services/apps_service.dart';

class NotificationsInboxView extends StatefulWidget {
  const NotificationsInboxView({super.key});

  @override
  State<NotificationsInboxView> createState() => _NotificationsInboxViewState();
}

class _NotificationsInboxViewState extends State<NotificationsInboxView> with WidgetsBindingObserver {
  bool _permissionEnabled = false;
  List<Map<String, String>> _notifications = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Map<String, String> _packageNameToLabel = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndLoad();
    _loadAppNameCache();
    // Poll every 3 seconds for new notifications
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_permissionEnabled) {
        _loadNotifications();
      } else {
        _checkPermissionOnly();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndLoad();
    }
  }

  Future<void> _loadAppNameCache() async {
    try {
      final apps = await AppsService.getInstalledApps();
      final cache = <String, String>{};
      for (var app in apps) {
        cache[app.packageName] = app.label;
      }
      if (mounted) {
        setState(() {
          _packageNameToLabel = cache;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkPermissionOnly() async {
    try {
      final enabled = await LauncherService.isNotificationServiceEnabled();
      if (enabled != _permissionEnabled && mounted) {
        setState(() {
          _permissionEnabled = enabled;
        });
        if (enabled) {
          _loadNotifications();
        }
      }
    } catch (_) {}
  }

  Future<void> _checkPermissionAndLoad() async {
    try {
      final enabled = await LauncherService.isNotificationServiceEnabled();
      if (mounted) {
        setState(() {
          _permissionEnabled = enabled;
          _isLoading = !enabled ? false : _isLoading;
        });
      }
      if (enabled) {
        await _loadNotifications();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final list = await LauncherService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismiss(String key, int index) async {
    try {
      await LauncherService.dismissNotification(key);
      setState(() {
        _notifications.removeAt(index);
      });
    } catch (_) {}
  }

  Future<void> _clearAll() async {
    try {
      for (var notif in _notifications) {
        final key = notif['key'];
        if (key != null) {
          await LauncherService.dismissNotification(key);
        }
      }
      setState(() {
        _notifications.clear();
      });
    } catch (_) {}
  }

  String _getAppName(String packageName) {
    if (_packageNameToLabel.containsKey(packageName)) {
      return _packageNameToLabel[packageName]!;
    }
    // simple formatting fallback (com.android.settings -> Settings)
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final last = parts.last;
      return last[0].toUpperCase() + last.substring(1);
    }
    return packageName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (!_permissionEnabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Acesso a Notificações Desativado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Para que a aba de Correio exiba as notificações do seu aparelho diretamente no Portal, ative a permissão do sistema.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => LauncherService.requestNotificationPermission(),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.settings_suggest_rounded),
              label: const Text('Ativar nas Configurações', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Action Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mensagens Recebidas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
              if (_notifications.isNotEmpty)
                GestureDetector(
                  onTap: _clearAll,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Limpar Tudo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Notifications List
        Expanded(
          child: _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 40,
                        color: theme.colorScheme.onSurface.withOpacity(0.25),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhuma notificação no momento',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 14.0, right: 14.0, top: 4.0, bottom: 160.0),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final key = item['key'] ?? '';
                    final pack = item['packageName'] ?? '';
                    final title = item['title'] ?? '';
                    final text = item['text'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Dismissible(
                        key: Key(key),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.archive_outlined, color: Colors.white, size: 20),
                        ),
                        onDismissed: (direction) => _dismiss(key, index),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.06),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App Icon
                              FutureBuilder<Uint8List?>(
                                future: AppsService.getAppIcon(pack),
                                builder: (context, snap) {
                                  if (snap.hasData && snap.data != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(snap.data!, width: 26, height: 26, fit: BoxFit.cover),
                                    );
                                  }
                                  return Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.android_rounded, size: 16, color: theme.colorScheme.primary),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              
                              // Notification content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _getAppName(pack),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
