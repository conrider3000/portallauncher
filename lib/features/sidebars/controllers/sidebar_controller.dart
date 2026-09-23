import 'package:flutter/foundation.dart';

class SidebarController {
  final ValueNotifier<double> leftBarWidth = ValueNotifier<double>(0.0);
  final ValueNotifier<double> sideBarWidth = ValueNotifier<double>(0.0);
  
  DateTime? lastLeftBarOpenedTime;
  DateTime? lastRightBarOpenedTime;

  /// Atualiza a largura da barra esquerda (com clamp limitador)
  void updateLeftBarWidth(double newWidth, double maxBarWidth) {
    leftBarWidth.value = newWidth.clamp(0.0, maxBarWidth);
    if (leftBarWidth.value > 0) {
      lastLeftBarOpenedTime ??= DateTime.now();
    } else {
      lastLeftBarOpenedTime = null;
    }
  }

  /// Atualiza a largura da barra direita (com clamp limitador)
  void updateRightBarWidth(double newWidth, double maxBarWidth) {
    sideBarWidth.value = newWidth.clamp(0.0, maxBarWidth);
    if (sideBarWidth.value > 0) {
      lastRightBarOpenedTime ??= DateTime.now();
    } else {
      lastRightBarOpenedTime = null;
    }
  }

  double _leftDragStartWidth = 0.0;
  double _rightDragStartWidth = 0.0;

  void startLeftDrag(double initialWidth) {
    _leftDragStartWidth = initialWidth;
  }

  void startRightDrag(double initialWidth) {
    _rightDragStartWidth = initialWidth;
  }

  void handleLeftDragEnd(double primaryVelocity, double maxBarWidth) {
    if (_leftDragStartWidth < 10.0) {
      if (primaryVelocity < -200 || leftBarWidth.value < 20.0) {
        leftBarWidth.value = 0.0;
      } else {
        leftBarWidth.value = 72.0;
      }
    } else if (_leftDragStartWidth >= 70.0 && _leftDragStartWidth < 100.0) {
      if (primaryVelocity > 200 || leftBarWidth.value > 120.0) {
        leftBarWidth.value = maxBarWidth;
      } else if (primaryVelocity < -200 || leftBarWidth.value < 36.0) {
        leftBarWidth.value = 0.0;
      } else {
        leftBarWidth.value = 72.0;
      }
    } else {
      if (primaryVelocity < -200 || leftBarWidth.value < maxBarWidth - 50.0) {
        if (leftBarWidth.value < 100.0) {
          leftBarWidth.value = 0.0;
        } else {
          leftBarWidth.value = 72.0;
        }
      } else {
        leftBarWidth.value = maxBarWidth;
      }
    }
  }

  void handleRightDragEnd(double primaryVelocity, double maxBarWidth) {
    if (_rightDragStartWidth < 10.0) {
      if (primaryVelocity > 200 || sideBarWidth.value < 20.0) {
        sideBarWidth.value = 0.0;
      } else {
        sideBarWidth.value = 72.0;
      }
    } else if (_rightDragStartWidth >= 70.0 && _rightDragStartWidth < 100.0) {
      if (primaryVelocity < -200 || sideBarWidth.value > 120.0) {
        sideBarWidth.value = maxBarWidth;
      } else if (primaryVelocity > 200 || sideBarWidth.value < 36.0) {
        sideBarWidth.value = 0.0;
      } else {
        sideBarWidth.value = 72.0;
      }
    } else {
      if (primaryVelocity > 200 || sideBarWidth.value < maxBarWidth - 50.0) {
        if (sideBarWidth.value < 100.0) {
          sideBarWidth.value = 0.0;
        } else {
          sideBarWidth.value = 72.0;
        }
      } else {
        sideBarWidth.value = maxBarWidth;
      }
    }
  }

  /// Fecha as barras laterais considerando o timeout de clique (500ms preventivos do Android)
  bool tryCloseLeftBar() {
    if (leftBarWidth.value > 0.0) {
      final now = DateTime.now();
      if (lastLeftBarOpenedTime == null || now.difference(lastLeftBarOpenedTime!).inMilliseconds > 500) {
        leftBarWidth.value = 0.0;
        lastLeftBarOpenedTime = null;
        return true;
      }
    }
    return false;
  }

  bool tryCloseRightBar() {
    if (sideBarWidth.value > 0.0) {
      final now = DateTime.now();
      if (lastRightBarOpenedTime == null || now.difference(lastRightBarOpenedTime!).inMilliseconds > 500) {
        sideBarWidth.value = 0.0;
        lastRightBarOpenedTime = null;
        return true;
      }
    }
    return false;
  }

  void forceCloseAll() {
    leftBarWidth.value = 0.0;
    sideBarWidth.value = 0.0;
    lastLeftBarOpenedTime = null;
    lastRightBarOpenedTime = null;
  }
}
