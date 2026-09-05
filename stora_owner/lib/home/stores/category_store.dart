import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_client.dart';
import '../../data/db/stora_database.dart';

class CategoryStore extends ChangeNotifier {
  CategoryStore._internal();
  static final CategoryStore instance = CategoryStore._internal();

  final _db = AppDatabase.instance;
  final _api = ApiClient.instance;

  final List<CategoryRow> _categories = [];

  List<String> get categories =>
      List.unmodifiable(_categories.map((c) => c.name));

  List<String> get visibleCategories =>
      _categories.where((c) => !c.isHidden).map((c) => c.name).toList();

  bool isHidden(String name) =>
      _categories.any((c) => c.name == name && c.isHidden);

  CategoryRow? _byName(String name) {
    for (final category in _categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }
    return null;
  }

  Future<void> loadCategories() async {
    _categories
      ..clear()
      ..addAll(await _db.categoryDao.loadCategories());
    notifyListeners();
    try {
      final remote = await _api.listCategories();
      final rows = remote
          .map(
            (json) => CategoryRow(
              id: json['id'].toString(),
              name: json['name'] as String,
              isHidden: json['is_hidden'] as bool? ?? false,
            ),
          )
          .toList();
      _categories
        ..clear()
        ..addAll(rows);
      await _db.categoryDao.replaceCategories(
        rows
            .map(
              (row) => CategoriesCompanion(
                id: Value(row.id),
                name: Value(row.name),
                isHidden: Value(row.isHidden),
              ),
            )
            .toList(),
      );
    } catch (_) {
      // Keep the cached Drift rows when the API is unreachable.
    }
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_byName(trimmed) != null) return;
    try {
      final json = await _api.createCategory(trimmed);
      final row = CategoryRow(
        id: json['id'].toString(),
        name: json['name'] as String,
        isHidden: json['is_hidden'] as bool? ?? false,
      );
      _categories.add(row);
      await _db.categoryDao.upsertCategory(
        CategoriesCompanion(
          id: Value(row.id),
          name: Value(row.name),
          isHidden: Value(row.isHidden),
        ),
      );
    } catch (_) {
      // Product save still sends category_name; the API will get-or-create.
      _categories.add(CategoryRow(id: 'local-$trimmed', name: trimmed, isHidden: false));
    }
    notifyListeners();
  }

  Future<void> removeCategory(String name) async {
    final existing = _byName(name);
    if (existing == null) return;
    try {
      if (!existing.id.startsWith('local-')) {
        await _api.deleteCategory(existing.id);
      }
    } catch (_) {}
    _categories.removeWhere((c) => c.id == existing.id);
    await _db.categoryDao.deleteCategory(existing.id);
    notifyListeners();
  }

  Future<void> toggleHidden(String name) async {
    final existing = _byName(name);
    if (existing == null) return;
    final next = CategoryRow(id: existing.id, name: existing.name, isHidden: !existing.isHidden);
    try {
      if (!existing.id.startsWith('local-')) {
        await _api.patchCategory(existing.id, {'is_hidden': next.isHidden});
      }
    } catch (_) {}
    final idx = _categories.indexWhere((c) => c.id == existing.id);
    if (idx != -1) _categories[idx] = next;
    await _db.categoryDao.upsertCategory(
      CategoriesCompanion(
        id: Value(next.id),
        name: Value(next.name),
        isHidden: Value(next.isHidden),
      ),
    );
    notifyListeners();
  }

  void reset() {
    _categories.clear();
    notifyListeners();
  }
}
