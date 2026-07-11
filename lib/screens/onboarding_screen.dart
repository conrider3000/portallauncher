import 'dart:math' as math;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _portalRotationController;
  late AnimationController _transitionController;
  late Animation<double> _portalScaleAnimation;

  bool _isChecking = false;
  bool _lgpdAccepted = false;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Continuous rotation of the portal
    _portalRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Zoom-in transition animation when role is granted
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _portalScaleAnimation = Tween<double>(begin: 1.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInCirc,
      ),
    );

    _checkDefaultLauncher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _portalRotationController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDefaultLauncher();
    }
  }

  Future<void> _checkDefaultLauncher() async {
    if (_isChecking || _isTransitioning) return;
    setState(() => _isChecking = true);

    final isDefault = await LauncherService.isDefaultHome();
    if (isDefault) {
      // Trigger portal entry zoom animation
      _enterWorkspace();
    } else {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _enterWorkspace() {
    setState(() {
      _isTransitioning = true;
    });
    _transitionController.forward().then((_) {
      widget.onSetupComplete();
    });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // Background layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
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

                  // Multi-art rotating Portal widget
                  AnimatedBuilder(
                    animation: _portalScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _portalScaleAnimation.value,
                        child: _buildRotatingPortal(isDark),
                      );
                    },
                  ),

                  const Spacer(),

                  // Terms & LGPD section
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
                              child: Text(
                                'Aceito os termos da LGPD e autorizo o processamento local de dados do dispositivo.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Para acessar seu celular eficientemente e sem anúncios, este launcher precisa ser definido como o App de início principal nas configurações.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                          '2. Se o sistema não perguntar, configure manualmente em:\n'
                          '   Configurações ➔ Aplicativos ➔ Escolher aplicativos padrão ➔ Aplicativo de início ➔ Selecione "Portal".',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Accept and Setup Button
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

                  // Secondary bypass button
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
                      _enterWorkspace();
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

          // Bypass onboarding debug button (on Top Right)
          if (!isAndroidNative)
            Positioned(
              top: 40,
              right: 16,
              child: TextButton.icon(
                onPressed: _enterWorkspace,
                icon: const Icon(Icons.skip_next_rounded),
                label: const Text('Bypass (Dev)'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRotatingPortal(bool isDark) {
    // A layered gradient portal where layers rotate in opposite directions
    return Container(
      width: 180,
      height: 180,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Layer 1: Clockwise Outer Portal
          AnimatedBuilder(
            animation: _portalRotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _portalRotationController.value * 2 * math.pi,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        const Color(0xFF007AFF).withOpacity(0.8), // Apple Blue
                        const Color(0xFFAF52DE).withOpacity(0.8), // Siri Purple
                        const Color(0xFF30B0C7).withOpacity(0.8), // Apple Teal
                        const Color(0xFF007AFF).withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Layer 2: Counter-Clockwise Inner Portal
          AnimatedBuilder(
            animation: _portalRotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -_portalRotationController.value * 4 * math.pi,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        const Color(0xFF34C759).withOpacity(0.7), // Apple Emerald
                        const Color(0xFF007AFF).withOpacity(0.4),
                        const Color(0xFFAF52DE).withOpacity(0.7), // Siri Purple
                        const Color(0xFF34C759).withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Layer 3: Central core
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFF007AFF) : Colors.black).withOpacity(0.12),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.blur_circular_rounded,
              size: 40,
              color: Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }
}
