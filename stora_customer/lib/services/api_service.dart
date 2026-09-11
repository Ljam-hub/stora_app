import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/store_model.dart';
import '../models/user_model.dart';
import '../storage/session_manager.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CustomerApiService {
  CustomerApiService._();
  static final CustomerApiService instance = CustomerApiService._();

  String get baseUrl => ApiConfig.baseUrl;
  String? accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null && accessToken!.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      };

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$cleanBase$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      return base.replace(queryParameters: queryParams);
    }
    return base;
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _cleanError(dynamic body, int statusCode) {
    try {
      dynamic decoded = body;
      if (body is String && body.trim().isNotEmpty) {
        decoded = jsonDecode(body);
      }
      if (decoded is Map) {
        if (decoded.containsKey('detail')) return decoded['detail'].toString();
        if (decoded.containsKey('error')) return decoded['error'].toString();
        if (decoded.containsKey('non_field_errors')) {
          final errs = decoded['non_field_errors'];
          return errs is List ? errs.join('\n') : errs.toString();
        }
        final parts = <String>[];
        decoded.forEach((key, value) {
          if (value is List) {
            parts.add('$key: ${value.join(", ")}');
          } else if (value != null) {
            parts.add('$key: $value');
          }
        });
        if (parts.isNotEmpty) return parts.join('\n');
      }
    } catch (_) {}
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode == 403) return 'You do not have permission to perform this action.';
    if (statusCode == 404) return 'Requested item not found.';
    if (statusCode >= 500) return 'Server error ($statusCode). Please try again later.';
    return 'Request failed ($statusCode)';
  }

  Never _throw(http.Response response) {
    final decoded = _decode(response);
    throw ApiException(_cleanError(decoded, response.statusCode), statusCode: response.statusCode);
  }

  Future<bool> _refreshAccessToken() async {
    final session = await SessionManager.instance.getSession();
    if (session == null || session.refreshToken.isEmpty) return false;
    try {
      final response = await http.post(
        _uri('/auth/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh': session.refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newAccess = data['access'] as String?;
      if (newAccess == null || newAccess.isEmpty) return false;
      final newRefresh = (data['refresh'] as String?) ?? session.refreshToken;

      accessToken = newAccess;
      await SessionManager.instance.saveSession(
        accessToken: newAccess,
        refreshToken: newRefresh,
        user: session.user,
        savedPhone: session.savedPhone,
        savedAddress: session.savedAddress,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _executeRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? encoded,
    Duration timeout,
  ) async {
    final Future<http.Response> request;
    switch (method.toUpperCase()) {
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
        throw ApiException('Unsupported HTTP method $method');
    }
    return await request.timeout(timeout);
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    dynamic body,
    Duration timeout = const Duration(seconds: 15),
    bool retryOn401 = true,
  }) async {
    final reqHeaders = headers ?? _headers;
    final encoded = body != null ? (body is String ? body : jsonEncode(body)) : null;

    http.Response response;
    try {
      response = await _executeRequest(method, uri, reqHeaders, encoded, timeout);
    } on TimeoutException catch (e) {
      response = await _attemptReResolveAndRetry(method, uri, reqHeaders, encoded, timeout, e);
    } on SocketException catch (e) {
      response = await _attemptReResolveAndRetry(method, uri, reqHeaders, encoded, timeout, e);
    } on http.ClientException catch (e) {
      response = await _attemptReResolveAndRetry(method, uri, reqHeaders, encoded, timeout, e);
    } on FormatException {
      throw ApiException('Invalid response received from server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }

    if (response.statusCode == 401 && retryOn401 && accessToken != null) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        final retryHeaders = headers ?? _headers;
        response = await _executeRequest(method, uri, retryHeaders, encoded, timeout);
      }
    }
    return response;
  }

  Future<http.Response> _attemptReResolveAndRetry(
    String method,
    Uri failedUri,
    Map<String, String> headers,
    String? encoded,
    Duration timeout,
    Object originalError,
  ) async {
    final previousBase = baseUrl;
    final foundReachable = await ApiConfig.resolve();
    if (foundReachable || baseUrl != previousBase) {
      try {
        final path = failedUri.path.replaceFirst(RegExp(r'^/api'), '');
        final retryUri = _uri(path, failedUri.queryParameters.isEmpty ? null : failedUri.queryParameters);
        debugPrint('CustomerApiService: Retrying request with newly resolved baseUrl: $baseUrl');
        return await _executeRequest(method, retryUri, headers, encoded, timeout);
      } catch (_) {}
    }

    if (originalError is TimeoutException) {
      throw ApiException('Server request timed out. Is the backend running at $baseUrl?');
    } else if (originalError is SocketException) {
      throw ApiException('Cannot reach backend server at $baseUrl. Please check your network connection.');
    } else if (originalError is http.ClientException) {
      throw ApiException('Connection failed: Unable to reach $baseUrl.');
    } else {
      throw ApiException('Connection failed: $originalError');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/login/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {'email': email.trim(), 'password': password, 'app_role': 'customer'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['access'] as String?;
      return data;
    }
    _throw(response);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/register/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {
        'email': email.trim(),
        'password': password,
        'business_name': (name ?? '').trim(),
        'role': 'customer',
      },
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['access'] as String?;
      return data;
    }
    _throw(response);
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String code) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/verify-email/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {'email': email.trim(), 'code': code.trim()},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['access'] as String?;
      if (data.containsKey('user') && data['user'] is Map) {
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        final session = await SessionManager.instance.getSession();
        await SessionManager.instance.saveSession(
          accessToken: data['access'] as String? ?? session?.accessToken ?? '',
          refreshToken: data['refresh'] as String? ?? session?.refreshToken ?? '',
          user: user,
          savedPhone: session?.savedPhone,
          savedAddress: session?.savedAddress,
        );
      }
      return data;
    }
    _throw(response);
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/resend-verification/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {'email': email.trim()},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    _throw(response);
  }

  Future<UserModel> fetchProfile() async {
    final response = await _dispatch('GET', _uri('/auth/me/'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    }
    _throw(response);
  }

  Future<UserModel> updateProfile({String? name, String? email}) async {
    final body = <String, dynamic>{};
    if (name != null) body['business_name'] = name.trim();
    if (email != null) body['email'] = email.trim();

    final response = await _dispatch('PATCH', _uri('/auth/me/'), body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return UserModel.fromJson(data);
    }
    _throw(response);
  }

  Future<UserModel> uploadAvatar(Uint8List imageBytes, String filename) async {
    if (accessToken == null || accessToken!.isEmpty) {
      final session = await SessionManager.instance.getSession();
      if (session != null && session.accessToken.isNotEmpty) {
        accessToken = session.accessToken;
      }
    }
    final request = http.MultipartRequest('PATCH', _uri('/auth/me/'));
    if (accessToken != null && accessToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
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
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final user = UserModel.fromJson(data);
      final session = await SessionManager.instance.getSession();
      if (session != null) {
        await SessionManager.instance.saveSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          user: user,
          savedPhone: session.savedPhone,
          savedAddress: session.savedAddress,
        );
      }
      return user;
    }
    _throw(response);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/change-password/'),
      body: {
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
    if (response.statusCode != 200) {
      _throw(response);
    }
  }

  Future<void> forgotPassword(String email) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/forgot-password/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {'email': email.trim()},
    );
    if (response.statusCode != 200) {
      _throw(response);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/reset-password/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {
        'token': token.trim(),
        'new_password': newPassword,
      },
    );
    if (response.statusCode != 200) {
      _throw(response);
    }
  }

  Future<List<StoreModel>> fetchStores({double? lat, double? lng}) async {
    try {
      final params = <String, String>{};
      if (lat != null && lng != null) {
        params['lat'] = lat.toString();
        params['lng'] = lng.toString();
      }
      final response = await _dispatch('GET', _uri('/stores/', params));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching stores: $e');
    }
    return [];
  }


  Future<List<CategoryModel>> fetchCategories({int? storeId}) async {
    try {
      final params = <String, String>{};
      if (storeId != null) params['store'] = storeId.toString();

      final response = await _dispatch('GET', _uri('/categories/', params));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
    return [];
  }

  Future<List<ProductModel>> fetchProducts({
    int? storeId,
    int? categoryId,
    String? search,
  }) async {
    final params = <String, String>{};
    if (storeId != null) params['store'] = storeId.toString();

    final response = await _dispatch('GET', _uri('/products/', params.isNotEmpty ? params : null));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      var products = list.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();

      if (categoryId != null) {
        products = products.where((p) => p.categoryId == categoryId).toList();
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        products = products.where((p) => p.name.toLowerCase().contains(q) || (p.barcode?.contains(q) ?? false)).toList();
      }
      return products;
    }
    _throw(response);
  }

  Future<CustomerOrder> placeOrder({
    required int ownerId,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    String notes = '',
    required List<CustomerOrderItem> items,
  }) async {
    final response = await _dispatch(
      'POST',
      _uri('/orders/'),
      body: {
        'owner': ownerId,
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone.trim(),
        'customer_address': customerAddress.trim(),
        'notes': notes.trim(),
        'items_data': items.map((e) => e.toJson()).toList(),
      },
    );
    if (response.statusCode == 201) {
      return CustomerOrder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    _throw(response);
  }

  Future<List<CustomerOrder>> fetchMyOrders() async {
    final response = await _dispatch('GET', _uri('/orders/'));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => CustomerOrder.fromJson(e as Map<String, dynamic>)).toList();
    }
    _throw(response);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    try {
      await _dispatch(
        'POST',
        _uri('/auth/fcm-token/'),
        body: {'fcm_token': fcmToken},
      );
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
  }

  Future<void> clearFcmToken() async {
    try {
      await _dispatch('POST', _uri('/auth/clear-fcm-token/'));
    } catch (_) {}
  }

  // ---------- Chat & Messaging ----------

  Future<List<Map<String, dynamic>>> fetchMessages(int storeOwnerId) async {
    final response = await _dispatch('GET', _uri('/messages/', {'with_user': storeOwnerId.toString()}));
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    _throw(response);
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
      final req = http.MultipartRequest('POST', uri);
      if (accessToken != null && accessToken!.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $accessToken';
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

      try {
        final streamedResponse = await req.send().timeout(const Duration(seconds: 25));
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 401 && await _refreshAccessToken()) {
          final retryReq = http.MultipartRequest('POST', uri);
          if (accessToken != null && accessToken!.isNotEmpty) {
            retryReq.headers['Authorization'] = 'Bearer $accessToken';
          }
          retryReq.headers['Accept'] = 'application/json';
          retryReq.fields['recipient'] = recipientId.toString();
          if (message != null && message.trim().isNotEmpty) {
            retryReq.fields['message'] = message.trim();
          }
          if (orderId != null) {
            retryReq.fields['order'] = orderId.toString();
          }
          retryReq.files.add(
            http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
          );
          final retryStream = await retryReq.send().timeout(const Duration(seconds: 25));
          final retryResponse = await http.Response.fromStream(retryStream);
          if (retryResponse.statusCode != 201) _throw(retryResponse);
          return jsonDecode(retryResponse.body) as Map<String, dynamic>;
        }
        if (response.statusCode != 201) _throw(response);
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException('Failed to send image message: $e');
      }
    } else {
      final body = <String, dynamic>{
        'recipient': recipientId,
        'message': message ?? '',
      };
      if (orderId != null) body['order'] = orderId;
      final response = await _dispatch('POST', _uri('/messages/'), body: body);
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _throw(response);
    }
  }

  Future<bool> checkBlockStatus(int storeOwnerId) async {
    try {
      final response = await _dispatch('GET', _uri('/messages/block-status/', {'customer_id': storeOwnerId.toString()}));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['is_blocked'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> submitReport({
    required int reportedUserId,
    required String reason,
    required String description,
    int? orderId,
    List<int>? attachmentBytes,
    String filename = 'report_attachment.jpg',
  }) async {
    if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      final uri = _uri('/reports/');
      http.MultipartRequest buildRequest(String? token) {
        final req = http.MultipartRequest('POST', uri);
        if (token != null && token.isNotEmpty) {
          req.headers['Authorization'] = 'Bearer $token';
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
        var streamed = await buildRequest(accessToken).send().timeout(const Duration(seconds: 25));
        var response = await http.Response.fromStream(streamed);
        if (response.statusCode == 401 && await _refreshAccessToken()) {
          streamed = await buildRequest(accessToken).send().timeout(const Duration(seconds: 25));
          response = await http.Response.fromStream(streamed);
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
      final response = await _dispatch('POST', _uri('/reports/'), body: body);
      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      _throw(response);
    }
  }
}
