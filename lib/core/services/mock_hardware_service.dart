import 'package:flutter/foundation.dart';
import 'i_hardware_service.dart';

class MockHardwareService implements IHardwareService {
  bool _wifiEnabled = true;
  bool _bluetoothEnabled = false;
  bool _flashlightEnabled = false;
  bool _autoRotationEnabled = true;

  @override
  Future<bool> toggleWifi(bool enabled) async {
    _wifiEnabled = enabled;
    debugPrint('MockHardwareService: toggleWifi($enabled)');
    return true;
  }

  @override
  Future<bool> toggleBluetooth(bool enabled) async {
    _bluetoothEnabled = enabled;
    debugPrint('MockHardwareService: toggleBluetooth($enabled)');
    return true;
  }

  @override
  Future<bool> toggleFlashlight(bool enabled) async {
    _flashlightEnabled = enabled;
    debugPrint('MockHardwareService: toggleFlashlight($enabled)');
    return true;
  }

  @override
  Future<bool> setAutoRotationEnabled(bool enabled) async {
    _autoRotationEnabled = enabled;
    debugPrint('MockHardwareService: setAutoRotationEnabled($enabled)');
    return true;
  }

  @override
  Future<Map<String, dynamic>> getHardwareInfo() async {
    debugPrint('MockHardwareService: getHardwareInfo()');
    return {
      'wifi': {'enabled': _wifiEnabled},
      'bluetooth': {'enabled': _bluetoothEnabled},
      'flashlight': {'enabled': _flashlightEnabled},
      'autoRotation': {'enabled': _autoRotationEnabled},
      'batteryLevel': 100,
      'isCharging': true,
    };
  }
}
