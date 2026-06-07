import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api/v1';
    return 'http://10.0.2.2:3000/api/v1';
  }

  static String get socketUrl {
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }
  static String get _imageOrigin {
    if (kIsWeb) return 'http://localhost:3000';
    return 'http://10.0.2.2:3000';
  }

  static String? resolveImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.indexOf('/uploads/');
    if (idx >= 0) return '$_imageOrigin${raw.substring(idx)}';
    return raw;
  }
}
