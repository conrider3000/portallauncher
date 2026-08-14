import 'dart:async';
import 'dart:convert';
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
import '../widgets/notifications_inbox_view.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
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
  double _sideBarWidth = 0.0;
  double _leftBarWidth = 0.0;
  bool _flashlightEnabled = false;
  bool _autoRotationEnabled = false;
  bool _isOfflineMode = false;
  int _rightSidebarTabIndex = 0; // 0: Mais Utilizados & Telemetria, 1: Histórico Recente

  // For unified app search inside the overlay
  List<AppInfo> _allApps = [];
  List<AppInfo> _overlayFilteredApps = [];
  // ignore: unused_field
  final Map<String, Uint8List?> _overlayIconCache = {};

  Map<String, dynamic> _hardwareInfo = {};
  List<AppInfo> _mostUsedApps = [];
  bool _fmRadioSimEnabled = false;
  DateTime? _lastLeftBarOpenedTime;
  DateTime? _lastRightBarOpenedTime;

  // Wikipedia Interactive Overlay Flow
  int _exploreOverlayMode = 0; // 0: Menu, 1: Candidate Terms, 2: Full Article
  List<Map<String, String>> _wikiTermsList = [];
  bool _loadingWikiTerms = false;
  Map<String, String>? _selectedWikiArticle;
  bool _loadingWikiArticle = false;

  Future<void> _fetchWikiCandidateTerms(String query) async {
    setState(() {
      _exploreOverlayMode = 1;
      _loadingWikiTerms = true;
      _wikiTermsList = [];
    });

    final String searchUrl = 'https://pt.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(query)}&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchList = data['query']?['search'] as List?;
        if (searchList != null && searchList.isNotEmpty) {
          final List<Map<String, String>> terms = [];
          for (var item in searchList) {
            final title = item['title'] as String? ?? '';
            final snippet = (item['snippet'] as String? ?? '').replaceAll(RegExp(r'<[^>]*>'), '');
            final timestamp = item['timestamp'] as String? ?? '';
            terms.add({
              'title': title,
              'snippet': snippet,
              'timestamp': _formatWikiDate(timestamp),
            });
          }
          if (mounted) {
            setState(() {
              _wikiTermsList = terms;
              _loadingWikiTerms = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _wikiTermsList = [];
              _loadingWikiTerms = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingWikiTerms = false;
        });
      }
    }
  }

  Future<void> _fetchWikiArticleFull(String title) async {
    setState(() {
      _exploreOverlayMode = 2;
      _loadingWikiArticle = true;
      _selectedWikiArticle = null;
    });

    final String url = 'https://pt.wikipedia.org/w/api.php?action=query&prop=extracts|revisions&rvprop=timestamp&explaintext&titles=${Uri.encodeComponent(title)}&format=json&origin=*';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pages = data['query']?['pages'] as Map?;
        if (pages != null && pages.isNotEmpty) {
          final pageId = pages.keys.first;
          final pageData = pages[pageId];
          final String extract = pageData['extract'] ?? 'Conteúdo indisponível.';
          final revisions = pageData['revisions'] as List?;
          String dateStr = 'Atualização recente';
          if (revisions != null && revisions.isNotEmpty) {
            final ts = revisions[0]['timestamp'] as String? ?? '';
            dateStr = _formatWikiDate(ts);
          }

          if (mounted) {
            setState(() {
              _selectedWikiArticle = {
                'title': title,
                'extract': extract,
                'updated': dateStr,
              };
              _loadingWikiArticle = false;
            });
            // Focus 3D Globe camera on term
            VirtualTopography.directSearchTrigger.value = title;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingWikiArticle = false;
        });
      }
    }
  }

  String _formatWikiDate(String isoString) {
    if (isoString.isEmpty) return 'Recente';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

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

  @override
  void initState() {
    super.initState();
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
      _sideBarWidth = 0.0;
      _leftBarWidth = 0.0;
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
        } else if (ContextHeader.isPanelOpenNotifier.value == HeaderMode.timeSpace) {
          ContextHeader.isPanelOpenNotifier.value = HeaderMode.none;
        } else if (_leftBarWidth > 0.0) {
          final now = DateTime.now();
          if (_lastLeftBarOpenedTime == null || now.difference(_lastLeftBarOpenedTime!).inMilliseconds > 500) {
            setState(() => _leftBarWidth = 0.0);
          }
        } else if (_sideBarWidth > 0.0) {
          final now = DateTime.now();
          if (_lastRightBarOpenedTime == null || now.difference(_lastRightBarOpenedTime!).inMilliseconds > 500) {
            setState(() => _sideBarWidth = 0.0);
          }
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
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 0.0, bottom: 148.0),
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
                              padding: EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0, bottom: 8.0),
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
                            final double expandedWidth = screenWidth - 40.0;

                            return Padding(
                              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
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
                    padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.55),
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
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

            // Unified Home Explore Search Panel — floats above bottom nav bar when user types on Home (Page 0)
            if (_currentPageIndex == 0 && _searchController.text.trim().isNotEmpty)
              Positioned(
                top: _exploreOverlayMode == 2 ? 148 : null,
                bottom: 148, // sits above bottom nav bar
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      constraints: _exploreOverlayMode == 2 ? null : BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF0F1511) : Colors.white).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: _exploreOverlayMode == 2 ? MainAxisSize.max : MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row with Back / Title / Close
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                            child: Row(
                              children: [
                                if (_exploreOverlayMode > 0)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_exploreOverlayMode == 2) {
                                          _exploreOverlayMode = 1;
                                        } else {
                                          _exploreOverlayMode = 0;
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.arrow_back_rounded, size: 18, color: theme.colorScheme.primary),
                                    ),
                                  )
                                else
                                  Icon(Icons.explore_rounded, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _exploreOverlayMode == 0
                                        ? 'Explorar "${_searchController.text.trim()}"'
                                        : (_exploreOverlayMode == 1
                                            ? 'Escolha de Termos: "${_searchController.text.trim()}"'
                                            : (_selectedWikiArticle?['title'] ?? 'Artigo Wikipédia')),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                    setState(() {
                                      _overlayFilteredApps = [];
                                      _exploreOverlayMode = 0;
                                      _wikiTermsList = [];
                                      _selectedWikiArticle = null;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.15)),

                          // ── MODE 0: MAIN EXPLORE OPTIONS MENU ──
                          if (_exploreOverlayMode == 0) ...[
                            if (_overlayFilteredApps.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Text(
                                  '1. APLICATIVOS INSTALADOS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 68,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: _overlayFilteredApps.length,
                                  itemBuilder: (context, index) {
                                    final app = _overlayFilteredApps[index];
                                    return GestureDetector(
                                      onTap: () {
                                        AppsService.launchApp(app.packageName, app.className);
                                        _searchController.clear();
                                        _searchFocusNode.unfocus();
                                        setState(() {
                                          _overlayFilteredApps = [];
                                        });
                                      },
                                      child: Container(
                                        width: 54,
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
                                                    child: Image.memory(snap.data!, width: 34, height: 34, fit: BoxFit.cover),
                                                  );
                                                }
                                                return Container(
                                                  width: 34, height: 34,
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
                                                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              app.label,
                                              style: TextStyle(fontSize: 8.5, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.8)),
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
                              Divider(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                            ],

                            // 2. Wikipedia Search Action
                            _buildExploreActionTile(
                              icon: Icons.menu_book_rounded,
                              title: '2. Artigo na Wikipédia',
                              subtitle: 'Escolher termos relacionados e ler artigo completo',
                              theme: theme,
                              isDark: isDark,
                              onTap: () {
                                final query = _searchController.text.trim();
                                _searchFocusNode.unfocus();
                                _fetchWikiCandidateTerms(query);
                              },
                            ),

                            // 3. Google Web Search Action
                            _buildExploreActionTile(
                              icon: Icons.search_rounded,
                              title: '3. Pesquisar no Google',
                              subtitle: 'Abrir resultados de busca no navegador',
                              theme: theme,
                              isDark: isDark,
                              onTap: () {
                                final query = _searchController.text.trim();
                                _searchFocusNode.unfocus();
                                LauncherService.openUrl("https://www.google.com/search?q=${Uri.encodeComponent(query)}");
                              },
                            ),

                            // 4. Google Maps Search Action
                            _buildExploreActionTile(
                              icon: Icons.map_rounded,
                              title: '4. Google Maps',
                              subtitle: 'Explorar local ou mapa no navegador',
                              theme: theme,
                              isDark: isDark,
                              onTap: () {
                                final query = _searchController.text.trim();
                                _searchFocusNode.unfocus();
                                LauncherService.openUrl("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}");
                              },
                            ),
                            const SizedBox(height: 6),
                          ]
                          // ── MODE 1: CANDIDATE WIKIPEDIA TERMS LIST ──
                          else if (_exploreOverlayMode == 1) ...[
                            if (_loadingWikiTerms)
                              const Padding(
                                padding: EdgeInsets.all(28.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_wikiTermsList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'Nenhum artigo encontrado na Wikipédia.',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 280),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  itemCount: _wikiTermsList.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
                                  itemBuilder: (context, index) {
                                    final term = _wikiTermsList[index];
                                    final title = term['title'] ?? '';
                                    final snippet = term['snippet'] ?? '';
                                    final ts = term['timestamp'] ?? '';

                                    return InkWell(
                                      onTap: () => _fetchWikiArticleFull(title),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.article_rounded, size: 14, color: theme.colorScheme.primary),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black,
                                                    ),
                                                  ),
                                                ),
                                                if (ts.isNotEmpty)
                                                  Text(
                                                    ts,
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (snippet.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                snippet,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ]
                          // ── MODE 2: FULL ARTICLE DISPLAY ──
                          else if (_exploreOverlayMode == 2) ...[
                            if (_loadingWikiArticle)
                              const Padding(
                                padding: EdgeInsets.all(36.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_selectedWikiArticle != null) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ARTIGO WIKIPÉDIA',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: theme.colorScheme.primary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    Text(
                                      '📅 Atualização: ${_selectedWikiArticle!['updated']}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.1)),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedWikiArticle!['title']!,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.primary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        _selectedWikiArticle!['extract']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

             // ── Custom Left Swipe Sidebar (Sensors & Radios) ─────────────────
             Positioned(
               top: 0,
               bottom: 0,
               left: 0,
               width: _leftBarWidth > 0 ? screenWidth : 60.0,
               child: GestureDetector(
                 behavior: HitTestBehavior.translucent,
                 onHorizontalDragUpdate: (details) {
                   setState(() {
                     _leftBarWidth = (_leftBarWidth + details.delta.dx).clamp(0.0, maxBarWidth);
                     _lastLeftBarOpenedTime = DateTime.now();
                   });
                 },
                 onHorizontalDragEnd: (details) {
                   final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
                   if (velocity > 200) {
                     setState(() {
                       _leftBarWidth = maxBarWidth;
                       _lastLeftBarOpenedTime = DateTime.now();
                     });
                   } else if (velocity < -200) {
                     setState(() {
                       _leftBarWidth = 0.0;
                       _lastLeftBarOpenedTime = null;
                     });
                   } else {
                     setState(() {
                       if (_leftBarWidth < 36.0) {
                         _leftBarWidth = 0.0;
                         _lastLeftBarOpenedTime = null;
                       } else if (_leftBarWidth < maxBarWidth * 0.5) {
                         _leftBarWidth = 72.0;
                         _lastLeftBarOpenedTime = DateTime.now();
                       } else {
                         _leftBarWidth = maxBarWidth;
                         _lastLeftBarOpenedTime = DateTime.now();
                       }
                     });
                   }
                 },
                 child: Stack(
                   children: [
                     if (_leftBarWidth > 0)
                       Positioned.fill(
                         child: GestureDetector(
                           onTap: () => setState(() {
                             _leftBarWidth = 0.0;
                             _lastLeftBarOpenedTime = null;
                           }),
                           child: Container(
                             color: Colors.black.withValues(alpha: 0.15 * (_leftBarWidth / maxBarWidth)),
                           ),
                         ),
                       ),
                     Positioned(
                       top: 0,
                       bottom: 0,
                       left: 0,
                       width: _leftBarWidth > 0 ? _leftBarWidth : 0.0,
                       child: GestureDetector(
                         onTap: () {}, // Consume taps inside the panel

                         child: ClipRRect(
                           borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                           child: BackdropFilter(
                             filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                             child: Container(
                               decoration: BoxDecoration(
                                 color: (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA)).withValues(alpha: 0.85),
                                 borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                                 border: Border(
                                   right: BorderSide(
                                     color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                     width: 1.5,
                                   ),
                                 ),
                               ),
                               child: SafeArea(
                                 child: _leftBarWidth < 120
                                     ? _buildMiniLeftBarContent(theme, isDark)
                                     : _buildFullLeftBarContent(theme, isDark),
                               ),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ],
                 ),
               ),
             ),

             // ── Custom Right Swipe Sidebar (Apps) ─────────────────
             Positioned(
               top: 0,
               bottom: 0,
               right: 0,
               width: _sideBarWidth > 0 ? screenWidth : 60.0,
               child: GestureDetector(
                 behavior: HitTestBehavior.translucent,
                 onHorizontalDragUpdate: (details) {
                   if (_sideBarWidth == 0.0) {
                     _loadMostUsedApps();
                   }
                   setState(() {
                     _sideBarWidth = (_sideBarWidth - details.delta.dx).clamp(0.0, maxBarWidth);
                     _lastRightBarOpenedTime = DateTime.now();
                   });
                 },
                 onHorizontalDragEnd: (details) {
                   final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
                   if (velocity < -200) {
                     _loadMostUsedApps();
                     setState(() {
                       _sideBarWidth = maxBarWidth;
                       _lastRightBarOpenedTime = DateTime.now();
                     });
                   } else if (velocity > 200) {
                     setState(() {
                       _sideBarWidth = 0.0;
                       _lastRightBarOpenedTime = null;
                     });
                   } else {
                     setState(() {
                       if (_sideBarWidth < 36.0) {
                         _sideBarWidth = 0.0;
                         _lastRightBarOpenedTime = null;
                       } else if (_sideBarWidth < maxBarWidth * 0.5) {
                         _loadMostUsedApps();
                         _sideBarWidth = 72.0;
                         _lastRightBarOpenedTime = DateTime.now();
                       } else {
                         _loadMostUsedApps();
                         _sideBarWidth = maxBarWidth;
                         _lastRightBarOpenedTime = DateTime.now();
                       }
                     });
                   }
                 },
                 child: Stack(
                   children: [
                     if (_sideBarWidth > 0)
                       Positioned.fill(
                         child: GestureDetector(
                           onTap: () => setState(() {
                             _sideBarWidth = 0.0;
                             _lastRightBarOpenedTime = null;
                           }),
                           child: Container(
                             color: Colors.black.withValues(alpha: 0.15 * (_sideBarWidth / maxBarWidth)),
                           ),
                         ),
                       ),
                     Positioned(
                       top: 0,
                       bottom: 0,
                       right: 0,
                       width: _sideBarWidth > 0 ? _sideBarWidth : 0.0,
                       child: GestureDetector(
                         onTap: () {}, // Consume taps inside the panel

                         child: ClipRRect(
                           borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                           child: BackdropFilter(
                             filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                             child: Container(
                               decoration: BoxDecoration(
                                 color: (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA)).withValues(alpha: 0.85),
                                 borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
                                 border: Border(
                                   left: BorderSide(
                                     color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                     width: 1.5,
                                   ),
                                 ),
                               ),
                               child: SafeArea(
                                 child: _sideBarWidth < 120
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
               ),
             )
          ],
        ),
      ),
    ),
  );
  }





  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0F1511) : Colors.white).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.airplanemode_active_rounded,
                            color: Color(0xFFFF3B30),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'MODO OFFLINE ATIVO',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFF3B30),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'O Portal Launcher está operando em modo de isolamento de sinal local.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Wi-Fi, Bluetooth, NFC, Rádio FM e Lanterna foram desligados.\n'
                      '• Transmissões de dados móveis, clima e telemetria remota estão bloqueadas.\n'
                      '• O smartphone opera em isolamento de rádio total.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'ENTENDIDO (MANTER ISOLAMENTO)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
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

  Widget _buildToolButtonTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool active,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
    Color? activeColor,
    String? badgeText,
  }) {
    final Color effectiveColor = activeColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? effectiveColor.withValues(alpha: 0.14)
                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? effectiveColor.withValues(alpha: 0.4)
                  : theme.colorScheme.primary.withValues(alpha: 0.08),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: active
                      ? effectiveColor.withValues(alpha: 0.2)
                      : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: active ? effectiveColor : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: active ? (isDark ? Colors.white : Colors.black) : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
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
  }

  Widget _buildCompassCard(ThemeData theme, bool isDark) {
    return _buildToolButtonTile(
      title: 'Bússola Magnética',
      subtitle: 'Sensor Magnetômetro Interno',
      icon: Icons.explore_rounded,
      active: true,
      theme: theme,
      isDark: isDark,
      onTap: () {
        setState(() {
          _leftBarWidth = MediaQuery.of(context).size.width * 0.5;
        });
      },
    );
  }

  Widget _buildFullLeftBarContent(ThemeData theme, bool isDark) {
    final wifi = _hardwareInfo['wifi'] as Map? ?? {};
    final bool wifiEnabled = wifi['enabled'] == true;
    final String wifiSsid = wifi['ssid'] ?? '';
    final int wifiSpeed = wifi['speed'] ?? 0;

    final bluetooth = _hardwareInfo['bluetooth'] as Map? ?? {};
    final bool btEnabled = bluetooth['enabled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Master Offline Mode Button Card ──────────────────────────────
          _buildToolButtonTile(
            title: _isOfflineMode ? 'MODO OFFLINE ATIVO' : 'MODO ONLINE',
            subtitle: _isOfflineMode
                ? 'Isolamento de rádio ativo no launcher'
                : 'Todas as transmissões e buscas ativas',
            icon: _isOfflineMode ? Icons.airplanemode_active_rounded : Icons.cell_tower_rounded,
            active: _isOfflineMode,
            activeColor: const Color(0xFFFF3B30),
            badgeText: _isOfflineMode ? 'OFFLINE' : 'ONLINE',
            theme: theme,
            isDark: isDark,
            onTap: () async {
              final newOffline = !_isOfflineMode;
              setState(() {
                _isOfflineMode = newOffline;
                if (newOffline) {
                  _fmRadioSimEnabled = false;
                }
              });
              if (newOffline) {
                await LauncherService.toggleWifi(false);
                await LauncherService.toggleBluetooth(false);
                await LauncherService.toggleFlashlight(false);
                _showOfflineDialog();
              }
            },
          ),
          Divider(color: theme.colorScheme.primary.withValues(alpha: 0.15)),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildSectionTitle('FERRAMENTAS DE HARDWARE', theme),
                
                // 1. Calculadora
                _buildToolButtonTile(
                  title: 'Calculadora',
                  subtitle: 'Calculadora rápida do sistema',
                  icon: Icons.calculate_rounded,
                  active: true,
                  badgeText: 'ABRIR',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openCalculatorApp(),
                ),

                // 2. Câmera
                _buildToolButtonTile(
                  title: 'Câmera Digital',
                  subtitle: 'Captura de fotos e vídeos',
                  icon: Icons.camera_alt_rounded,
                  active: true,
                  badgeText: 'ABRIR',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openCameraApp(),
                ),

                // 3. Lanterna LED
                _buildToolButtonTile(
                  title: 'Lanterna LED',
                  subtitle: _flashlightEnabled ? 'LED traseiro ativado' : 'Toque para ligar a lanterna',
                  icon: _flashlightEnabled ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                  active: _flashlightEnabled,
                  badgeText: _flashlightEnabled ? 'ON' : 'OFF',
                  theme: theme,
                  isDark: isDark,
                  onTap: () async {
                    final newSt = !_flashlightEnabled;
                    await LauncherService.toggleFlashlight(newSt);
                    setState(() {
                      _flashlightEnabled = newSt;
                    });
                  },
                ),

                // 4. Bússola Magnética
                _buildCompassCard(theme, isDark),

                // 5. Rádio FM Analógico
                _buildToolButtonTile(
                  title: 'Rádio FM Analógico',
                  subtitle: _fmRadioSimEnabled
                      ? 'Frequência 98.9 MHz • Receptor ativo'
                      : 'Toque para ligar o receptor FM',
                  icon: Icons.radio_rounded,
                  active: _fmRadioSimEnabled,
                  badgeText: _fmRadioSimEnabled ? 'ATIVO' : 'OFF',
                  theme: theme,
                  isDark: isDark,
                  onTap: () {
                    setState(() {
                      _fmRadioSimEnabled = !_fmRadioSimEnabled;
                    });
                  },
                ),

                // 6. Auto-Rotação
                _buildToolButtonTile(
                  title: 'Giro da Tela',
                  subtitle: _autoRotationEnabled ? 'Giro livre ativado' : 'Orientação bloqueada',
                  icon: _autoRotationEnabled ? Icons.screen_rotation_rounded : Icons.screen_lock_rotation_rounded,
                  active: _autoRotationEnabled,
                  badgeText: _autoRotationEnabled ? 'AUTO' : 'TRAVADO',
                  theme: theme,
                  isDark: isDark,
                  onTap: () async {
                    final newMode = !_autoRotationEnabled;
                    final success = await LauncherService.setAutoRotationEnabled(newMode);
                    if (success) {
                      setState(() {
                        _autoRotationEnabled = newMode;
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),
                _buildSectionTitle('CONECTIVIDADE & TRANSMISSÃO', theme),

                // 7. Wi-Fi
                _buildToolButtonTile(
                  title: 'Wi-Fi',
                  subtitle: wifiEnabled
                      ? (wifiSsid.isNotEmpty && wifiSsid != 'Desconectado'
                          ? '$wifiSsid ${wifiSpeed > 0 ? "• $wifiSpeed Mbps" : ""}'
                          : 'Conectado')
                      : 'Toque para ativar Wi-Fi',
                  icon: wifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  active: wifiEnabled,
                  badgeText: wifiEnabled ? 'CONECTADO' : 'DESLIGADO',
                  theme: theme,
                  isDark: isDark,
                  onTap: () async {
                    await LauncherService.toggleWifi(!wifiEnabled);
                    Future.delayed(const Duration(milliseconds: 1200), () {
                      _loadHardwareInfo();
                    });
                  },
                ),

                // 8. Bluetooth
                _buildToolButtonTile(
                  title: 'Bluetooth',
                  subtitle: btEnabled ? 'Dispositivo visível e pronto' : 'Toque para ativar Bluetooth',
                  icon: btEnabled ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                  active: btEnabled,
                  badgeText: btEnabled ? 'ATIVO' : 'DESLIGADO',
                  theme: theme,
                  isDark: isDark,
                  onTap: () async {
                    await LauncherService.toggleBluetooth(!btEnabled);
                    Future.delayed(const Duration(milliseconds: 1200), () {
                      _loadHardwareInfo();
                    });
                  },
                ),

                // 9. Dados Móveis
                _buildToolButtonTile(
                  title: 'Rede Celular (4G/5G)',
                  subtitle: 'Operadora & dados móveis',
                  icon: Icons.signal_cellular_alt_rounded,
                  active: true,
                  badgeText: 'PAINEL',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.toggleCellular(),
                ),

                // 10. NFC
                _buildToolButtonTile(
                  title: 'NFC & Pagamentos',
                  subtitle: 'Comunicação por aproximação',
                  icon: Icons.nfc_rounded,
                  active: true,
                  badgeText: 'PAINEL',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openNfcSettings(),
                ),
              ],
            ),
          ),

          Divider(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'PORTAL OS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
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
          // ── TOP GREEN SECTION TITLE ─────────────────────────────────
          Text(
            _rightSidebarTabIndex == 0 ? 'APLICATIVOS MAIS UTILIZADOS' : 'ÚLTIMOS APPS ABERTOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary, // Signature App Green!
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

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
                    padding: EdgeInsets.zero,
                    itemCount: _mostUsedApps.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = _mostUsedApps[index];
                      return InkWell(
                        onTap: () async {
                          setState(() => _sideBarWidth = 0.0);
                          await AppsService.launchApp(app.packageName, app.className);
                          _loadMostUsedApps();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: AppsService.getAppIcon(app.packageName),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        snapshot.data!,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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


  Widget _buildExploreActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ],
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
            children: filters.map((filter) {
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
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.primary.withValues(alpha: 0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }


  Widget _buildMiniLeftBarContent(ThemeData theme, bool isDark) {
    final wifiEnabled = _hardwareInfo['wifi']?['enabled'] == true;
    final bluetoothEnabled = _hardwareInfo['bluetooth']?['enabled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 4,
            height: 32,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildMiniSensorToggle(
                    icon: _isOfflineMode ? Icons.airplanemode_active_rounded : Icons.cell_tower_rounded,
                    enabled: _isOfflineMode,
                    tooltip: 'Modo Offline: ${_isOfflineMode ? "ATIVO" : "INATIVO"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      final newOffline = !_isOfflineMode;
                      setState(() {
                        _isOfflineMode = newOffline;
                        if (newOffline) {
                          _fmRadioSimEnabled = false;
                        }
                      });
                      if (newOffline) {
                        await LauncherService.toggleWifi(false);
                        await LauncherService.toggleBluetooth(false);
                        await LauncherService.toggleFlashlight(false);
                        _showOfflineDialog();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: wifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    enabled: wifiEnabled,
                    tooltip: 'Wi-Fi: ${wifiEnabled ? "Ativo" : "Inativo"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      await LauncherService.toggleWifi(!wifiEnabled);
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        _loadHardwareInfo();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: bluetoothEnabled ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                    enabled: bluetoothEnabled,
                    tooltip: 'Bluetooth: ${bluetoothEnabled ? "Ativo" : "Inativo"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      await LauncherService.toggleBluetooth(!bluetoothEnabled);
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        _loadHardwareInfo();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.network_cell_rounded,
                    enabled: !_isOfflineMode,
                    tooltip: 'Dados Móveis (4G/5G)',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.toggleCellular(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.nfc_rounded,
                    enabled: !_isOfflineMode,
                    tooltip: 'NFC & Pagamento sem Contato',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openNfcSettings(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.calculate_rounded,
                    enabled: true,
                    tooltip: 'Calculadora',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openCalculatorApp(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.camera_alt_rounded,
                    enabled: true,
                    tooltip: 'Câmera',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openCameraApp(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.explore_rounded,
                    enabled: true,
                    tooltip: 'Bússola Magnética',
                    theme: theme,
                    isDark: isDark,
                    onTap: () {
                      setState(() {
                        _leftBarWidth = MediaQuery.of(context).size.width * 0.5;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _fmRadioSimEnabled ? Icons.radio_rounded : Icons.radio_button_off_rounded,
                    enabled: _fmRadioSimEnabled,
                    tooltip: 'Rádio FM Analógico: ${_fmRadioSimEnabled ? "Ligado" : "Desligado"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () {
                      if (_isOfflineMode) {
                        _showOfflineDialog();
                        return;
                      }
                      setState(() {
                        _fmRadioSimEnabled = !_fmRadioSimEnabled;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _flashlightEnabled ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                    enabled: _flashlightEnabled,
                    tooltip: 'Lanterna: ${_flashlightEnabled ? "Ativa" : "Inativa"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      final newMode = !_flashlightEnabled;
                      await LauncherService.toggleFlashlight(newMode);
                      setState(() {
                        _flashlightEnabled = newMode;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _autoRotationEnabled ? Icons.screen_rotation_rounded : Icons.screen_lock_rotation_rounded,
                    enabled: _autoRotationEnabled,
                    tooltip: 'Rotação da Tela: ${_autoRotationEnabled ? "Auto" : "Bloqueada"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      final newMode = !_autoRotationEnabled;
                      final success = await LauncherService.setAutoRotationEnabled(newMode);
                      if (success) {
                        setState(() {
                          _autoRotationEnabled = newMode;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildMiniSensorToggle(
            icon: Icons.build_circle_rounded,
            enabled: true,
            tooltip: 'Barra de Ferramentas completa',
            theme: theme,
            isDark: isDark,
            onTap: () {
              setState(() {
                _leftBarWidth = MediaQuery.of(context).size.width * 0.5;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSideBarContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
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
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final app = _mostUsedApps[index];
                      return Center(
                        child: Tooltip(
                          message: app.label,
                          child: InkWell(
                            onTap: () async {
                              setState(() => _sideBarWidth = 0.0);
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

  Widget _buildMiniSensorToggle({
    required IconData icon,
    required bool enabled,
    required String tooltip,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled 
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

}
