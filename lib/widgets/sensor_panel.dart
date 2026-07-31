import 'package:flutter/material.dart';
import '../services/launcher_service.dart';

class SensorPanel extends StatefulWidget {
  final Map<String, dynamic> hardwareInfo;
  final bool loadingHardware;
  final Set<String> expandedSensors;
  final bool flashlightEnabled;
  final bool autoRotationEnabled;
  final bool fmRadioSimEnabled;
  final VoidCallback onRefreshHardware;
  final ValueChanged<bool> onToggleFlashlight;
  final ValueChanged<bool> onToggleAutoRotation;
  final ValueChanged<bool> onToggleFmRadio;
  final String Function(String name, String type) getSensorDescription;

  const SensorPanel({
    super.key,
    required this.hardwareInfo,
    required this.loadingHardware,
    required this.expandedSensors,
    required this.flashlightEnabled,
    required this.autoRotationEnabled,
    required this.fmRadioSimEnabled,
    required this.onRefreshHardware,
    required this.onToggleFlashlight,
    required this.onToggleAutoRotation,
    required this.onToggleFmRadio,
    required this.getSensorDescription,
  });

  @override
  State<SensorPanel> createState() => _SensorPanelState();
}

class _SensorPanelState extends State<SensorPanel> {
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.loadingHardware) {
      return const Center(child: CircularProgressIndicator());
    }

    final wifi = widget.hardwareInfo['wifi'] as Map? ?? {};
    final bluetooth = widget.hardwareInfo['bluetooth'] as Map? ?? {};

    final bool wifiActive = wifi['enabled'] == true && !_offlineMode;
    final bool btActive = bluetooth['enabled'] == true && !_offlineMode;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── 1. Modo Offline Top Header Button ─────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              setState(() {
                _offlineMode = !_offlineMode;
              });
              if (_offlineMode) {
                // Disable active radios
                if (wifi['enabled'] == true) await LauncherService.toggleWifi(false);
                if (bluetooth['enabled'] == true) await LauncherService.toggleBluetooth(false);
              }
              widget.onRefreshHardware();
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _offlineMode
                    ? theme.colorScheme.error.withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _offlineMode
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _offlineMode ? Icons.wifi_off_rounded : Icons.public_rounded,
                    size: 22,
                    color: _offlineMode ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _offlineMode ? 'MODO OFFLINE ATIVO' : 'MODO ONLINE ATIVO',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: _offlineMode ? theme.colorScheme.error : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _offlineMode
                              ? 'Rádios e transmissões locais desativados'
                              : 'Conexões e sensores operando normalmente',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _offlineMode ? theme.colorScheme.error : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _offlineMode ? 'OFFLINE' : 'ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── 2. Grid de Botões Padronizados ─────────────────────────────────
        Text(
          'CONTROLES RÁPIDOS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            _buildStandardGridButton(
              'Wi-Fi',
              wifiActive,
              wifiActive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              theme,
              isDark,
              onTap: () async {
                await LauncherService.toggleWifi(!wifiActive);
                Future.delayed(const Duration(milliseconds: 1000), widget.onRefreshHardware);
              },
            ),
            _buildStandardGridButton(
              'Bluetooth',
              btActive,
              btActive ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
              theme,
              isDark,
              onTap: () async {
                await LauncherService.toggleBluetooth(!btActive);
                Future.delayed(const Duration(milliseconds: 1000), widget.onRefreshHardware);
              },
            ),
            _buildStandardGridButton(
              'Lanterna',
              widget.flashlightEnabled,
              widget.flashlightEnabled ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              theme,
              isDark,
              onTap: () => widget.onToggleFlashlight(!widget.flashlightEnabled),
            ),
            _buildStandardGridButton(
              'Rotação Tela',
              widget.autoRotationEnabled,
              widget.autoRotationEnabled ? Icons.screen_rotation_rounded : Icons.screen_lock_rotation_rounded,
              theme,
              isDark,
              onTap: () => widget.onToggleAutoRotation(!widget.autoRotationEnabled),
            ),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStandardGridButton(
    String label,
    bool isActive,
    IconData icon,
    ThemeData theme,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    final activeBg = theme.colorScheme.primary;
    final activeFg = theme.colorScheme.onPrimary;
    final inactiveBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05);
    final inactiveFg = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? activeBg
                  : theme.colorScheme.primary.withValues(alpha: 0.12),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? activeFg : inactiveFg,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? activeFg : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
