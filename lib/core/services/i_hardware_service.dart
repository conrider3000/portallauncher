abstract class IHardwareService {
  Future<bool> toggleWifi(bool enabled);
  Future<bool> toggleBluetooth(bool enabled);
  Future<bool> toggleFlashlight(bool enabled);
  Future<bool> setAutoRotationEnabled(bool enabled);
  Future<Map<String, dynamic>> getHardwareInfo();
}
