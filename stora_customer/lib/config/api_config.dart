import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static const _envUrl = String.fromEnvironment('STORA_API_URL');
  static const lanUrl = 'http://192.168.254.107:8000/api';

  static String baseUrl = _defaultUrl();

  static String _defaultUrl() {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'http://127.0.0.1:8000/api';
  }

  static List<String> get candidates {
    final urls = <String>[];
    void add(String url) {
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }

    add(_envUrl);
    if (!kIsWeb && Platform.isAndroid) {
      add('http://127.0.0.1:8000/api'); // ADB reverse port forwarding (instant USB connection)
      add('http://10.0.2.2:8000/api'); // Android Emulator default
      add(lanUrl); // Wi-Fi LAN IP
      add('http://localhost:8000/api');
    } else {
      add('http://127.0.0.1:8000/api');
      add('http://localhost:8000/api');
      add(lanUrl);
    }
    return urls;
  }

  static Future<void> resolve() async {
    for (final url in candidates) {
      if (await _reachable(url)) {
        baseUrl = url;
        debugPrint('ApiConfig resolved baseUrl: $baseUrl');
        return;
      }
    }
    baseUrl = candidates.first;
    debugPrint('ApiConfig fallback baseUrl: $baseUrl');
  }

  static Future<bool> _reachable(String base) async {
    try {
      final cleanBase = base.endsWith('/') ? base : '$base/';
      final response = await http
          .get(
            Uri.parse(cleanBase),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(milliseconds: 1500));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
