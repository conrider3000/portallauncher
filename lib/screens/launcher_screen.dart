import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/launcher_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/context_header.dart';
import '../widgets/virtual_topography.dart';
import '../widgets/apps_list_view.dart';
import '../widgets/memory_explorer_view.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  double _lastPointerDownX = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultStatus();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
    AppsListView.searchQueryNotifier.value = ''; // Reset app filter
    VirtualTopography.mapSearchQueryNotifier.value = ''; // Reset map filter
    MemoryExplorerView.fileSearchQueryNotifier.value = ''; // Reset file filter
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
          width: 280,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA)).withOpacity(0.7),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(32)),
                  border: Border(
                    right: BorderSide(
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
                              Icons.dashboard_customize_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Colateral Bar',
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
                          icon: Icons.widgets_rounded,
                          label: 'Adicionar Widgets',
                          subtitle: 'Personalize sua tela de início',
                        ),
                        const SizedBox(height: 16),
                        _buildSidebarItem(
                          context,
                          icon: Icons.settings_suggest_rounded,
                          label: 'Configurações do Portal',
                          subtitle: 'Temas, layouts e transições',
                        ),
                        const SizedBox(height: 16),
                        _buildSidebarItem(
                          context,
                          icon: Icons.info_outline_rounded,
                          label: 'Sobre o Sistema',
                          subtitle: 'Licença e créditos de código',
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
                              child: Text(
                                _currentPageIndex == 0
                                    ? 'Home'
                                    : _currentPageIndex == 1
                                        ? 'Memória'
                                        : 'Apps',
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
                    ],
                  ),

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
                                              size: 18,
                                              color: _currentPageIndex == 0
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Home',
                                              style: TextStyle(
                                                fontSize: 12,
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
                                    height: 20,
                                    color: theme.colorScheme.primary.withOpacity(0.18),
                                  ),
                                  // Middle Tab (Memória)
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
                                              size: 18,
                                              color: _currentPageIndex == 1
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Memória',
                                              style: TextStyle(
                                                fontSize: 12,
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
                                    height: 20,
                                    color: theme.colorScheme.primary.withOpacity(0.18),
                                  ),
                                  // Right Tab (Apps)
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
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(23)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.apps_rounded,
                                              size: 18,
                                              color: _currentPageIndex == 2
                                                  ? theme.colorScheme.primary
                                                  : inactiveColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Apps',
                                              style: TextStyle(
                                                fontSize: 12,
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
                          decoration: InputDecoration(
                            hintText: _currentPageIndex == 0
                                ? 'Explorar...'
                                : _currentPageIndex == 1
                                    ? 'Buscar arquivo...'
                                    : 'Explorar app...',
                            hintStyle: TextStyle(
                              color: isDark ? const Color(0xFFECEFF1).withOpacity(0.4) : Colors.black.withOpacity(0.35),
                            ),
                            suffixIcon: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.primary.withOpacity(0.7),
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

  Widget _buildEarthFilterBar(ThemeData theme, bool isDark) {
    final filters = ['Todos', 'Clima (IR)', 'Wikipédia', 'Vetor (3D)'];
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
}
