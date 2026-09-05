import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Base URL for the Django REST API (`/api`).
///
/// Override at build/run time with:
/// `--dart-define=STORA_API_URL=http://192.168.x.x:8000/api`
///
/// On a physical Android phone over USB, also run:
/// `adb reverse tcp:8000 tcp:8000`
class ApiConfig {
  static const _envUrl = String.fromEnvironment('STORA_API_URL');

  /// This PC's Wi-Fi IPv4 so a physical phone on the same network can
  /// reach Django. Update if `ipconfig` shows a different address.
  static const lanUrl = 'http://192.168.254.107:8000/api';

  static String _baseUrl = _defaultUrl();

  static String get baseUrl => _baseUrl;

  static String _defaultUrl() {
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'http://127.0.0.1:8000/api';
  }

  static List<String> get _candidates {
    final urls = <String>[];
    void add(String url) {
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }

    add(_envUrl);
    if (!kIsWeb && Platform.isAndroid) {
      add('http://127.0.0.1:8000/api');
      add('http://10.0.2.2:8000/api');
      add(lanUrl);
      add('http://localhost:8000/api');
    } else {
      add('http://127.0.0.1:8000/api');
      add('http://localhost:8000/api');
      add(lanUrl);
    }
    return urls;
  }

  /// Pick the first API host that actually answers. A 401 from `/api/`
  /// still counts — that means Django is up, just unauthenticated.
  static Future<void> resolve() async {
    for (final url in _candidates) {
      if (await _reachable(url)) {
        _baseUrl = url;
        debugPrint('ApiConfig: resolved baseUrl -> $_baseUrl');
        return;
      }
    }
    _baseUrl = _candidates.first;
    debugPrint('ApiConfig: fallback baseUrl -> $_baseUrl');
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
