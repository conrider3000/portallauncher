import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/apps_service.dart';
import '../controllers/sidebar_controller.dart';
import '../../../core/theme/portal_design_system.dart';

class RightSidebarView extends StatefulWidget {
  final SidebarController controller;

  const RightSidebarView({super.key, required this.controller});

  @override
  State<RightSidebarView> createState() => _RightSidebarViewState();
}

class _RightSidebarViewState extends State<RightSidebarView> {
  int _rightSidebarTabIndex = 0; // 0: Mais Utilizados, 1: Recentes
  List<AppInfo> _allApps = [];
  List<AppInfo> _mostUsedApps = [];

  @override
  void initState() {
    super.initState();
    _loadAllApps();
  }

  Future<void> _loadAllApps() async {
    final apps = await AppsService.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
      });
      _loadMostUsedApps();
    }
  }

  Future<void> _loadMostUsedApps() async {
    if (_allApps.isEmpty) return;
    
    final List<AppInfo> appsList = _rightSidebarTabIndex == 0
        ? await AppsService.getMostUsedApps(_allApps)
        : await AppsService.getRecentApps(_allApps);
    
    if (mounted) {
      setState(() {
        _mostUsedApps = appsList;
      });
    }
  }

  Widget _buildMiniSideBarContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: GestureDetector(
              onDoubleTap: () {
                widget.controller.updateRightBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
              },
              onTap: () {
                widget.controller.updateRightBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
              },
              child: Icon(
                Icons.keyboard_arrow_left_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: _mostUsedApps.isEmpty
                ? Center(
                    child: Icon(
                      Icons.apps_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 24,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _mostUsedApps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final app = _mostUsedApps[index];
                      return Center(
                        child: Tooltip(
                          message: app.label,
                          child: InkWell(
                            onTap: () async {
                              widget.controller.forceCloseAll();
                              await AppsService.launchApp(app.packageName, app.className);
                              _loadMostUsedApps();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: FutureBuilder<List<int>?>(
                                future: AppsService.getAppIcon(app.packageName),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        Uint8List.fromList(snapshot.data!),
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return Icon(
                                    Icons.android_rounded,
                                    size: 28,
                                    color: theme.colorScheme.primary,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_rounded,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              size: 20,
            ),
            onPressed: () {
              AppsService.launchApp('com.android.settings', '');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullSideBarContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                if (widget.controller.sideBarWidth.value > PortalDesignSystem.miniBarWidth) {
                  widget.controller.updateRightBarWidth(PortalDesignSystem.miniBarWidth, PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
                }
              },
              onDoubleTap: () {
                if (widget.controller.sideBarWidth.value > PortalDesignSystem.miniBarWidth) {
                  widget.controller.updateRightBarWidth(PortalDesignSystem.miniBarWidth, PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
                }
              },
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
          // ── APPS LIST ────────────────────────────────────────────────
          Expanded(
            child: _mostUsedApps.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum aplicativo registrado',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    reverse: true,
                    padding: EdgeInsets.zero,
                    itemCount: _mostUsedApps.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = _mostUsedApps[index];
                      return InkWell(
                        onTap: () async {
                          widget.controller.forceCloseAll();
                          await AppsService.launchApp(app.packageName, app.className);
                          _loadMostUsedApps();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              FutureBuilder<List<int>?>(
                                future: AppsService.getAppIcon(app.packageName),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        Uint8List.fromList(snapshot.data!),
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.android_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  app.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),

          // ── SEGMENTED CONTROL TOGGLE AT BASE / BOTTOM ────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _rightSidebarTabIndex = 0);
                      _loadMostUsedApps();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _rightSidebarTabIndex == 0
                            ? theme.colorScheme.primary.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '🔥 MAIS USADOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _rightSidebarTabIndex == 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _rightSidebarTabIndex = 1);
                      _loadMostUsedApps();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _rightSidebarTabIndex == 1
                            ? theme.colorScheme.primary.withValues(alpha: 0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '🕒 RECENTES',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: _rightSidebarTabIndex == 1
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBarWidth = PortalDesignSystem.maxBarWidth(screenWidth);

    return ValueListenableBuilder<double>(
      valueListenable: widget.controller.sideBarWidth,
      builder: (context, currentWidth, child) {
        return Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: currentWidth > 0 ? screenWidth : 60.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              widget.controller.startRightDrag(currentWidth);
            },
            onHorizontalDragUpdate: (details) {
            if (currentWidth == 0.0) {
              _loadMostUsedApps();
            }
            widget.controller.updateRightBarWidth(currentWidth - details.delta.dx, maxBarWidth);
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
            widget.controller.handleRightDragEnd(velocity, maxBarWidth);
            if (widget.controller.sideBarWidth.value > 0.0) {
               _loadMostUsedApps();
            }
          },
          child: Stack(
            children: [
              if (currentWidth > 0)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => widget.controller.forceCloseAll(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.15 * (currentWidth / maxBarWidth)),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: currentWidth > 0 ? currentWidth : 0.0,
                child: GestureDetector(
                  onTap: () {}, // Consume taps
                  child: ClipRRect(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(PortalDesignSystem.overlayBorderRadius)),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: PortalDesignSystem.getOverlayBlurBackground(isDark),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(PortalDesignSystem.overlayBorderRadius)),
                          border: Border(
                            left: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: currentWidth < 120
                              ? _buildMiniSideBarContent(theme, isDark)
                              : _buildFullSideBarContent(theme, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }
}
