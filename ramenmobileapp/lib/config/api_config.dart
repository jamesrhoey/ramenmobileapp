import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Network configuration for different environments
  static const String _localPort = '3000';
  static const String _apiPath = '/api/v1';
  
  // Machine IP addresses (update these if your network changes)
  static const String _machineIP = '192.168.194.188';
  static const String _emulatorIP = '10.0.2.2';
  
  // Get the appropriate base URL for the current platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$_localPort$_apiPath';
    }
    
    if (Platform.isAndroid) {
      // Use localhost with ADB port forwarding (most reliable)
      return 'http://localhost:$_localPort$_apiPath';
      // Alternative: 'http://$_machineIP:$_localPort$_apiPath';
    }
    
    if (Platform.isIOS) {
      return 'http://localhost:$_localPort$_apiPath';
    }
    
    // Default fallback
    return 'http://localhost:$_localPort$_apiPath';
  }
  
  // Alternative URLs for Android emulator troubleshooting
  static String get alternativeAndroidUrl => 'http://$_emulatorIP:$_localPort$_apiPath';
  static String get machineIPUrl => 'http://$_machineIP:$_localPort$_apiPath';
  
  // Connection settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // Debug information
  static void printNetworkInfo() {
    print('🌐 API Configuration:');
    print('📱 Platform: ${Platform.operatingSystem}');
    print('🔗 Base URL: $baseUrl');
    print('🔄 Alternative Android URL: $alternativeAndroidUrl');
    print('💻 Machine IP URL: $machineIPUrl');
  }
}
