// ignore_for_file: unused_field, unused_local_variable, prefer_final_fields, unused_import, unused_element
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/launcher_service.dart';
import '../services/apps_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/context_header.dart';
import '../widgets/virtual_topography.dart';
import '../widgets/apps_list_view.dart';
import '../widgets/memory_explorer_view.dart';
import '../features/inbox/views/notifications_inbox_view.dart';
import '../features/sidebars/controllers/sidebar_controller.dart';
import '../features/sidebars/views/left_sidebar_view.dart';
import '../features/sidebars/views/right_sidebar_view.dart';
import '../features/wikipedia/controllers/wikipedia_controller.dart';
import '../features/wikipedia/views/wikipedia_search_overlay.dart';


class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final SidebarController _sidebarController = SidebarController();
  final WikipediaController _wikipediaController = WikipediaController();
  late AnimationController _filterBarController;
  bool _isFilterBarExpanded = false;
  bool _showHomeTitle = true;
  final PageController _pageController = PageController();
  int _searchTapCount = 0;
  Timer? _searchTapTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentPageIndex = 0;
  bool _isDefault = true;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _overlaySearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _overlayFocusNode = FocusNode();
  // ignore: unused_field
  bool _searchOverlayOpen = false;
  bool _autoRotationEnabled = false;
  int _rightSidebarTabIndex = 0; // 0: Mais Utilizados & Telemetria, 1: Histórico Recente

  // For unified app search inside the overlay
  List<AppInfo> _allApps = [];
  List<AppInfo> _overlayFilteredApps = [];
  // ignore: unused_field
  final Map<String, Uint8List?> _overlayIconCache = {};

  List<AppInfo> _mostUsedApps = [];

  // Wikipedia Interactive Overlay Flow
  Map<String, String>? _selectedWikiArticle;
  Map<String, dynamic> _hardwareInfo = {};
  bool _isOfflineMode = false;

  Future<void> _loadMostUsedApps() async {
    if (_allApps.isEmpty) {
      final apps = await AppsService.getInstalledApps();
      _allApps = apps;
    }
    final List<AppInfo> appsList = _rightSidebarTabIndex == 0
        ? await AppsService.getMostUsedApps(_allApps)
        : await AppsService.getRecentApps(_allApps);
    if (mounted) {
      setState(() {
        _mostUsedApps = appsList;
      });
    }
  }

  Future<void> _loadHardwareInfo() async {
    try {
      final info = await LauncherService.getDeviceHardwareInfo();
      if (mounted) {
        final wifi = info['wifi'] as Map? ?? {};
        final bt = info['bluetooth'] as Map? ?? {};
        final bool wifiOn = wifi['enabled'] == true;
        final bool btOn = bt['enabled'] == true;
        setState(() {
          _hardwareInfo = info;
          if (wifiOn || btOn) {
            _isOfflineMode = false;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialStates() async {
    final rot = await LauncherService.isAutoRotationEnabled();
    if (mounted) {
      setState(() {
        _autoRotationEnabled = rot;
      });
    }
  }




  void _onPanelOpenChanged() {
    if (mounted) {
      final mode = ContextHeader.isPanelOpenNotifier.value;
      setState(() {
        if (mode == HeaderMode.timeSpace) {
          _showHomeTitle = false;
          if (_isFilterBarExpanded) {
            _isFilterBarExpanded = false;
            _filterBarController.reverse();
          }
        } else {
          // Delay showing the title so it waits for the weather panel to animate out
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && ContextHeader.isPanelOpenNotifier.value != HeaderMode.timeSpace) {
              setState(() {
                _showHomeTitle = true;
              });
            }
          });
        }
      });
    }
  }

  void _toggleFilterBar() {
    setState(() {
      _isFilterBarExpanded = !_isFilterBarExpanded;
      if (_isFilterBarExpanded) {
        _filterBarController.forward();
        if (ContextHeader.isPanelOpenNotifier.value == HeaderMode.timeSpace) {
          ContextHeader.isPanelOpenNotifier.value = HeaderMode.filter;
        }
      } else {
        _filterBarController.reverse();
      }
    });
  }

  void _handleSatelliteDoubleTap() {
    VirtualTopography.refreshSatelliteTrigger.value =
        !VirtualTopography.refreshSatelliteTrigger.value;
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Atualizando telemetria e dados de satélite...',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    }
  }

  void _handleSearchTap() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _openSearchOverlay();
      return;
    }

    _searchTapCount++;
    _searchTapTimer?.cancel();
    _searchTapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_searchTapCount == 1) {
        // Single tap: Wikipedia
        _searchFocusNode.unfocus();
        VirtualTopography.directSearchTrigger.value = query;
      } else if (_searchTapCount == 2) {
        // Double tap: Google Search
        _searchFocusNode.unfocus();
        LauncherService.openUrl("https://www.google.com/search?q=${Uri.encodeComponent(query)}");
      } else if (_searchTapCount >= 3) {
        // Triple tap: Google Maps
        _searchFocusNode.unfocus();
        LauncherService.openUrl("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}");
      }
      _searchTapCount = 0;
    });
  }

  bool _wasSearchOpen = false;
  HeaderMode _savedHeaderMode = HeaderMode.none;
  bool _savedFilterBarExpanded = false;

  void _onSearchTextChanged() {
    final isSearchOpen = _searchController.text.trim().isNotEmpty;
    if (isSearchOpen && !_wasSearchOpen) {
      _wasSearchOpen = true;
      _savedHeaderMode = ContextHeader.isPanelOpenNotifier.value;
      _savedFilterBarExpanded = _isFilterBarExpanded;
      
      ContextHeader.isPanelOpenNotifier.value = HeaderMode.none;
      if (_isFilterBarExpanded) {
        _isFilterBarExpanded = false;
        _filterBarController.reverse();
      }
    } else if (!isSearchOpen && _wasSearchOpen) {
      _wasSearchOpen = false;
      ContextHeader.isPanelOpenNotifier.value = _savedHeaderMode;
      if (_savedFilterBarExpanded) {
        _isFilterBarExpanded = true;
        _filterBarController.forward();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultStatus();
    _loadAppsForOverlay();
    _loadHardwareInfo();
    _loadInitialStates();

    _filterBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 0.0, // Initially collapsed
    );
    ContextHeader.isPanelOpenNotifier.addListener(_onPanelOpenChanged);
    ContextHeader.isExtendedNotifier.addListener(_onPanelOpenChanged);
    VirtualTopography.onTapCallback = () {
      ContextHeader.isExtendedNotifier.value = false;
      if (_isFilterBarExpanded) {
        _toggleFilterBar();
      }
    };

    // Listen to Home button / swipe-up gesture from Android
    const MethodChannel('com.portal/launcher_setup').setMethodCallHandler((call) async {
      if (call.method == 'onHomePressed') {
        if (_currentPageIndex != 0) {
          _navigateToPage(0);
        } else {
          _closeSearchOverlay();
        }
      }
      return null;
    });
  }

  Future<void> _loadAppsForOverlay() async {
    final apps = await AppsService.getInstalledApps();
    if (mounted) {
      setState(() {
        _allApps = apps;
        _overlayFilteredApps = [];
      });
      _loadMostUsedApps();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    WidgetsBinding.instance.removeObserver(this);
    ContextHeader.isPanelOpenNotifier.removeListener(_onPanelOpenChanged);
    ContextHeader.isExtendedNotifier.removeListener(_onPanelOpenChanged);
    VirtualTopography.onTapCallback = null;
    _filterBarController.dispose();
    _searchTapTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _overlaySearchController.dispose();
    _searchFocusNode.dispose();
    _overlayFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultStatus();
    }
  }

  Future<void> _checkDefaultStatus() async {
    if (!isAndroidNative) return;
    final isDefault = await LauncherService.isDefaultHome();
    if (mounted) {
      setState(() {
        _isDefault = isDefault;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
      _searchOverlayOpen = false;
      _overlayFilteredApps = [];
      if (_isFilterBarExpanded) {
        _isFilterBarExpanded = false;
        _filterBarController.reverse();
      }
    });
    ContextHeader.isExtendedNotifier.value = false;

    _searchController.clear();
    _overlaySearchController.clear();
    _searchFocusNode.unfocus();
    _overlayFocusNode.unfocus();
    AppsListView.searchQueryNotifier.value = '';
    VirtualTopography.mapSearchQueryNotifier.value = '';
    MemoryExplorerView.fileSearchQueryNotifier.value = '';
  }

  void _openSearchOverlay() {
    setState(() => _searchOverlayOpen = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      _overlayFocusNode.requestFocus();
    });
  }

  void _closeSearchOverlay() {
    setState(() {
      _searchOverlayOpen = false;
      _overlayFilteredApps = [];
    });
    _overlaySearchController.clear();
    _searchController.clear();
    _overlayFocusNode.unfocus();
    _searchFocusNode.unfocus();
    VirtualTopography.mapSearchQueryNotifier.value = '';
    MemoryExplorerView.fileSearchQueryNotifier.value = '';
    AppsListView.searchQueryNotifier.value = '';
  }

  void _navigateToPage(int index) {
    if ((index - _currentPageIndex).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBarWidth = screenWidth * 0.5;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchOverlayOpen) {
          _closeSearchOverlay();
        } else if (ContextHeader.isExtendedNotifier.value) {
          ContextHeader.isExtendedNotifier.value = false;
        } else if (_sidebarController.leftBarWidth.value > 0.0) {
          _sidebarController.tryCloseLeftBar();
        } else if (_sidebarController.sideBarWidth.value > 0.0) {
          _sidebarController.tryCloseRightBar();
        } else if (_currentPageIndex > 0) {
          _navigateToPage(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: () {
                      final isTimeSpaceOpen = ContextHeader.isPanelOpenNotifier.value == HeaderMode.timeSpace;
                      final isExtendedOpen = ContextHeader.isExtendedNotifier.value;
                      if (_currentPageIndex == 0) {
                        return isExtendedOpen ? 280.0 : 148.0;
                      }
                      return isExtendedOpen ? 280.0 : (isTimeSpaceOpen ? 132.0 : 84.0);
                    }(),
                  ),

                  // Warning banner if Portal is not the default launcher
                  if (!_isDefault)
                    GestureDetector(
                      onTap: () async {
                        await LauncherService.requestDefaultHome();
                        // Re-check after a brief delay
                        Future.delayed(const Duration(seconds: 1), _checkDefaultStatus);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Definir Portal como Padrão',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Toque para configurar a tela de início do seu aparelho.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Main sliding views (Topography Map or A-Z Apps List)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Page 0: Topography map view (Expanding rectangle)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            if (_isFilterBarExpanded) {
                              _toggleFilterBar();
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(left: 12.0, right: 12.0, top: 0.0, bottom: 148.0),
                            child: VirtualTopography(),
                          ),
                        ),
                        // Page 1: Memory & Folder Explorer view
                        const MemoryExplorerView(),
                        // Page 2: Niagara-style A-Z list
                        const AppsListView(),
                        // Page 3: Device Notifications Inbox
                        const NotificationsInboxView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ContextHeader & FilterBar Stack (overlay positioned at top of Stack to paint ON TOP of earth)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 148.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_isFilterBarExpanded) {
                                _toggleFilterBar();
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0, bottom: 12.0),
                              child: ContextHeader(),
                            ),
                          ),
                          Positioned(
                            top: 32.0,
                            left: 0,
                            right: 0,
                            child: Align(
                              alignment: Alignment.center,
                              child: ValueListenableBuilder<HeaderMode>(
                                valueListenable: ContextHeader.isPanelOpenNotifier,
                                builder: (context, headerMode, child) {
                                  final String titleText = _currentPageIndex == 0
                                      ? 'Home'
                                      : _currentPageIndex == 1
                                          ? 'Memória'
                                          : _currentPageIndex == 2
                                              ? 'Aplicativos'
                                              : 'Correio';

                                  final bool isTitleVisible = (_currentPageIndex != 0)
                                      ? (headerMode == HeaderMode.filter)
                                      : ((headerMode == HeaderMode.filter) && _showHomeTitle);

                                  return AnimatedOpacity(
                                    opacity: isTitleVisible ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: GestureDetector(
                                      onTap: () {
                                        if (_currentPageIndex == 0) {
                                          VirtualTopography.toggleRotationTrigger.value = 
                                              !VirtualTopography.toggleRotationTrigger.value;
                                        }
                                      },
                                      child: Text(
                                        titleText,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_currentPageIndex == 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        bottom: (ContextHeader.isPanelOpenNotifier.value == HeaderMode.timeSpace) ? -2.0 : 12.0,
                        left: 0,
                        right: 0,
                        child: ValueListenableBuilder<HeaderMode>(
                          valueListenable: ContextHeader.isPanelOpenNotifier,
                          builder: (context, mode, child) {
                            if (mode == HeaderMode.none) {
                              return const SizedBox.shrink();
                            }
                            final double screenWidth = MediaQuery.of(context).size.width;
                            final double collapsedWidth = 48.0;
                            final double expandedWidth = screenWidth - 24.0;

                            return Padding(
                              padding: const EdgeInsets.only(left: 12.0, right: 12.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedBuilder(
                                  animation: _filterBarController,
                                  builder: (context, child) {
                                    final double progress = Curves.easeInOutCubic.transform(_filterBarController.value);
                                    final double currentWidth = ui.lerpDouble(collapsedWidth, expandedWidth, progress)!;

                                    return GestureDetector(
                                      onTap: () {
                                        if (!_isFilterBarExpanded) {
                                          _toggleFilterBar();
                                        }
                                      },
                                      onDoubleTap: _handleSatelliteDoubleTap,
                                      child: Container(
                                        width: currentWidth,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                              blurRadius: 4,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(24),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (_filterBarController.value < 0.9)
                                                Opacity(
                                                  opacity: (1.0 - _filterBarController.value).clamp(0.0, 1.0),
                                                  child: GestureDetector(
                                                    onDoubleTap: _handleSatelliteDoubleTap,
                                                    child: SizedBox(
                                                      width: 48,
                                                      height: 48,
                                                      child: Icon(
                                                        Icons.satellite_alt_rounded,
                                                        size: 20,
                                                        color: theme.colorScheme.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (_filterBarController.value > 0.1)
                                                Opacity(
                                                  opacity: _filterBarController.value,
                                                  child: Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: _toggleFilterBar,
                                                        onDoubleTap: _handleSatelliteDoubleTap,
                                                        behavior: HitTestBehavior.opaque,
                                                        child: Container(
                                                          width: 48,
                                                          height: 48,
                                                          alignment: Alignment.center,
                                                          child: Icon(
                                                            Icons.satellite_alt_rounded,
                                                            size: 20,
                                                            color: theme.colorScheme.primary,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: _buildEarthFilterChips(theme, isDark),
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
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Frosted Glass Bottom Navigation overlay (thumb-friendly absolute placement)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Navigation Button Bar (Same size/style as explore bar)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
                            if (velocity > 120) {
                              // Swiped RIGHT on the tab bar -> Go to NEXT page
                              if (_currentPageIndex < 3) {
                                _navigateToPage(_currentPageIndex + 1);
                              }
                            } else if (velocity < -120) {
                              // Swiped LEFT on the tab bar -> Go to PREVIOUS page
                              if (_currentPageIndex > 0) {
                                _navigateToPage(_currentPageIndex - 1);
                              }
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Builder(
                            builder: (context) {
                              final Color inactiveColor = isDark
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.black.withValues(alpha: 0.4);

                              return Row(
                                children: [
                                  // Left Tab (Home)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(0),
                                      child: Container(
                                        height: double.infinity,
                                        margin: EdgeInsets.zero,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 0
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.public_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 0
                                                  ? theme.colorScheme.onPrimary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Home',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 0
                                                    ? theme.colorScheme.onPrimary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Middle Tab 1 (Memória)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(1),
                                      child: Container(
                                        height: double.infinity,
                                        margin: EdgeInsets.zero,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 1
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.sd_storage_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 1
                                                  ? theme.colorScheme.onPrimary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Memória',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 1
                                                    ? theme.colorScheme.onPrimary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Middle Tab 2 (Aplicativos)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(2),
                                      child: Container(
                                        height: double.infinity,
                                        margin: EdgeInsets.zero,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 2
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.apps_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 2
                                                  ? theme.colorScheme.onPrimary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Apps',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 2
                                                    ? theme.colorScheme.onPrimary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Right Tab (Correio)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(3),
                                      child: Container(
                                        height: double.infinity,
                                        margin: EdgeInsets.zero,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 3
                                              ? theme.colorScheme.primary
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.mail_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 3
                                                  ? theme.colorScheme.onPrimary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Correio',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 3
                                                    ? theme.colorScheme.onPrimary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Fixed Bottom Explore Bar (Absolute lowest item)
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textAlign: TextAlign.right, // RTL alignment for thumb
                          onChanged: (text) {
                            final q = text.toLowerCase().trim();
                            if (_currentPageIndex == 0) {
                              setState(() {
                                _overlayFilteredApps = q.isEmpty
                                    ? []
                                    : _allApps.where((app) {
                                        return app.label.toLowerCase().contains(q) ||
                                            app.packageName.toLowerCase().contains(q);
                                      }).take(6).toList();
                              });
                            } else if (_currentPageIndex == 1) {
                              MemoryExplorerView.fileSearchQueryNotifier.value = text;
                            } else if (_currentPageIndex == 2) {
                              AppsListView.searchQueryNotifier.value = text;
                            }
                          },
                          onSubmitted: (query) {
                            final trimmed = query.trim();
                            if (_currentPageIndex == 0 && trimmed.isNotEmpty) {
                              _searchFocusNode.unfocus();
                              VirtualTopography.directSearchTrigger.value = trimmed;
                            } else {
                              _searchFocusNode.unfocus();
                            }
                          },
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await LauncherService.openCameraApp();
                                      } catch (e) {
                                        debugPrint('Erro ao abrir a câmera: $e');
                                      }
                                    },
                                    onDoubleTap: () async {
                                      try {
                                        await LauncherService.openGoogleLens();
                                      } catch (e) {
                                        debugPrint('Erro ao abrir o Google Lens: $e');
                                      }
                                    },
                                    child: Icon(
                                      Icons.remove_red_eye_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      try {
                                        await LauncherService.openVoiceRecorderApp();
                                      } catch (e) {
                                        debugPrint('Erro ao abrir o gravador: $e');
                                      }
                                    },
                                    child: Icon(
                                      Icons.hearing_rounded,
                                      size: 20,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            hintText: _currentPageIndex == 0
                                ? 'explorar!'
                                : _currentPageIndex == 1
                                    ? 'explorar memórias'
                                    : _currentPageIndex == 2
                                        ? 'explorar apps'
                                        : 'explorar correio',
                            hintStyle: TextStyle(
                              color: isDark ? const Color(0xFFECEFF1).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.35),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: _handleSearchTap,
                              child: Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

                        // Unified Home Explore Search Panel
            if (_currentPageIndex == 0 && _searchController.text.trim().isNotEmpty)
              Positioned(
                top: 84.0, // Standard top spacing
                bottom: 144.0, // Above the tab bar
                left: 12.0,
                right: 12.0,
                child: WikipediaSearchOverlay(
                controller: _wikipediaController,
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                overlayFilteredApps: _overlayFilteredApps,
                onClearSearch: () {
                  setState(() {
                    _searchController.clear();
                    _overlayFilteredApps.clear();
                    _wikipediaController.reset();
                  });
                  _searchFocusNode.unfocus();
                },
                onAppTap: () {
                  setState(() {
                    _overlayFilteredApps.clear();
                    _searchController.clear();
                  });
                  _searchFocusNode.unfocus();
                },
                isDark: isDark,
                theme: theme,
              ),
              ),

             // ── Custom Left Swipe Sidebar ──
             LeftSidebarView(controller: _sidebarController),
             // ── Custom Right Swipe Sidebar ──
             RightSidebarView(controller: _sidebarController),
           ],
        ),
      ),
    ),
  );
}











// ignore: unused_element
Widget _buildSidebarItem(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String subtitle,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return InkWell(
    onTap: () {
      // Future actions
    },
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ignore: unused_element
  Widget _buildSearchOverlay(ThemeData theme, bool isDark) {
    final hasApps = _overlayFilteredApps.isNotEmpty;
    return Padding(
      key: const ValueKey('searchoverlay'),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Search field row ──────────────────────────────────────
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _overlaySearchController,
                          focusNode: _overlayFocusNode,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Buscar apps, locais...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (text) {
                            // Always search apps
                            final q = text.toLowerCase().trim();
                            setState(() {
                              _overlayFilteredApps = q.isEmpty
                                  ? []
                                  : _allApps.where((app) {
                                      return app.label.toLowerCase().contains(q) ||
                                          app.packageName.toLowerCase().contains(q);
                                    }).take(8).toList();
                            });
                            // Also fire page-specific search
                            if (_currentPageIndex == 0) {
                              VirtualTopography.mapSearchQueryNotifier.value = text;
                            } else if (_currentPageIndex == 1) {
                              MemoryExplorerView.fileSearchQueryNotifier.value = text;
                            }
                            AppsListView.searchQueryNotifier.value = text;
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: _closeSearchOverlay,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── App results ───────────────────────────────────────────
                if (hasApps) ...[
                  Divider(
                    height: 1,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                  ),
                  SizedBox(
                    height: 72,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: _overlayFilteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _overlayFilteredApps[index];
                        return GestureDetector(
                          onTap: () {
                            AppsService.launchApp(app.packageName, app.className);
                            _closeSearchOverlay();
                          },
                          child: Container(
                            width: 56,
                            margin: const EdgeInsets.only(right: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FutureBuilder<Uint8List?>(
                                  future: AppsService.getAppIcon(app.packageName),
                                  builder: (context, snap) {
                                    if (snap.hasData && snap.data != null) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(snap.data!, width: 36, height: 36, fit: BoxFit.cover),
                                      );
                                    }
                                    return Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  app.label,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.75),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarthFilterChips(ThemeData theme, bool isDark) {
    final filters = [
      {'name': 'Solo', 'value': 'Satélite', 'icon': Icons.satellite_alt_rounded},
      {'name': 'Nuvens', 'value': 'Clima', 'icon': Icons.cloud_rounded},
      {'name': 'Ventos', 'value': 'Ventos', 'icon': Icons.air_rounded},
      {'name': 'Vetor', 'value': 'Vetor (3D)', 'icon': Icons.grid_view_rounded},
      {'name': 'Monit.', 'value': 'Monitoramento', 'icon': Icons.analytics_rounded},
    ];

    final Color inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);

    return ValueListenableBuilder<Set<String>>(
      valueListenable: VirtualTopography.earthFilterNotifier,
      builder: (context, activeLayers, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...filters.map((filter) {
              final filterName = filter['name'] as String;
              final filterValue = filter['value'] as String;
              final filterIcon = filter['icon'] as IconData;

              final bool isSelected = activeLayers.contains(filterValue);

              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: GestureDetector(
                  onTap: () {
                    final newSet = Set<String>.from(activeLayers);
                    if (isSelected) {
                      newSet.remove(filterValue);
                    } else {
                      newSet.add(filterValue);
                    }
                    if (newSet.isEmpty) {
                      newSet.addAll(['Satélite', 'Clima']);
                    }
                    VirtualTopography.earthFilterNotifier.value = newSet;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          filterIcon,
                          size: 13,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : inactiveColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          filterName,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              }),
              ValueListenableBuilder<int>(
                valueListenable: VirtualTopography.rotationSpeedNotifier,
                builder: (context, speed, _) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: GestureDetector(
                      onTap: () {
                        // Cycles: 1 -> 10 -> 100 -> 1000 -> 10000 -> 1
                        int nextSpeed = speed * 10;
                        if (nextSpeed > 10000) nextSpeed = 1;
                        VirtualTopography.rotationSpeedNotifier.value = nextSpeed;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: speed > 1 ? theme.colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: speed > 1 ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              speed > 1 ? Icons.fast_forward_rounded : Icons.play_arrow_rounded,
                              size: 13,
                              color: speed > 1 ? theme.colorScheme.primary : inactiveColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              speed == 1 ? 'Rot. Real' : 'Rot. x$speed',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: speed > 1 ? theme.colorScheme.primary : inactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }






}
