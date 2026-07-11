import 'package:flutter/foundation.dart';

/// Returns true only when running as a real Android device/emulator.
/// Safe to call on web, Windows, macOS, Linux, iOS.
bool get isAndroidNative => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
