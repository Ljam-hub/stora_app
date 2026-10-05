import '../config/api_config.dart';

class StorePaymentAccount {
  final String? id;
  final String label;
  final String accountName;
  final String accountNumber;
  final String? qrCodeUrl;
  final bool isPrimary;
  final bool isActive;

  const StorePaymentAccount({
    this.id,
    this.label = '',
    this.accountName = '',
    this.accountNumber = '',
    this.qrCodeUrl,
    this.isPrimary = false,
    this.isActive = true,
  });

  factory StorePaymentAccount.fromJson(Map<String, dynamic> json) {
    return StorePaymentAccount(
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      accountNumber: json['account_number']?.toString() ?? '',
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1 || json['is_primary'] == 'true',
      isActive: json['is_active'] != false && json['is_active'] != 0 && json['is_active'] != 'false',
      qrCodeUrl: ApiConfig.resolveMediaUrl(json['qr_code_url']?.toString()),
    );
  }
}

class StoreModel {
  final int id;
  final String businessName;
  final String email;
  final double latitude;
  final double longitude;
  final String address;
  final double? distanceKm;
  final String? avatarUrl;
  final bool isOpen;
  final String role;
  final String paymentPhoneNumber;
  final String paymentAccountName;
  final String? paymentQrUrl;
  final bool acceptGcashPayments;
  final bool showSingleAccount;
  final List<StorePaymentAccount> paymentAccounts;

  StoreModel({
    required this.id,
    required this.businessName,
    required this.email,
    this.latitude = 14.5995,
    this.longitude = 120.9842,
    this.address = '',
    this.distanceKm,
    this.avatarUrl,
    this.isOpen = true,
    this.role = 'owner',
    this.paymentPhoneNumber = '',
    this.paymentAccountName = '',
    this.paymentQrUrl,
    this.acceptGcashPayments = true,
    this.showSingleAccount = false,
    this.paymentAccounts = const [],
  });

  String get displayName {
    if (businessName.trim().isNotEmpty) return businessName.trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Store #$id';
  }

  /// Whether the store has an actual custom location set (not the default Manila coordinates or 0,0).
  bool get hasValidLocation {
    if (latitude == 0 && longitude == 0) return false;
    final isDefaultManila = (latitude - 14.5995).abs() < 0.0001 &&
        (longitude - 120.9842).abs() < 0.0001;
    if (isDefaultManila && (address.isEmpty || address == 'Metro Manila, Philippines')) {
      return false;
    }
    return true;
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    List<StorePaymentAccount> accounts = [];
    if (json['payment_accounts'] != null && json['payment_accounts'] is List) {
      accounts = (json['payment_accounts'] as List)
          .map((e) => StorePaymentAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // Fallback
      final phone = (json['payment_phone_number'] as String?) ?? '';
      final name = (json['payment_account_name'] as String?) ?? '';
      final qr = ApiConfig.resolveMediaUrl((json['payment_qr_url'] ?? json['payment_qr_code']) as String?);
      if (phone.isNotEmpty || qr != null) {
        accounts.add(StorePaymentAccount(
          label: 'GCash',
          accountName: name,
          accountNumber: phone,
          qrCodeUrl: qr,
          isPrimary: true,
          isActive: true,
        ));
      }
    }

    final rawShowSingle = json['show_single_account'];
    final showSingle = rawShowSingle == true ||
        rawShowSingle == 1 ||
        rawShowSingle == 'true' ||
        rawShowSingle == '1';

    return StoreModel(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      businessName: (json['business_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : (double.tryParse(json['latitude']?.toString() ?? '14.5995') ?? 14.5995),
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : (double.tryParse(json['longitude']?.toString() ?? '120.9842') ?? 120.9842),
      address: (json['address'] as String?) ?? '',
      distanceKm: json['distance_km'] is num
          ? (json['distance_km'] as num).toDouble()
          : (json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null),
      avatarUrl: ApiConfig.resolveMediaUrl(json['avatar_url'] as String?),
      isOpen: json['is_open'] == false ||
              json['is_open'] == 0 ||
              json['is_open'] == 'false' ||
              json['is_open'] == '0'
          ? false
          : true,
      role: (json['role'] as String?) ?? 'owner',
      paymentPhoneNumber: (json['payment_phone_number'] as String?) ?? '',
      paymentAccountName: (json['payment_account_name'] as String?) ?? '',
      paymentQrUrl: ApiConfig.resolveMediaUrl((json['payment_qr_url'] ?? json['payment_qr_code']) as String?),
      acceptGcashPayments: json['accept_gcash_payments'] == false ||
              json['accept_gcash_payments'] == 0 ||
              json['accept_gcash_payments'] == 'false' ||
              json['accept_gcash_payments'] == '0'
          ? false
          : true,
      showSingleAccount: showSingle,
      paymentAccounts: accounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_name': businessName,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'distance_km': distanceKm,
      'avatar_url': avatarUrl,
      'is_open': isOpen,
      'role': role,
      'payment_phone_number': paymentPhoneNumber,
      'payment_account_name': paymentAccountName,
      'payment_qr_url': paymentQrUrl,
      'accept_gcash_payments': acceptGcashPayments,
    };
  }
}

