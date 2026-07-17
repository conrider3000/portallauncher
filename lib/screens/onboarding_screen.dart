import 'package:flutter/material.dart';
import '../services/launcher_service.dart';
import '../theme/tropical_theme.dart';
import '../utils/platform_helper.dart';

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
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'PORTAL',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Eficiência sem distrações.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const Spacer(),

                  // Super minimalist outline Portal symbol
                  _buildMinimalistPortal(theme, isDark),

                  const Spacer(),

                  // Terms & LGPD Section with Policy Link
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1E15) : const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
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
                                  'Aceito os termos da LGPD e autorizo o processamento local de dados do dispositivo.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showPrivacyPolicySheet,
                          child: Text(
                            'Ver Termos e Privacidade',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step-by-step tutorial card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0A140E) : const Color(0xFFEFF5F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Como definir como launcher padrão:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. Toque no botão principal abaixo para abrir as opções.\n'
                          '2. Escolha o "Portal" como seu app de início padrão nas configurações do sistema.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Setup button
                  ElevatedButton(
                    onPressed: _triggerSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Definir como Padrão',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_isChecking) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bypass button
                  TextButton(
                    onPressed: () {
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
                    child: Text(
                      'Entrar no Portal (Definir depois)',
                      style: TextStyle(
                        color: theme.colorScheme.primary.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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

  Widget _buildMinimalistPortal(ThemeData theme, bool isDark) {
    return Container(
      width: 150,
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Container(
        width: 90,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.12),
            width: 1.0,
          ),
        ),
        child: Icon(
          Icons.blur_on_rounded,
          size: 32,
          color: theme.colorScheme.primary.withOpacity(0.8),
        ),
      ),
    );
  }
}
