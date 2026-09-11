import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../db/stora_database.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthResult {
  AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
    required this.businessName,
    this.isEmailVerified = false,
    this.avatarUrl,
  });

  final String accessToken;
  final String refreshToken;
  final String email;
  final String businessName;
  final bool isEmailVerified;
  final String? avatarUrl;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await AppDatabase.instance.authDao.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Never _throw(http.Response response) {
    final decoded = _decode(response);
    throw ApiException(_flattenError(decoded, response.statusCode), statusCode: response.statusCode);
  }

  String _flattenError(dynamic decoded, int status) {
    if (decoded is Map<String, dynamic>) {
      if (decoded['detail'] is String) return decoded['detail'] as String;
      final parts = <String>[];
      decoded.forEach((key, value) {
        if (value is List) {
          parts.add(value.map((e) => e.toString()).join(' '));
        } else if (value is String) {
          parts.add(value);
        }
      });
      if (parts.isNotEmpty) return parts.join(' ');
    }
    if (status == 401) return 'Please log in again.';
    return 'Request failed ($status)';
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? encoded,
  ) async {
    try {
      final Future<http.Response> request;
      switch (method) {
        case 'GET':
          request = http.get(uri, headers: headers);
          break;
        case 'POST':
          request = http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          request = http.put(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          request = http.patch(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          request = http.delete(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported method $method');
      }
      return await request.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(
        'Server timed out. Is stora_backend running at ${ApiConfig.baseUrl}?',
      );
    } on SocketException {
      throw ApiException('Could not reach the server at ${ApiConfig.baseUrl}');
    } on http.ClientException {
      throw ApiException('Could not reach the server at ${ApiConfig.baseUrl}');
    }
  }

  Future<bool> _refreshAccessToken() async {
    final session = await AppDatabase.instance.authDao.readSession();
    if (session == null || session.refreshToken.isEmpty) return false;
    try {
      final response = await http.post(
        _uri('/auth/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh': session.refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access'] as String?;
      if (access == null || access.isEmpty) return false;
      await AppDatabase.instance.authDao.saveSession(
        accessToken: access,
        refreshToken: (data['refresh'] as String?) ?? session.refreshToken,
        email: session.email,
        businessName: session.businessName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    bool auth = true,
    Object? body,
  }) async {
    final encoded = body == null ? null : jsonEncode(body);
    http.Response response;
    try {
      response = await _dispatch(method, _uri(path), await _headers(auth: auth), encoded);
    } on ApiException {
      // If the current host failed to connect, attempt re-resolution across candidates
      final currentBase = ApiConfig.baseUrl;
      final reResolved = await ApiConfig.resolve();
      if (reResolved || ApiConfig.baseUrl != currentBase) {
        response = await _dispatch(method, _uri(path), await _headers(auth: auth), encoded);
      } else {
        rethrow;
      }
    }
    if (auth && response.statusCode == 401 && await _refreshAccessToken()) {
      response = await _dispatch(method, _uri(path), await _headers(auth: auth), encoded);
    }
    return response;
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String businessName,
  }) async {
    final response = await _send(
      'POST',
      '/auth/register/',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'business_name': businessName,
      },
    );
    if (response.statusCode != 201) _throw(response);
    return _parseAuth(response);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      'POST',
      '/auth/login/',
      auth: false,
      body: {'email': email, 'password': password, 'app_role': 'owner'},
    );
    if (response.statusCode != 200) _throw(response);
    return _parseAuth(response);
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    final response = await _send(
      'POST',
      '/auth/verify-email/',
      auth: false,
      body: {
        'email': email.trim(),
        'code': code.trim(),
      },
    );
    if (response.statusCode != 200) _throw(response);
    return _parseAuth(response);
  }

  Future<void> resendVerification({
    required String email,
  }) async {
    final response = await _send(
      'POST',
      '/auth/resend-verification/',
      auth: false,
      body: {
        'email': email.trim(),
      },
    );
    if (response.statusCode != 200) _throw(response);
  }

  AuthResult _parseAuth(http.Response response) {
    final data = _decode(response) as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>? ?? {};
    return AuthResult(
      accessToken: (data['access'] as String?) ?? '',
      refreshToken: (data['refresh'] as String?) ?? '',
      email: (user['email'] as String?) ?? (data['email'] as String?) ?? '',
      businessName: (user['business_name'] as String?) ?? (data['business_name'] as String?) ?? '',
      isEmailVerified: user['is_email_verified'] == true || data['is_email_verified'] == true,
      avatarUrl: (user['avatar_url'] as String?) ?? (data['avatar_url'] as String?),
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _send('GET', '/auth/me/');
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? businessName,
    String? email,
  }) async {
    final body = <String, dynamic>{};
    if (businessName != null) body['business_name'] = businessName;
    if (email != null) body['email'] = email;
    final response = await _send('PATCH', '/auth/me/', body: body);
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadAvatar(Uint8List imageBytes, String filename) async {
    final token = await AppDatabase.instance.authDao.readAccessToken();
    final request = http.MultipartRequest('PATCH', _uri('/auth/me/'));
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        imageBytes,
        filename: filename,
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getStoreCustomers() async {
    final response = await _send('GET', '/messages/customers/');
    if (response.statusCode != 200) _throw(response);
    return (jsonDecode(response.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _send(
      'POST',
      '/auth/change-password/',
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
    if (response.statusCode != 200) _throw(response);
    final data = _decode(response) as Map<String, dynamic>;
    return (data['detail'] as String?) ?? 'Password updated successfully';
  }

  Future<Map<String, dynamic>> getSubscriptionConfig() async {
    final response = await _send('GET', '/subscription/config/');
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final response = await _send('GET', '/categories/');
    if (response.statusCode != 200) _throw(response);
    return (jsonDecode(response.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createCategory(String name) async {
    final response = await _send('POST', '/categories/', body: {'name': name});
    if (response.statusCode != 201) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchCategory(String id, Map<String, dynamic> body) async {
    final response = await _send('PATCH', '/categories/$id/', body: body);
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteCategory(String id) async {
    final response = await _send('DELETE', '/categories/$id/');
    if (response.statusCode != 204 && response.statusCode != 200) _throw(response);
  }

  Future<List<Map<String, dynamic>>> listProducts() async {
    final response = await _send('GET', '/products/');
    if (response.statusCode != 200) _throw(response);
    return (jsonDecode(response.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async {
    final response = await _send('POST', '/products/', body: body);
    if (response.statusCode != 201) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> body) async {
    final response = await _send('PUT', '/products/$id/', body: body);
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> adjustStock(String id, int delta) async {
    if (id.startsWith('local-')) return null;
    final response = await _send('PATCH', '/products/$id/adjust_stock/', body: {'delta': delta});
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteProduct(String id) async {
    if (id.startsWith('local-')) return;
    final response = await _send('DELETE', '/products/$id/');
    if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 404) {
      _throw(response);
    }
  }

  Future<List<Map<String, dynamic>>> listSales() async {
    final response = await _send('GET', '/sales/');
    if (response.statusCode != 200) _throw(response);
    return (jsonDecode(response.body) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> body) async {
    final response = await _send('POST', '/sales/', body: body);
    if (response.statusCode != 201) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteSale(String id) async {
    final response = await _send('DELETE', '/sales/$id/');
    if (response.statusCode != 204 && response.statusCode != 200) _throw(response);
  }

  // ---------- Barcode ----------

  Future<Map<String, dynamic>?> lookupBarcode(String code) async {
    final response = await _send('GET', '/products/barcode/$code/');
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------- Account status & Subscription ----------

  Future<Map<String, dynamic>> getAccountStatus() async {
    final response = await _send('GET', '/account/status/');
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final response = await _send('GET', '/subscription/status/');
    if (response.statusCode != 200) _throw(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadPaymentProof({
    required String referenceNumber,
    required double amount,
    required List<int> screenshotBytes,
    String filename = 'screenshot.jpg',
  }) async {
    final uri = _uri('/subscription/upload-proof/');
    final token = await AppDatabase.instance.authDao.readAccessToken();

    http.MultipartRequest buildRequest(String? bearerToken) {
      final req = http.MultipartRequest('POST', uri);
      if (bearerToken != null && bearerToken.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $bearerToken';
      }
      req.headers['Accept'] = 'application/json';
      req.fields['reference_number'] = referenceNumber;
      req.fields['amount'] = amount.toStringAsFixed(2);
      req.files.add(
        http.MultipartFile.fromBytes(
          'screenshot',
          screenshotBytes,
          filename: filename,
        ),
      );
      return req;
    }

    try {
      var streamedResponse = await buildRequest(token).send().timeout(const Duration(seconds: 25));
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 401 && await _refreshAccessToken()) {
        final newToken = await AppDatabase.instance.authDao.readAccessToken();
        streamedResponse = await buildRequest(newToken).send().timeout(const Duration(seconds: 25));
        response = await http.Response.fromStream(streamedResponse);
      }
      if (response.statusCode != 201) _throw(response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw ApiException('Server timed out. Is stora_backend running at ${ApiConfig.baseUrl}?');
    } on SocketException {
      throw ApiException('Could not reach the server at ${ApiConfig.baseUrl}');
    } on http.ClientException {
      throw ApiException('Could not reach the server at ${ApiConfig.baseUrl}');
    }
  }


  // ---------- Forgot password ----------

  Future<String> requestPasswordReset(String email) async {
    final response = await _send(
      'POST',
      '/auth/forgot-password/',
      auth: false,
      body: {'email': email},
    );
    if (response.statusCode != 200) _throw(response);
    final data = _decode(response) as Map<String, dynamic>;
    return data['detail'] as String;
  }

  Future<String> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    final response = await _send(
      'POST',
      '/auth/reset-password/',
      auth: false,
      body: {'token': token, 'new_password': newPassword},
    );
    if (response.statusCode != 200) _throw(response);
    final data = _decode(response) as Map<String, dynamic>;
    return data['detail'] as String;
  }

  // ---------- Push Notifications (FCM) ----------

  Future<void> updateFcmToken(String fcmToken) async {
    final response = await _send(
      'POST',
      '/auth/fcm-token/',
      body: {'fcm_token': fcmToken},
    );
    if (response.statusCode != 200) _throw(response);
  }

  // ---------- Orders ----------

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await _send('GET', '/orders/');
    if (response.statusCode != 200) _throw(response);
    final decoded = _decode(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    final response = await _send('POST', '/orders/$orderId/accept/');
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markOrderReady(int orderId) async {
    final response = await _send('POST', '/orders/$orderId/ready/');
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> declineOrder(int orderId, {String reason = ''}) async {
    final response = await _send(
      'POST',
      '/orders/$orderId/decline/',
      body: {'reason': reason},
    );
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> counterOrder(
    int orderId, {
    required String notes,
    double? counterPrice,
  }) async {
    final response = await _send(
      'POST',
      '/orders/$orderId/counter/',
      body: {
        'notes': notes,
        if (counterPrice != null) 'counter_price': counterPrice.toStringAsFixed(2),
      },
    );
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  // ---------- Store Location ----------

  Future<Map<String, dynamic>> getStoreLocation() async {
    final response = await _send('GET', '/stores/my-location/');
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStoreLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    final response = await _send(
      'PUT',
      '/stores/my-location/',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'is_visible': true,
      },
    );
    if (response.statusCode != 200) _throw(response);
    return _decode(response) as Map<String, dynamic>;
  }

  // ---------- AI Store Insights ----------

  Future<List<Map<String, dynamic>>> fetchAiInsights() async {
    final response = await _send('GET', '/ai/insights/');
    if (response.statusCode != 200) _throw(response);
    final decoded = _decode(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> dismissAiInsight(int insightId) async {
    final response = await _send('POST', '/ai/insights/$insightId/dismiss/');
    if (response.statusCode != 200) _throw(response);
  }

  Future<void> clearFcmToken() async {
    try {
      await _send('POST', '/auth/clear-fcm-token/');
    } catch (_) {}
  }

  // ---------- Chat & Messaging ----------

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await _send('GET', '/messages/conversations/');
    if (response.statusCode != 200) _throw(response);
    final decoded = _decode(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchMessages(int withUserId) async {
    final response = await _send('GET', '/messages/?with_user=$withUserId');
    if (response.statusCode != 200) _throw(response);
    final decoded = _decode(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required int recipientId,
    String? message,
    List<int>? imageBytes,
    int? orderId,
    String filename = 'chat_image.jpg',
  }) async {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uri = _uri('/messages/');
      final token = await AppDatabase.instance.authDao.readAccessToken();

      http.MultipartRequest buildRequest(String? bearerToken) {
        final req = http.MultipartRequest('POST', uri);
        if (bearerToken != null && bearerToken.isNotEmpty) {
          req.headers['Authorization'] = 'Bearer $bearerToken';
        }
        req.headers['Accept'] = 'application/json';
        req.fields['recipient'] = recipientId.toString();
        if (message != null && message.trim().isNotEmpty) {
          req.fields['message'] = message.trim();
        }
        if (orderId != null) {
          req.fields['order'] = orderId.toString();
        }
        req.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: filename,
          ),
        );
        return req;
      }

      try {
        var streamedResponse = await buildRequest(token).send().timeout(const Duration(seconds: 25));
        var response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 401 && await _refreshAccessToken()) {
          final newToken = await AppDatabase.instance.authDao.readAccessToken();
          streamedResponse = await buildRequest(newToken).send().timeout(const Duration(seconds: 25));
          response = await http.Response.fromStream(streamedResponse);
        }
        if (response.statusCode != 201) _throw(response);
        return jsonDecode(response.body) as Map<String, dynamic>;
      } on TimeoutException {
        throw ApiException('Server timed out. Please check your connection.');
      } on SocketException {
        throw ApiException('Could not reach the server at ${ApiConfig.baseUrl}');
      }
    } else {
      final body = <String, dynamic>{
        'recipient': recipientId,
        'message': message ?? '',
      };
      if (orderId != null) body['order'] = orderId;
      final response = await _send('POST', '/messages/', body: body);
      if (response.statusCode != 201) _throw(response);
      return _decode(response) as Map<String, dynamic>;
    }
  }

  Future<void> blockCustomer(int customerId) async {
    final response = await _send('POST', '/messages/block/', body: {'customer_id': customerId});
    if (response.statusCode != 200) _throw(response);
  }

  Future<void> unblockCustomer(int customerId) async {
    final response = await _send('POST', '/messages/unblock/', body: {'customer_id': customerId});
    if (response.statusCode != 200) _throw(response);
  }

  Future<bool> checkBlockStatus(int customerId) async {
    final response = await _send('GET', '/messages/block-status/?customer_id=$customerId');
    if (response.statusCode != 200) _throw(response);
    final data = _decode(response) as Map<String, dynamic>;
    return data['is_blocked'] == true;
  }

  // ---------- User Reporting ----------

  Future<Map<String, dynamic>> submitReport({
    required int reportedUserId,
    required String reason,
    required String description,
    int? orderId,
    List<int>? attachmentBytes,
    String filename = 'report_evidence.jpg',
  }) async {
    if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      final uri = _uri('/reports/');
      final token = await AppDatabase.instance.authDao.readAccessToken();

      http.MultipartRequest buildRequest(String? bearerToken) {
        final req = http.MultipartRequest('POST', uri);
        if (bearerToken != null && bearerToken.isNotEmpty) {
          req.headers['Authorization'] = 'Bearer $bearerToken';
        }
        req.headers['Accept'] = 'application/json';
        req.fields['reported_user'] = reportedUserId.toString();
        req.fields['reason'] = reason;
        req.fields['description'] = description.trim();
        if (orderId != null) req.fields['order'] = orderId.toString();
        req.files.add(
          http.MultipartFile.fromBytes('attachment', attachmentBytes, filename: filename),
        );
        return req;
      }

      try {
        var streamedResponse = await buildRequest(token).send().timeout(const Duration(seconds: 25));
        var response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 401 && await _refreshAccessToken()) {
          final newToken = await AppDatabase.instance.authDao.readAccessToken();
          streamedResponse = await buildRequest(newToken).send().timeout(const Duration(seconds: 25));
          response = await http.Response.fromStream(streamedResponse);
        }
        if (response.statusCode != 201) _throw(response);
        return jsonDecode(response.body) as Map<String, dynamic>;
      } on TimeoutException {
        throw ApiException('Server timed out while submitting report.');
      } on SocketException {
        throw ApiException('Could not reach the server.');
      }
    } else {
      final body = <String, dynamic>{
        'reported_user': reportedUserId,
        'reason': reason,
        'description': description.trim(),
      };
      if (orderId != null) body['order'] = orderId;
      final response = await _send('POST', '/reports/', body: body);
      if (response.statusCode != 201) _throw(response);
      return _decode(response) as Map<String, dynamic>;
    }
  }
}

