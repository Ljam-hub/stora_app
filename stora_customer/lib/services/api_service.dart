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

    try {
      var response = await _executeRequest(method, uri, reqHeaders, encoded, timeout);
      if (response.statusCode == 401 && retryOn401 && accessToken != null) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          final retryHeaders = headers ?? _headers;
          response = await _executeRequest(method, uri, retryHeaders, encoded, timeout);
        }
      }
      return response;
    } on TimeoutException {
      throw ApiException('Server request timed out. Is the backend running at $baseUrl?');
    } on SocketException {
      throw ApiException('Cannot reach backend server. Please check your network connection.');
    } on http.ClientException catch (e) {
      debugPrint('ClientException intercepted: $e');
      throw ApiException('Connection failed: Unable to reach $baseUrl.');
    } on FormatException {
      throw ApiException('Invalid response received from server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dispatch(
      'POST',
      _uri('/auth/login/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: {'email': email.trim(), 'password': password},
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

  Future<List<StoreModel>> fetchStores() async {
    try {
      final response = await _dispatch('GET', _uri('/stores/'));
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
}
