class StoreModel {
  final int id;
  final String businessName;
  final String email;
  final double latitude;
  final double longitude;
  final String address;
  final double? distanceKm;
  final String? avatarUrl;

  StoreModel({
    required this.id,
    required this.businessName,
    required this.email,
    this.latitude = 14.5995,
    this.longitude = 120.9842,
    this.address = '',
    this.distanceKm,
    this.avatarUrl,
  });

  String get displayName {
    if (businessName.trim().isNotEmpty) return businessName.trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Store #$id';
  }

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      businessName: (json['business_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : 14.5995,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : 120.9842,
      address: (json['address'] as String?) ?? '',
      distanceKm: json['distance_km'] is num ? (json['distance_km'] as num).toDouble() : null,
      avatarUrl: (json['avatar_url'] as String?),
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
    };
  }
}

