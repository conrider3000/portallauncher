import 'package:flutter/material.dart';

class PortalDesignSystem {
  PortalDesignSystem._();

  // Dimensões e Âncoras
  static const double sidebarOpenTrigger = 60.0;
  static const double miniBarWidth = 72.0;
  
  static double maxBarWidth(double screenWidth) => screenWidth * 0.5;

  static const double wikiOverlayMarginTop = 148.0;
  static const double wikiOverlayMarginBottom = 148.0;
  
  static const double tabBarBorderRadius = 24.0;
  static const double overlayBorderRadius = 28.0;

  static const Duration androidGestureDelay = Duration(milliseconds: 500);

  // Cores - Fundo Escuro (Dark Mode)
  static const Color darkBackground = Color(0xFF070D09);
  static Color get darkOverlayBlur => const Color(0xFF1C1C1E).withValues(alpha: 0.85);

  // Cores - Fundo Claro (Light Mode)
  static const Color lightBackground = Color(0xFFF4F7F5);
  static Color get lightOverlayBlur => const Color(0xFFE5E5EA).withValues(alpha: 0.85);

  // Helpers
  static Color getActiveTabBackground(bool isDark) => 
      isDark ? darkBackground : lightBackground;

  static Color getOverlayBlurBackground(bool isDark) => 
      isDark ? darkOverlayBlur : lightOverlayBlur;
}
