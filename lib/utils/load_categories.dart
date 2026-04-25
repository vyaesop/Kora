import 'package:flutter/material.dart';

class LoadCategoryDefinition {
  final String category;
  final List<String> subcategories;
  final Color accent;

  const LoadCategoryDefinition({
    required this.category,
    required this.subcategories,
    required this.accent,
  });
}

const List<LoadCategoryDefinition> loadCategoryCatalog = [
  LoadCategoryDefinition(
    category: 'Agriculture',
    subcategories: [
      'Grain',
      'Vegetables',
      'Fruits',
      'Coffee',
      'Khat',
      'Flowers',
      'Animal feed',
    ],
    accent: Color(0xFF4D8B5B),
  ),
  LoadCategoryDefinition(
    category: 'Livestock',
    subcategories: ['Cattle', 'Sheep & goats', 'Chicken', 'Eggs', 'Milk'],
    accent: Color(0xFF9A6C3B),
  ),
  LoadCategoryDefinition(
    category: 'Construction',
    subcategories: [
      'Sand & gravel',
      'Bricks',
      'Wood',
      'Cement',
      'Steel',
      'Textile',
    ],
    accent: Color(0xFF64748B),
  ),
  LoadCategoryDefinition(
    category: 'Retail',
    subcategories: ['Food & beverage', 'Household goods', 'Electronics'],
    accent: Color(0xFF2563EB),
  ),
  LoadCategoryDefinition(
    category: 'Liquids',
    subcategories: ['Diesel', 'Petrol', 'Edible oil', 'Chemicals'],
    accent: Color(0xFF0F766E),
  ),
];

const Map<String, String> _legacyTypeCategoryMap = {
  'coffee': 'Agriculture',
  'livestock': 'Livestock',
  'construction materials': 'Construction',
  'food': 'Retail',
  'fuel': 'Liquids',
};

LoadCategoryDefinition? loadCategoryByName(String? category) {
  if (category == null || category.trim().isEmpty) {
    return null;
  }
  final normalized = category.trim().toLowerCase();
  for (final definition in loadCategoryCatalog) {
    if (definition.category.toLowerCase() == normalized) {
      return definition;
    }
  }
  return null;
}

String? inferLoadCategory({String? category, String? subtype}) {
  if (category != null && category.trim().isNotEmpty) {
    return loadCategoryByName(category)?.category ?? category.trim();
  }

  final normalizedSubtype = subtype?.trim().toLowerCase();
  if (normalizedSubtype == null || normalizedSubtype.isEmpty) {
    return null;
  }

  for (final definition in loadCategoryCatalog) {
    for (final item in definition.subcategories) {
      if (item.toLowerCase() == normalizedSubtype) {
        return definition.category;
      }
    }
  }

  return _legacyTypeCategoryMap[normalizedSubtype];
}

List<String> subcategoriesFor(String? category) {
  return loadCategoryByName(category)?.subcategories ?? const <String>[];
}

String displayLoadType({String? category, String? subtype}) {
  final resolvedCategory = inferLoadCategory(
    category: category,
    subtype: subtype,
  );
  final cleanSubtype = subtype?.trim() ?? '';

  if (resolvedCategory == null || resolvedCategory.isEmpty) {
    return cleanSubtype.isEmpty ? 'General goods' : cleanSubtype;
  }
  if (cleanSubtype.isEmpty ||
      cleanSubtype.toLowerCase() == resolvedCategory.toLowerCase()) {
    return resolvedCategory;
  }
  return '$resolvedCategory / $cleanSubtype';
}

bool loadMatchesCategoryFilter({
  required String? category,
  required String? subtype,
  required String selectedCategory,
  required String selectedSubtype,
}) {
  final resolvedCategory = inferLoadCategory(
    category: category,
    subtype: subtype,
  );
  final cleanSubtype = subtype?.trim().toLowerCase() ?? '';

  if (selectedCategory != 'All' &&
      (resolvedCategory == null ||
          resolvedCategory.toLowerCase() != selectedCategory.toLowerCase())) {
    return false;
  }

  if (selectedSubtype != 'All' &&
      cleanSubtype != selectedSubtype.toLowerCase()) {
    return false;
  }

  return true;
}
