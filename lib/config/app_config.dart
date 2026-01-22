import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // Your Mac's IP address on the local network
  static const String macIpAddress = '10.176.212.52';
  
  // Determine if running on a physical device vs simulator/emulator
  static bool get isPhysicalDevice {
    if (kIsWeb) return false;
    
    // On iOS, check if running on simulator
    // Note: This is a simple heuristic. In production, you might use a more robust check.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Simulators typically won't error on Platform.environment checks
      // Physical devices are harder to detect without plugins, but we can use this as a fallback
      return !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
    }
    
    // Android emulators can be detected similarly
    if (defaultTargetPlatform == TargetPlatform.android) {
      return false; // For now, assume emulator (can be enhanced)
    }
    
    return false; // Desktop and other platforms
  }
  
  /// Returns the appropriate backend URL based on platform and device type
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:7071/api';
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator uses 10.0.2.2 to access host machine
      return 'http://10.0.2.2:7071/api';
    }
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Physical iOS device needs Mac's IP address
      if (isPhysicalDevice) {
        return 'http://$macIpAddress:7071/api';
      }
      // iOS simulator can use localhost
      return 'http://127.0.0.1:7071/api';
    }
    
    // macOS and other platforms use localhost
    return 'http://127.0.0.1:7071/api';
  }
  
  /// Returns full base URL including protocol and port (for constructing full URLs)
  static String get baseUrlWithoutApi {
    if (kIsWeb) {
      return 'http://127.0.0.1:7071';
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:7071';
    }
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (isPhysicalDevice) {
        return 'http://$macIpAddress:7071';
      }
      return 'http://127.0.0.1:7071';
    }
    
    return 'http://127.0.0.1:7071';
  }
}
