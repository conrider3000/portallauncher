import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../services/apps_service.dart';
import '../../../services/launcher_service.dart';
import '../controllers/wikipedia_controller.dart';
import '../../../core/theme/portal_design_system.dart';

class WikipediaSearchOverlay extends StatelessWidget {
  final WikipediaController controller;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<AppInfo> overlayFilteredApps;
  final VoidCallback onClearSearch;
  final VoidCallback onAppTap;
  final bool isDark;
  final ThemeData theme;

  const WikipediaSearchOverlay({
    super.key,
    required this.controller,
    required this.searchController,
    required this.searchFocusNode,
    required this.overlayFilteredApps,
    required this.onClearSearch,
    required this.onAppTap,
    required this.isDark,
    required this.theme,
  });

  Widget _buildExploreActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                      ),
                    ),
                  ],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final mode = controller.overlayMode;
        final selectedWiki = controller.selectedWikiArticle;
        final wikiList = controller.wikiTermsList;
        final isLoading = controller.isLoading;
        
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  // constraints removed, relies on parent Positioned bounds
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: PortalDesignSystem.getOverlayBlurBackground(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: mode == 2 ? MainAxisSize.max : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with Back / Title / Close
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(
                          children: [
                            if (mode > 0)
                              GestureDetector(
                                onTap: () {
                                  if (mode == 2) {
                                    controller.setMode(1);
                                  } else {
                                    controller.setMode(0);
                                  }
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
                                mode == 0
                                    ? 'Explorar "${searchController.text.trim()}"'
                                    : (mode == 1
                                        ? 'Escolha de Termos: "${searchController.text.trim()}"'
                                        : (selectedWiki?['title'] ?? 'Artigo Wikipédia')),
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
                              onTap: onClearSearch,
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
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      // ── MODE 0: MAIN EXPLORE OPTIONS MENU ──
                      if (mode == 0) ...[
                        if (overlayFilteredApps.isNotEmpty) ...[
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
                              itemCount: overlayFilteredApps.length,
                              itemBuilder: (context, index) {
                                final app = overlayFilteredApps[index];
                                return GestureDetector(
                                  onTap: () {
                                    AppsService.launchApp(app.packageName, app.className);
                                    onAppTap();
                                  },
                                  child: Container(
                                    width: 54,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        FutureBuilder<List<int>?>(
                                          future: AppsService.getAppIcon(app.packageName),
                                          builder: (context, snap) {
                                            if (snap.hasData && snap.data != null) {
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: Image.memory(
                                                  Uint8List.fromList(snap.data!), 
                                                  width: 34, height: 34, fit: BoxFit.cover
                                                ),
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
                            final query = searchController.text.trim();
                            searchFocusNode.unfocus();
                            controller.fetchCandidateTerms(query);
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
                            final query = searchController.text.trim();
                            searchFocusNode.unfocus();
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
                            final query = searchController.text.trim();
                            searchFocusNode.unfocus();
                            LauncherService.openUrl("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}");
                          },
                        ),
                        const SizedBox(height: 6),
                      ]
                      // ── MODE 1: CANDIDATE WIKIPEDIA TERMS LIST ──
                      else if (mode == 1) ...[
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(28.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (wikiList.isEmpty)
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
                              itemCount: wikiList.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: theme.colorScheme.primary.withValues(alpha: 0.08)),
                              itemBuilder: (context, index) {
                                final term = wikiList[index];
                                final title = term['title'] ?? '';
                                final snippet = term['snippet'] ?? '';
                                final ts = term['timestamp'] ?? '';

                                return InkWell(
                                  onTap: () => controller.fetchArticleFull(title),
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
                      else if (mode == 2) ...[
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(36.0),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (selectedWiki != null) ...[
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
                                  '📅 Atualização: ${selectedWiki['updated']}',
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
                                    selectedWiki['title']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: theme.colorScheme.primary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedWiki['extract']!,
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
    });
  }
}
