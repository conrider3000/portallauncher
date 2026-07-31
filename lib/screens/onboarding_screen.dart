import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/launcher_service.dart';
import '../theme/tropical_theme.dart';
import '../utils/platform_helper.dart';
import '../widgets/context_header.dart';
import '../widgets/virtual_topography.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onSetupComplete;

  const OnboardingScreen({super.key, required this.onSetupComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _lgpdAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDefaultLauncher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultLauncher();
    }
  }

  Future<void> _checkDefaultLauncher() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final isDefault = await LauncherService.isDefaultHome();
    if (isDefault) {
      widget.onSetupComplete();
    } else {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _triggerSetup() async {
    if (!_lgpdAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, aceite os termos da LGPD para entrar no Portal.'),
          backgroundColor: TropicalTheme.warmTerracotta,
        ),
      );
      return;
    }
    await LauncherService.requestDefaultHome();
  }

  void _showPrivacyPolicySheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Termos e Privacidade da LGPD',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '1. Armazenamento Local de Dados:\n'
                    'Todos os dados coletados pelo Portal Launcher, incluindo histórico de buscas, uso de aplicativos recentes, telemetria básica do sistema e posições de geolocalização no globo virtual 3D, são salvos de forma estritamente local nas preferências do aplicativo no seu dispositivo (SharedPreferences/SQLite).\n\n'
                    '2. Ausência de Envio em Nuvem:\n'
                    'Este aplicativo não possui banco de dados em nuvem próprio nem compartilha qualquer data pessoal identificável com terceiros ou com a equipe de desenvolvimento. Cumprimos rigorosamente a LGPD (Lei Geral de Proteção de Dados).\n\n'
                    '3. Permissões de Localização e Arquivos:\n'
                    'As permissões de Localização (GPS) servem apenas para plotar sua posição no globo 3D e atualizar as condições climáticas de Curitiba ou da sua região atual. A permissão de armazenamento/arquivos é opcional e serve exclusivamente para gerenciar as mídias da aba "Memória".\n\n'
                    '4. Consentimento e Revogação:\n'
                    'Ao prosseguir, você concorda com o processamento local desses dados. É possível revogar as permissões nas configurações do Android a qualquer momento.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Entendi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // 1. Full 3D Interactive Virtual Topography Globe (Real Earth with Satellite + Clouds)
          const Positioned.fill(
            child: VirtualTopography(),
          ),

          // 2. Interactive Time-Space Header at Top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
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
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0, bottom: 8.0),
                            child: ContextHeader(),
                          ),
                          ValueListenableBuilder<HeaderMode>(
                            valueListenable: ContextHeader.isPanelOpenNotifier,
                            builder: (context, headerMode, child) {
                              return AnimatedOpacity(
                                opacity: (headerMode == HeaderMode.filter) ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'PORTAL',
                                    style: theme.textTheme.headlineLarge?.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Onboarding Glass Dock Overlay (in place of Search bar and Tab bar at bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Terms & LGPD Section
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F1E15).withValues(alpha: 0.8) : const Color(0xFFF4F7F5).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _lgpdAccepted,
                                    onChanged: (val) {
                                      setState(() {
                                        _lgpdAccepted = val ?? false;
                                      });
                                    },
                                    activeColor: theme.colorScheme.primary,
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _lgpdAccepted = !_lgpdAccepted;
                                        });
                                      },
                                      child: Text(
                                        'Aceito os termos da LGPD e o processamento local.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showPrivacyPolicySheet,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Text(
                                        'Ver Termos',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons Row (Entrar no Portal + Definir como Padrão)
                        Row(
                          children: [
                            Expanded(
                              child: _buildHiggsButton(
                                text: 'Entrar no Portal',
                                onTap: () {
                                  if (!_lgpdAccepted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Por favor, aceite os termos da LGPD primeiro.'),
                                        backgroundColor: TropicalTheme.warmTerracotta,
                                      ),
                                    );
                                    return;
                                  }
                                  widget.onSetupComplete();
                                },
                                theme: theme,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildHiggsButton(
                                text: 'Definir Padrão',
                                onTap: _triggerSetup,
                                theme: theme,
                                isDark: isDark,
                                isLoading: _isChecking,
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

          // Bypass debug button on desktop
          if (!isAndroidNative)
            Positioned(
              top: 40,
              right: 16,
              child: TextButton.icon(
                onPressed: widget.onSetupComplete,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Bypass (Dev)'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHiggsButton({
    required String text,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    bool isLoading = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF070D09) : const Color(0xFFF4F7F5)).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
}
