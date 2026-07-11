import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/apps_service.dart';

class AppsListView extends StatefulWidget {
  const AppsListView({super.key});

  // Global search notifier to communicate between the bottom search bar and the apps list
  static final ValueNotifier<String> searchQueryNotifier = ValueNotifier('');

  @override
  State<AppsListView> createState() => _AppsListViewState();
}

class _AppsListViewState extends State<AppsListView> {
  List<AppInfo> _allApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  String _activeLetter = '';
  final Map<String, Uint8List?> _loadedIcons = {};

  final ScrollController _scrollController = ScrollController();

  static const double _itemHeight = 66.0; // 54.0 height + 12.0 padding

  final List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
    AppsListView.searchQueryNotifier.addListener(_onSearchNotifierChanged);
  }

  @override
  void dispose() {
    AppsListView.searchQueryNotifier.removeListener(_onSearchNotifierChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchNotifierChanged() {
    _onSearch(AppsListView.searchQueryNotifier.value);
  }

  Future<void> _loadApps() async {
    final apps = await AppsService.getInstalledApps();
    if (mounted) {
      // Pre-load all icons concurrently to guarantee they are fully cached before list shows
      await Future.wait(apps.map((app) async {
        final iconBytes = await AppsService.getAppIcon(app.packageName);
        if (mounted) {
          _loadedIcons[app.packageName] = iconBytes;
        }
      }));

      if (mounted) {
        setState(() {
          _allApps = apps;
          _filteredApps = apps;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    final lowercaseQuery = query.toLowerCase().trim();
    setState(() {
      _filteredApps = _allApps.where((app) {
        final label = app.label.toLowerCase();
        final packageName = app.packageName.toLowerCase();
        final className = app.className.toLowerCase();
        return label.contains(lowercaseQuery) ||
            packageName.contains(lowercaseQuery) ||
            className.contains(lowercaseQuery);
      }).toList();
    });
  }

  void _scrollToLetter(String letter) {
    int targetIndex = -1;
    if (letter == '#') {
      targetIndex = _filteredApps.indexWhere((app) {
        if (app.label.isEmpty) return true;
        final firstChar = app.label[0].toUpperCase();
        return !_alphabet.contains(firstChar);
      });
    } else {
      targetIndex = _filteredApps.indexWhere((app) {
        return app.label.isNotEmpty && app.label[0].toUpperCase() == letter;
      });
    }

    if (targetIndex != -1) {
      _scrollController.animateTo(
        targetIndex * _itemHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleAlphabetDrag(double localY, double containerHeight) {
    if (_filteredApps.isEmpty) return;

    final double letterHeight = containerHeight / _alphabet.length;
    int index = (localY / letterHeight).floor();
    index = index.clamp(0, _alphabet.length - 1);

    final letter = _alphabet[index];
    if (_activeLetter != letter) {
      setState(() {
        _activeLetter = letter;
      });
      _scrollToLetter(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Scrollable List of Glassmorphic Buttons
        Padding(
          padding: const EdgeInsets.only(right: 46.0), // Leave space for A-Z sidebar
          child: _filteredApps.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum app encontrado',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredApps.length,
                  itemExtent: _itemHeight,
                  padding: const EdgeInsets.only(top: 12.0, bottom: 160.0),
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    return _buildGlassmorphicItem(app, isDark, theme);
                  },
                ),
        ),

        // A-Z Sidebar Overlay (Right side aligned to thumb sweep)
        Positioned(
          right: 8,
          top: 16,
          bottom: 16,
          width: 30,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onVerticalDragStart: (details) {
                  _handleAlphabetDrag(details.localPosition.dy, constraints.maxHeight);
                },
                onVerticalDragUpdate: (details) {
                  _handleAlphabetDrag(details.localPosition.dy, constraints.maxHeight);
                },
                onVerticalDragEnd: (_) {
                  setState(() {
                    _activeLetter = '';
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _alphabet.map((letter) {
                      final isCurrent = _activeLetter == letter;
                      return Expanded(
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: isCurrent ? 14 : 9,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),

        // A-Z Letter Indicator Popup in the center
        if (_activeLetter.isNotEmpty)
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _activeLetter,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassmorphicItem(AppInfo app, bool isDark, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Container(
        height: 54.0,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => AppsService.launchApp(app.packageName, app.className),
              splashColor: theme.colorScheme.primary.withOpacity(0.08),
              highlightColor: theme.colorScheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Align contents to the right
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Name (aligned to the right, next to the icon)
                    Expanded(
                      child: Text(
                        app.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.25,
                          color: theme.colorScheme.onSurface.withOpacity(0.85),
                        ),
                        textAlign: TextAlign.right, // Text right-alignment
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // App Icon (on the far right, closest to the thumb)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: _loadedIcons[app.packageName] != null
                          ? Image.memory(
                              _loadedIcons[app.packageName]!,
                              filterQuality: FilterQuality.medium,
                            )
                          : Icon(
                              Icons.android_rounded,
                              size: 20,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
