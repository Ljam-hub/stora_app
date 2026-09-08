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

  /// Primary Wi-Fi LAN IP of host machine (192.168.254.105)
  static const lanUrl = 'http://192.168.254.105:8000/api';

  /// Secondary Wi-Fi LAN IP fallback (192.168.254.107)
  static const altLanUrl = 'http://192.168.254.107:8000/api';

  static String? _customUrl;

  static String _baseUrl = _defaultUrl();

  static String get baseUrl => _baseUrl;

  static String _defaultUrl() {
    if (_customUrl != null && _customUrl!.isNotEmpty) return _customUrl!;
    if (_envUrl.isNotEmpty) return _envUrl;
    return 'http://127.0.0.1:8000/api';
  }

  static void setCustomUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customUrl = null;
    } else {
      var cleaned = url.trim();
      if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
        cleaned = 'http://$cleaned';
      }
      if (!cleaned.endsWith('/api') && !cleaned.endsWith('/api/')) {
        cleaned = cleaned.endsWith('/') ? '${cleaned}api' : '$cleaned/api';
      }
      if (cleaned.endsWith('/')) {
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
      _customUrl = cleaned;
      _baseUrl = cleaned;
    }
    debugPrint('ApiConfig: customUrl set to: $_customUrl, baseUrl: $_baseUrl');
  }

  /// Windows Mobile Hotspot IP
  static const hotspotUrl = 'http://192.168.137.1:8000/api';

  static List<String> get candidates {
    final urls = <String>[];
    void add(String? url) {
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    add(_customUrl);
    add(_envUrl);
    if (!kIsWeb && Platform.isAndroid) {
      add('http://127.0.0.1:8000/api'); // ADB reverse port forwarding (USB connection)
      add('http://10.0.2.2:8000/api'); // Android Emulator default
      add(lanUrl); // Wi-Fi LAN IP (192.168.254.105)
      add(altLanUrl); // Alternate LAN IP (192.168.254.107)
      add(hotspotUrl); // Windows Mobile Hotspot IP (192.168.137.1)
      add('http://localhost:8000/api');
    } else {
      add('http://127.0.0.1:8000/api');
      add('http://localhost:8000/api');
      add(lanUrl);
      add(altLanUrl);
      add(hotspotUrl);
    }
    return urls;
  }

  /// Probes candidate hosts in parallel and selects the highest-priority reachable host.
  /// Returns `true` if a reachable host was found, `false` otherwise.
  static Future<bool> resolve() async {
    final candidateList = List<String>.from(candidates);
    debugPrint('ApiConfig: resolving across candidates: $candidateList');

    // Probe all candidates concurrently with a fast timeout
    final probeResults = await Future.wait(
      candidateList.map((url) async {
        final ok = await _reachable(url);
        return ok ? url : null;
      }),
    );

    // Pick highest-priority reachable URL
    for (final url in candidateList) {
      if (probeResults.contains(url)) {
        _baseUrl = url;
        debugPrint('ApiConfig: resolved baseUrl -> $_baseUrl');
        return true;
      }
    }

    _baseUrl = _customUrl ?? candidateList.first;
    debugPrint('ApiConfig: fallback baseUrl -> $_baseUrl (server not answering)');
    return false;
  }

  static Future<bool> _reachable(String base) async {
    try {
      final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;

      // 1. Probe dedicated health check endpoint first
      try {
        final healthUri = Uri.parse('$cleanBase/health/');
        final res = await http
            .get(healthUri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(milliseconds: 3000));
        if (res.statusCode < 500) return true;
      } catch (_) {}

      // 2. Fallback to base root
      final baseUri = Uri.parse('$cleanBase/');
      final res = await http
          .get(baseUri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(milliseconds: 2500));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
