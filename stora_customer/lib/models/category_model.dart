class CategoryModel {
  final int id;
  final String name;
  final bool isHidden;

  CategoryModel({
    required this.id,
    required this.name,
    this.isHidden = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      name: (json['name'] as String?) ?? '',
      isHidden: json['is_hidden'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_hidden': isHidden,
    };
  }
}
