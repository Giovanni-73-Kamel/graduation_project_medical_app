import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configuredBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  static String get backendBaseUrl {
    final configured = _configuredBackendBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _stripTrailingSlash(configured);
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String _stripTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
