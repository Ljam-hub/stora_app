import '../stora_database.dart';

/// Data Access Object for category operations.
class CategoryDao {
  CategoryDao(this._db);
  final AppDatabase _db;

  Future<List<CategoryRow>> loadCategories() => _db.select(_db.categories).get();

  Future<void> replaceCategories(List<CategoriesCompanion> items) async {
    await _db.transaction(() async {
      await _db.delete(_db.categories).go();
      for (final item in items) {
        await _db.into(_db.categories).insert(item);
      }
    });
  }

  Future<void> upsertCategory(CategoriesCompanion item) {
    return _db.into(_db.categories).insertOnConflictUpdate(item);
  }

  Future<void> deleteCategory(String id) {
    return (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}
