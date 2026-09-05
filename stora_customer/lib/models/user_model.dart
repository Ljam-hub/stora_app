class UserModel {
  final int id;
  final String email;
  final String name;
  final String role;
  final bool isPremium;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'customer',
    this.isPremium = false,
  });

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (email.contains('@')) return email.split('@').first;
    return 'Customer';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      email: (json['email'] as String?) ?? '',
      name: (json['business_name'] as String?) ?? (json['name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'customer',
      isPremium: json['is_premium'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'business_name': name,
      'role': role,
      'is_premium': isPremium,
    };
  }
}
