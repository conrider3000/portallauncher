import 'package:flutter/services.dart';
import 'i_hardware_service.dart';

class AndroidHardwareService implements IHardwareService {
  static const _channel = MethodChannel('com.portal/launcher_setup');

  @override
  Future<bool> toggleWifi(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleWifi', {'enabled': enabled});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> toggleBluetooth(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleBluetooth', {'enabled': enabled});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> toggleFlashlight(bool enabled) async {
    try {
      await _channel.invokeMethod('toggleFlashlight', {'enabled': enabled});
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setAutoRotationEnabled(bool enabled) async {
    try {
      return await _channel.invokeMethod('setAutoRotationEnabled', {'enabled': enabled}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getHardwareInfo() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getDeviceHardwareInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
