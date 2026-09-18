import '../config/api_config.dart';

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
    };
  }
}

