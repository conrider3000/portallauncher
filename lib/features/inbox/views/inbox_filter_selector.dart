import 'package:flutter/material.dart';

class InboxFilterSelector extends StatelessWidget {
  final int selectedFilter;
  final int humanMessagesCount;
  final int appAlertsCount;
  final ValueChanged<int> onFilterChanged;
  final bool isDark;
  final ThemeData theme;

  const InboxFilterSelector({
    super.key,
    required this.selectedFilter,
    required this.humanMessagesCount,
    required this.appAlertsCount,
    required this.onFilterChanged,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Messages Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onFilterChanged(0),
              child: Container(
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedFilter == 0
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '💬 MENSAGENS ($humanMessagesCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selectedFilter == 0
                        ? theme.colorScheme.onPrimary
                        : inactiveColor,
                  ),
                ),
              ),
            ),
          ),
          // Alerts Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onFilterChanged(1),
              child: Container(
                height: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selectedFilter == 1
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '🔔 AVISOS ($appAlertsCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selectedFilter == 1
                        ? theme.colorScheme.onPrimary
                        : inactiveColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
