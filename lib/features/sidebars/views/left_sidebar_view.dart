import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../services/launcher_service.dart';
import '../controllers/sidebar_controller.dart';
import '../../../core/theme/portal_design_system.dart';

class LeftSidebarView extends StatefulWidget {
  final SidebarController controller;
  
  const LeftSidebarView({super.key, required this.controller});

  @override
  State<LeftSidebarView> createState() => _LeftSidebarViewState();
}

class _LeftSidebarViewState extends State<LeftSidebarView> with WidgetsBindingObserver {
  bool _isOfflineMode = false;
  bool _flashlightEnabled = false;
  bool _autoRotationEnabled = false;
  bool _fmRadioSimEnabled = false;
  Map<String, dynamic> _hardwareInfo = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHardwareInfo();
    _loadInitialStates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHardwareInfo();
      _loadInitialStates();
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

  Widget _buildSectionTitle(String title, ThemeData theme, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.55)),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary.withValues(alpha: 0.55),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
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
        widget.controller.updateLeftBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
      },
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

  Widget _buildMiniLeftBarContent(ThemeData theme, bool isDark) {
    final wifiEnabled = _hardwareInfo['wifi']?['enabled'] == true;
    final bluetoothEnabled = _hardwareInfo['bluetooth']?['enabled'] == true;
    final locationEnabled = _hardwareInfo['location']?['enabled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onDoubleTap: () {
                widget.controller.updateLeftBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
              },
              onTap: () {
                widget.controller.updateLeftBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
              },
              child: Icon(
                Icons.keyboard_arrow_right_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  // CONEXÕES separator
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                    child: Icon(Icons.sensors_rounded, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  _buildMiniSensorToggle(
                    icon: Icons.signal_cellular_alt_rounded,
                    enabled: true,
                    tooltip: 'Rede Celular',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.toggleCellular(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: wifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    enabled: wifiEnabled,
                    tooltip: 'Wi-Fi: ${wifiEnabled ? "ON" : "OFF"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      await LauncherService.toggleWifi(!wifiEnabled);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: bluetoothEnabled ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                    enabled: bluetoothEnabled,
                    tooltip: 'Bluetooth: ${bluetoothEnabled ? "ON" : "OFF"}',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      await LauncherService.toggleBluetooth(!bluetoothEnabled);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: Icons.nfc_rounded,
                    enabled: true,
                    tooltip: 'NFC',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openNfcSettings(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _isOfflineMode ? Icons.airplanemode_active_rounded : Icons.airplanemode_inactive_rounded,
                    enabled: _isOfflineMode,
                    tooltip: 'Modo Offline',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      await LauncherService.openAirplaneModeSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // SENSORES separator
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                    child: Icon(Icons.track_changes_rounded, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  _buildMiniSensorToggle(
                    icon: locationEnabled ? Icons.location_on_rounded : Icons.location_off_rounded,
                    enabled: locationEnabled,
                    tooltip: 'Localização',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openLocationSettings(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _autoRotationEnabled ? Icons.screen_rotation_rounded : Icons.screen_lock_rotation_rounded,
                    enabled: _autoRotationEnabled,
                    tooltip: 'Giro da Tela',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      final newMode = !_autoRotationEnabled;
                      if (await LauncherService.setAutoRotationEnabled(newMode)) {
                        setState(() => _autoRotationEnabled = newMode);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // FERRAMENTAS separator
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                    child: Icon(Icons.handyman_rounded, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  ),
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
                    icon: Icons.access_time_filled_rounded,
                    enabled: true,
                    tooltip: 'Alarme / Relógio',
                    theme: theme,
                    isDark: isDark,
                    onTap: () => LauncherService.openClockApp(),
                  ),
                  const SizedBox(height: 12),
                  _buildMiniSensorToggle(
                    icon: _flashlightEnabled ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                    enabled: _flashlightEnabled,
                    tooltip: 'Lanterna',
                    theme: theme,
                    isDark: isDark,
                    onTap: () async {
                      final newSt = !_flashlightEnabled;
                      await LauncherService.toggleFlashlight(newSt);
                      setState(() => _flashlightEnabled = newSt);
                    },
                  ),
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
              widget.controller.updateLeftBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullLeftBarContent(ThemeData theme, bool isDark) {
    final wifi = _hardwareInfo['wifi'] as Map? ?? {};
    final bool wifiEnabled = wifi['enabled'] == true;
    final String wifiSsid = wifi['ssid'] ?? '';
    final int wifiSpeed = wifi['speed'] ?? 0;

    final bluetooth = _hardwareInfo['bluetooth'] as Map? ?? {};
    final bool btEnabled = bluetooth['enabled'] == true;
    
    final location = _hardwareInfo['location'] as Map? ?? {};
    final bool locationEnabled = location['enabled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                if (widget.controller.leftBarWidth.value > PortalDesignSystem.miniBarWidth) {
                  widget.controller.updateLeftBarWidth(PortalDesignSystem.miniBarWidth, PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
                }
              },
              onDoubleTap: () {
                if (widget.controller.leftBarWidth.value > PortalDesignSystem.miniBarWidth) {
                  widget.controller.updateLeftBarWidth(PortalDesignSystem.miniBarWidth, PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
                }
              },
              child: Icon(
                Icons.keyboard_arrow_left_rounded,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildSectionTitle('CONEXÕES', theme, Icons.sensors_rounded),
                
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

                _buildToolButtonTile(
                  title: 'Internet (Wi-Fi)',
                  subtitle: wifiEnabled
                      ? (wifiSsid.isNotEmpty && wifiSsid != 'Desconectado'
                          ? '$wifiSsid ${wifiSpeed > 0 ? "• $wifiSpeed Mbps" : ""}'
                          : 'Conectado')
                      : 'Wi-Fi desativado',
                  icon: wifiEnabled ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  active: wifiEnabled,
                  badgeText: wifiEnabled ? 'ON' : 'OFF',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.toggleWifi(!wifiEnabled),
                ),

                _buildToolButtonTile(
                  title: 'Bluetooth',
                  subtitle: btEnabled ? 'Dispositivo visível e pronto' : 'Bluetooth desativado',
                  icon: btEnabled ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                  active: btEnabled,
                  badgeText: btEnabled ? 'ON' : 'OFF',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.toggleBluetooth(!btEnabled),
                ),

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
                
                _buildToolButtonTile(
                  title: _isOfflineMode ? 'Modo Offline (Avião)' : 'Modo Offline (Avião)',
                  subtitle: _isOfflineMode ? 'Isolamento de rádio ativo' : 'Desativado',
                  icon: _isOfflineMode ? Icons.airplanemode_active_rounded : Icons.airplanemode_inactive_rounded,
                  active: _isOfflineMode,
                  activeColor: const Color(0xFFFF3B30),
                  badgeText: _isOfflineMode ? 'OFFLINE' : 'ONLINE',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openAirplaneModeSettings(),
                ),

                const SizedBox(height: 12),
                
                _buildSectionTitle('SENSORES', theme, Icons.track_changes_rounded),
                
                _buildToolButtonTile(
                  title: 'Localização (GPS)',
                  subtitle: locationEnabled ? 'Serviços de localização ativos' : 'Localização desativada',
                  icon: locationEnabled ? Icons.location_on_rounded : Icons.location_off_rounded,
                  active: locationEnabled,
                  badgeText: locationEnabled ? 'ON' : 'OFF',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openLocationSettings(),
                ),

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
                    if (await LauncherService.setAutoRotationEnabled(newMode)) {
                      setState(() => _autoRotationEnabled = newMode);
                    }
                  },
                ),

                const SizedBox(height: 12),
                
                _buildSectionTitle('FERRAMENTAS', theme, Icons.handyman_rounded),
                
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
                
                _buildToolButtonTile(
                  title: 'Alarme / Relógio',
                  subtitle: 'Gerenciar horários',
                  icon: Icons.access_time_filled_rounded,
                  active: true,
                  badgeText: 'ABRIR',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openClockApp(),
                ),

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
                    setState(() => _flashlightEnabled = newSt);
                  },
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBarWidth = PortalDesignSystem.maxBarWidth(screenWidth);

    return ValueListenableBuilder<double>(
      valueListenable: widget.controller.leftBarWidth,
      builder: (context, currentWidth, child) {
        return Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: currentWidth > 0 ? screenWidth : 60.0,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              widget.controller.startLeftDrag(currentWidth);
            },
            onHorizontalDragUpdate: (details) {
            widget.controller.updateLeftBarWidth(currentWidth + details.delta.dx, maxBarWidth);
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
            widget.controller.handleLeftDragEnd(velocity, maxBarWidth);
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
                left: 0,
                width: currentWidth > 0 ? currentWidth : 0.0,
                child: GestureDetector(
                  onTap: () {}, // Consume taps inside the panel
                  child: ClipRRect(
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(PortalDesignSystem.overlayBorderRadius)),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: PortalDesignSystem.getOverlayBlurBackground(isDark),
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(PortalDesignSystem.overlayBorderRadius)),
                          border: Border(
                            right: BorderSide(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: currentWidth < 120
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
        ));
      },
    );
  }
}
