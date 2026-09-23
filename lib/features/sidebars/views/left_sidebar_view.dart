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

class _LeftSidebarViewState extends State<LeftSidebarView> {
  bool _isOfflineMode = false;
  bool _flashlightEnabled = false;
  bool _autoRotationEnabled = false;
  bool _fmRadioSimEnabled = false;
  Map<String, dynamic> _hardwareInfo = {};

  @override
  void initState() {
    super.initState();
    _loadHardwareInfo();
    _loadInitialStates();
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
                      widget.controller.updateLeftBarWidth(PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width), PortalDesignSystem.maxBarWidth(MediaQuery.of(context).size.width));
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  title: 'Câmera Digital',
                  subtitle: 'Captura de fotos e vídeos',
                  icon: Icons.camera_alt_rounded,
                  active: true,
                  badgeText: 'ABRIR',
                  theme: theme,
                  isDark: isDark,
                  onTap: () => LauncherService.openCameraApp(),
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
                    setState(() {
                      _flashlightEnabled = newSt;
                    });
                  },
                ),

                _buildCompassCard(theme, isDark),

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
