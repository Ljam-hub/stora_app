class StoreModel {
  final int id;
  final String businessName;
  final String email;

  StoreModel({
    required this.id,
    required this.businessName,
    required this.email,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_name': businessName,
      'email': email,
    };
  }
}
