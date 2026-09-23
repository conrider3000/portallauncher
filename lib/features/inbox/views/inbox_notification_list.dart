import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/apps_service.dart';
import '../../../services/launcher_service.dart';

class InboxNotificationList extends StatelessWidget {
  final List<Map<String, String>> activeList;
  final int selectedFilter;
  final Function(String) onDismiss;
  final String Function(String) getAppName;
  final bool isDark;
  final ThemeData theme;

  const InboxNotificationList({
    super.key,
    required this.activeList,
    required this.selectedFilter,
    required this.onDismiss,
    required this.getAppName,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (activeList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedFilter == 0 ? Icons.chat_bubble_outline_rounded : Icons.notifications_none_rounded,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              selectedFilter == 0
                  ? 'Nenhuma mensagem de pessoas no momento'
                  : 'Nenhum aviso de aplicativo no momento',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 14.0, right: 14.0, top: 4.0, bottom: 20.0),
      itemCount: activeList.length,
      itemBuilder: (context, index) {
        final item = activeList[index];
        final keyStr = item['key'] ?? '';
        final pack = item['packageName'] ?? '';
        final title = item['title'] ?? '';
        final text = item['text'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Dismissible(
            key: Key(keyStr),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.archive_outlined, color: Colors.white, size: 20),
            ),
            onDismissed: (direction) => onDismiss(keyStr),
            child: GestureDetector(
              onDoubleTap: () async {
                final clicked = await LauncherService.clickNotification(keyStr);
                if (!clicked && pack.isNotEmpty) {
                  await AppsService.launchApp(pack, '');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Icon
                    FutureBuilder<List<int>?>(
                      future: AppsService.getAppIcon(pack),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              Uint8List.fromList(snap.data!), 
                              width: 26, 
                              height: 26, 
                              fit: BoxFit.cover
                            ),
                          );
                        }
                        return Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                                getAppName(pack),
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
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
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
          ),
        );
      },
    );
  }
}
