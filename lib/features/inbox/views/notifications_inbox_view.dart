import 'package:flutter/material.dart';
import '../controllers/inbox_controller.dart';
import 'inbox_filter_selector.dart';
import 'inbox_notification_list.dart';
import '../../../services/launcher_service.dart';

class NotificationsInboxView extends StatefulWidget {
  const NotificationsInboxView({super.key});

  @override
  State<NotificationsInboxView> createState() => _NotificationsInboxViewState();
}

class _NotificationsInboxViewState extends State<NotificationsInboxView> {
  late final InboxController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InboxController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        if (!_controller.permissionEnabled) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

        final humanMessages = _controller.notifications.where(_controller.isHumanMessage).toList();
        final appAlerts = _controller.notifications.where((n) => !_controller.isHumanMessage(n)).toList();
        final activeList = _controller.selectedFilter == 0 ? humanMessages : appAlerts;

        return Column(
          children: [
            // Action Sub-Header (Top)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _controller.selectedFilter == 0 ? 'Mensagens Pessoais & Sociais' : 'Notificações & Avisos de Apps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (activeList.isNotEmpty)
                    GestureDetector(
                      onTap: () => _controller.clearFilterList(activeList),
                      child: Row(
                        children: [
                          Icon(Icons.clear_all_rounded, size: 15, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Limpar Categoria',
                            style: TextStyle(
                              fontSize: 11,
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
              child: InboxNotificationList(
                activeList: activeList,
                selectedFilter: _controller.selectedFilter,
                onDismiss: _controller.dismiss,
                getAppName: _controller.getAppName,
                isDark: isDark,
                theme: theme,
              ),
            ),

            // DUAL FILTER SELECTOR TOGGLE (MOVED TO BOTTOM BASE NEAR THUMB)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 160.0),
              child: InboxFilterSelector(
                selectedFilter: _controller.selectedFilter,
                humanMessagesCount: humanMessages.length,
                appAlertsCount: appAlerts.length,
                onFilterChanged: _controller.setFilter,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ],
        );
      },
    );
  }
}
