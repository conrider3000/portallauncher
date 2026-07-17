import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/launcher_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/tropical_theme.dart';
import 'utils/platform_helper.dart';
import 'utils/theme_manager.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
  runApp(const PortalApp());
}

class PortalApp extends StatefulWidget {
  const PortalApp({super.key});

  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> {
  bool _showOnboarding = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Load theme preference on startup
    await ThemeManager.loadTheme();

    try {
      final prefs = await SharedPreferences.getInstance();
      final launched = prefs.getBool('portal_launched') ?? false;
      _showOnboarding = !launched;
    } catch (_) {
      _showOnboarding = true;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('portal_launched', true);
      await prefs.setBool('portal_lgpd_accepted', true);
    } catch (_) {}

    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          title: 'Portal',
          debugShowCheckedModeBanner: false,
          theme: TropicalTheme.light,
          darkTheme: TropicalTheme.dark,
          themeMode: currentThemeMode,
          home: DesktopPhoneFrame(
            child: _showOnboarding
                ? OnboardingScreen(
                    onSetupComplete: _completeOnboarding,
                  )
                : const LauncherScreen(),
          ),
        );
      },
    );
  }
}

class DesktopPhoneFrame extends StatelessWidget {
  final Widget child;
  const DesktopPhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // On real Android, no frame needed
    if (isAndroidNative) return child;

    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0A0F0B) : const Color(0xFFDDE8DF),
      child: Center(
        child: Container(
          width: 390,
          height: 844,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(44),
            border: Border.all(
              color: isDark ? const Color(0xFF2A4A35) : const Color(0xFF1A4A2E),
              width: 10,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: child,
          ),
        ),
      ),
    );
  }
}
