/// CategoryModel — data-layer DTO. Knows how to parse JSON from the backend.
library;

import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.emoji,
    required super.type,
    required super.isDefault,
    required super.excludeFromAnalytics,
    required super.createdAt,
    super.monthlyLimit,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      type: json['type'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      excludeFromAnalytics: json['excludeFromAnalytics'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'type': type,
        'isDefault': isDefault,
        'excludeFromAnalytics': excludeFromAnalytics,
        'monthlyLimit': monthlyLimit,
        'createdAt': createdAt.toIso8601String(),
      };
}
