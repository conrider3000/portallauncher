import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LauncherScreenState extends State<LauncherScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentPageIndex = 0;
  bool _isDefault = true;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _overlaySearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _overlayFocusNode = FocusNode();
  bool _searchOverlayOpen = false;
  double _lastPointerDownX = 0.0;

  // For unified app search inside the overlay
  List<AppInfo> _allApps = [];
  List<AppInfo> _overlayFilteredApps = [];
  final Map<String, Uint8List?> _overlayIconCache = {};

  Map<String, dynamic> _hardwareInfo = {};
  bool _loadingHardware = true;

  Future<void> _loadHardwareInfo() async {
    try {
      final info = await LauncherService.getDeviceHardwareInfo();
      if (mounted) {
        setState(() {
          _hardwareInfo = info;
          _loadingHardware = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingHardware = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultStatus();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
    _loadAppsForOverlay();
    _loadHardwareInfo();

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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    });
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
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Listener(
      onPointerDown: (PointerDownEvent event) {
        _lastPointerDownX = event.position.dx;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeDrawer();
          } else if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
            _scaffoldKey.currentState?.closeEndDrawer();
          } else if (_currentPageIndex > 0) {
            _navigateToPage(0);
          } else {
            Future.delayed(const Duration(milliseconds: 120), () {
              if (!mounted) return;
              if (_lastPointerDownX > screenWidth / 2) {
                _scaffoldKey.currentState?.openEndDrawer();
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            });
          }
        },
        child: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          width: 290,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF0F1411) : const Color(0xFFF0F4F1)).withOpacity(0.85),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
                  border: Border(
                    right: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      width: 1.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sensors_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Painel de Sensores',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (!_loadingHardware)
                              IconButton(
                                icon: Icon(Icons.refresh_rounded, size: 18, color: theme.colorScheme.primary.withOpacity(0.6)),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() => _loadingHardware = true);
                                  _loadHardwareInfo();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
                        
                        Expanded(
                          child: _loadingHardware
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: theme.colorScheme.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : ListView(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  children: [
                                    _buildSectionTitle('RÁDIOS & COMUNICAÇÃO', theme),
                                    _buildWifiTile(theme, isDark),
                                    _buildRadioTile('Bluetooth', _hardwareInfo['bluetooth'] ?? {}, Icons.bluetooth_rounded, theme, isDark),
                                    _buildRadioTile('NFC (Near Field)', _hardwareInfo['nfc'] ?? {}, Icons.nfc_rounded, theme, isDark),
                                    _buildRadioTile('Infravermelho', _hardwareInfo['infrared'] ?? {}, Icons.settings_remote_rounded, theme, isDark),
                                    
                                    const SizedBox(height: 16),
                                    
                                    _buildSectionTitle('SENSORES DE HARDWARE', theme),
                                    ..._buildPhysicalSensorsList(theme, isDark),
                                  ],
                                ),
                        ),
                        
                        Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PORTAL OS v1.0.3',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary.withOpacity(0.4),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'HARDWARE ACTIVE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        endDrawer: Drawer(
          width: 280,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(32)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA)).withOpacity(0.7),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(32)),
                  border: Border(
                    left: BorderSide(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                      width: 1.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.menu_open_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Lateral Bar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
                        const SizedBox(height: 16),
                        _buildSidebarItem(
                          context,
                          icon: Icons.notifications_active_rounded,
                          label: 'Notificações',
                          subtitle: 'Alertas e mensagens recentes',
                        ),
                        const SizedBox(height: 16),
                        _buildSidebarItem(
                          context,
                          icon: Icons.speed_rounded,
                          label: 'Status do Sistema',
                          subtitle: 'Desempenho, CPU e memória',
                        ),
                        const Spacer(),
                        Text(
                          'PORTAL OS v1.0.3',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Page Content (extends all the way down)
            Positioned.fill(
              child: Column(
                children: [
                  // Stack to overlay the centered page title on the same line as ContextHeader
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 8.0),
                        child: ContextHeader(),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: ContextHeader.isPanelOpenNotifier,
                        builder: (context, isPanelOpen, child) {
                          return AnimatedOpacity(
                            opacity: isPanelOpen ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4.0), // Center align vertically with the sun/moon button
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentPageIndex == 0) {
                                    VirtualTopography.toggleRotationTrigger.value = 
                                        !VirtualTopography.toggleRotationTrigger.value;
                                  }
                                },
                                child: Text(
                                  _currentPageIndex == 0
                                      ? 'Home'
                                      : _currentPageIndex == 1
                                          ? 'Memória'
                                          : 'Aplicativos',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark ? const Color(0xFFFAFAFA) : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Filter bar (shown only on Home when panel closed)
                  if (_currentPageIndex == 0)
                    ValueListenableBuilder<bool>(
                      valueListenable: ContextHeader.isPanelOpenNotifier,
                      builder: (context, isPanelOpen, child) {
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: isPanelOpen
                              ? const SizedBox.shrink()
                              : _buildEarthFilterBar(theme, isDark),
                        );
                      },
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
                          color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
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
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 142.0),
                          child: VirtualTopography(),
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
                      color: (isDark ? Colors.black : Colors.white).withOpacity(0.55),
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Navigation Button Bar (Same size/style as explore bar)
                        Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.18),
                            ),
                          ),
                          child: Builder(
                            builder: (context) {
                              final Color inactiveColor = isDark
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.4);

                              return Row(
                                children: [
                                  // Left Tab (Home)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(0),
                                      child: Container(
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 0
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(23)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.public_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 0
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Home',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 0
                                                    ? theme.colorScheme.primary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // First Divider
                                  Container(
                                    width: 1,
                                    height: 18,
                                    color: theme.colorScheme.primary.withOpacity(0.18),
                                  ),
                                  // Middle Tab 1 (Memória)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(1),
                                      child: Container(
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 1
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.sd_storage_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 1
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Memória',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 1
                                                    ? theme.colorScheme.primary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Second Divider
                                  Container(
                                    width: 1,
                                    height: 18,
                                    color: theme.colorScheme.primary.withOpacity(0.18),
                                  ),
                                  // Middle Tab 2 (Aplicativos)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(2),
                                      child: Container(
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 2
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.apps_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 2
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Apps',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 2
                                                    ? theme.colorScheme.primary
                                                    : inactiveColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Third Divider
                                  Container(
                                    width: 1,
                                    height: 18,
                                    color: theme.colorScheme.primary.withOpacity(0.18),
                                  ),
                                  // Right Tab (Correio)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _navigateToPage(3),
                                      child: Container(
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _currentPageIndex == 3
                                              ? theme.colorScheme.primary.withOpacity(0.12)
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(23)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.mail_rounded,
                                              size: 16,
                                              color: _currentPageIndex == 3
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Correio',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _currentPageIndex == 3
                                                    ? theme.colorScheme.primary
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
                        const SizedBox(height: 12),

                        // 2. Fixed Bottom Explore Bar (Absolute lowest item)
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textAlign: TextAlign.right, // RTL alignment for thumb
                          onChanged: (text) {
                            if (_currentPageIndex == 0) {
                              VirtualTopography.mapSearchQueryNotifier.value = text;
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
                            hintText: _currentPageIndex == 0
                                ? 'Explorar...'
                                : _currentPageIndex == 1
                                    ? 'Buscar arquivo...'
                                    : 'Explorar app...',
                            hintStyle: TextStyle(
                              color: isDark ? const Color(0xFFECEFF1).withOpacity(0.4) : Colors.black.withOpacity(0.35),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                final query = _searchController.text.trim();
                                if (_currentPageIndex == 0 && query.isNotEmpty) {
                                  _searchFocusNode.unfocus();
                                  VirtualTopography.directSearchTrigger.value = query;
                                } else {
                                  _openSearchOverlay();
                                }
                              },
                              child: Icon(
                                Icons.search_rounded,
                                color: theme.colorScheme.primary.withOpacity(0.7),
                              ),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(0.18),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(0.3),
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

            // App search results panel — floats above bottom nav bar when explore bar has results
            if (_overlayFilteredApps.isNotEmpty)
              Positioned(
                bottom: 148, // sits just above the nav bar height
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Row(
                              children: [
                                Icon(Icons.apps_rounded, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Apps encontrados',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _closeSearchOverlay,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              itemCount: _overlayFilteredApps.length,
                              itemBuilder: (context, index) {
                                final app = _overlayFilteredApps[index];
                                return GestureDetector(
                                  onTap: () {
                                    AppsService.launchApp(app.packageName, app.className);
                                    _closeSearchOverlay();
                                  },
                                  child: Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        FutureBuilder<Uint8List?>(
                                          future: AppsService.getAppIcon(app.packageName),
                                          builder: (context, snap) {
                                            if (snap.hasData && snap.data != null) {
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(snap.data!, width: 40, height: 40, fit: BoxFit.cover),
                                              );
                                            }
                                            return Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                app.label.isNotEmpty ? app.label[0].toUpperCase() : '?',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          app.label,
                                          style: TextStyle(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.8)),
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
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
      ),
  );
}

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
              color: theme.colorScheme.primary.withOpacity(0.08),
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
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
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
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25),
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
                              color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
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
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
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
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.07),
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
                                        color: theme.colorScheme.primary.withOpacity(0.15),
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
                                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.75),
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


  Widget _buildEarthFilterBar(ThemeData theme, bool isDark) {

    final filters = ['Todos', 'Satélite', 'Clima', 'Wikipédia', 'Vetor (3D)'];
    return ValueListenableBuilder<String>(
      valueListenable: VirtualTopography.earthFilterNotifier,
      builder: (context, currentFilter, child) {
        return Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filterName = filters[index];
              final isSelected = currentFilter == filterName;
              return ChoiceChip(
                label: Text(
                  filterName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    VirtualTopography.earthFilterNotifier.value = filterName;
                  }
                },
                selectedColor: theme.colorScheme.primary,
                backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isSelected 
                        ? theme.colorScheme.primary 
                        : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                showCheckmark: false,
              );
            },
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
          color: theme.colorScheme.primary.withOpacity(0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildWifiTile(ThemeData theme, bool isDark) {
    final wifi = _hardwareInfo['wifi'] as Map? ?? {};
    final bool enabled = wifi['enabled'] == true;
    final String ssid = wifi['ssid'] ?? 'Desconectado';
    final int speed = wifi['speed'] ?? 0;
    final int rssi = wifi['rssi'] ?? 0;

    String subtitle = 'Inativo';
    if (enabled) {
      if (ssid != 'Desconectado' && ssid.isNotEmpty) {
        subtitle = '$ssid • ${speed > 0 ? "$speed Mbps" : ""} • ${rssi}dBm';
      } else {
        subtitle = 'Ativo (Sem conexão)';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, size: 20, color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wi-Fi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              enabled ? 'ATIVO' : 'DESATIVADO',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(String title, Map<dynamic, dynamic> data, IconData icon, ThemeData theme, bool isDark) {
    final bool available = data['available'] != false;
    final bool enabled = data['enabled'] == true;
    final String state = data['state'] ?? 'INATIVO';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  available ? (enabled ? 'Ativo e pronto' : 'Disponível, inativo') : 'Não integrado ao hardware',
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPhysicalSensorsList(ThemeData theme, bool isDark) {
    final rawSensors = _hardwareInfo['sensors'] as List?;
    if (rawSensors == null || rawSensors.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Nenhum sensor de hardware detectado',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            ),
          ),
        )
      ];
    }

    final categories = <String, List<dynamic>>{
      'Movimento & Orientação': [],
      'Ambiente & Clima': [],
      'Posição & Proximidade': [],
      'Sensores Auxiliares': [],
    };

    for (var sensor in rawSensors) {
      final String type = (sensor['type'] as String? ?? '').toLowerCase();
      if (type.contains('accel') || type.contains('gyro') || type.contains('gravity') ||
          type.contains('linear') || type.contains('rotat') || type.contains('step') ||
          type.contains('orient') || type.contains('motion')) {
        categories['Movimento & Orientação']!.add(sensor);
      } else if (type.contains('light') || type.contains('temp') || type.contains('pressure') ||
                 type.contains('humid') || type.contains('barom')) {
        categories['Ambiente & Clima']!.add(sensor);
      } else if (type.contains('proxim') || type.contains('magn') || type.contains('compass')) {
        categories['Posição & Proximidade']!.add(sensor);
      } else {
        categories['Sensores Auxiliares']!.add(sensor);
      }
    }

    final List<Widget> listItems = [];

    categories.forEach((categoryName, sensorsList) {
      if (sensorsList.isNotEmpty) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 6.0, left: 4.0),
            child: Row(
              children: [
                Icon(
                  categoryName == 'Movimento & Orientação'
                      ? Icons.screen_rotation_rounded
                      : categoryName == 'Ambiente & Clima'
                          ? Icons.thermostat_rounded
                          : categoryName == 'Posição & Proximidade'
                              ? Icons.explore_rounded
                              : Icons.tune_rounded,
                  size: 11,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  categoryName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.secondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );

        listItems.addAll(sensorsList.map((sensor) {
          final String name = sensor['name'] ?? 'Sensor';
          final String vendor = sensor['vendor'] ?? 'Desconhecido';
          final double power = (sensor['power'] as num?)?.toDouble() ?? 0.0;
          final String type = (sensor['type'] as String? ?? 'Desconhecido').split('.').last.toUpperCase();

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.sensors_rounded, size: 14, color: theme.colorScheme.primary.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withOpacity(0.85)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fabricante: $vendor • Consumo: ${power.toStringAsFixed(2)}mA',
                        style: TextStyle(fontSize: 8.5, color: theme.colorScheme.onSurface.withOpacity(0.45)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          );
        }).toList());
      }
    });

    return listItems;
  }
}
