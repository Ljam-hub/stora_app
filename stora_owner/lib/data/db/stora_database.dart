import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Table imports
import 'tables/products_table.dart';
import 'tables/categories_table.dart';
import 'tables/sales_table.dart';
import 'tables/auth_sessions_table.dart';
import 'tables/sync_queue_table.dart';

// DAO imports
import 'daos/auth_dao.dart';
import 'daos/product_dao.dart';
import 'daos/category_dao.dart';
import 'daos/sales_dao.dart';
import 'daos/sync_dao.dart';

// Re-export tables so callers that import stora_database.dart still see
// generated row/companion classes (ProductRow, CategoryRow, etc.)
export 'tables/products_table.dart';
export 'tables/categories_table.dart';
export 'tables/sales_table.dart';
export 'tables/auth_sessions_table.dart';
export 'tables/sync_queue_table.dart';

// Re-export DAOs for convenient access
export 'daos/auth_dao.dart';
export 'daos/product_dao.dart';
export 'daos/category_dao.dart';
export 'daos/sales_dao.dart';
export 'daos/sync_dao.dart';

part 'stora_database.g.dart';

@DriftDatabase(
  tables: [Products, Categories, Sales, SaleItems, AuthSessions, SyncQueueEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 1;

  // ── DAOs ──────────────────────────────────────────────────────────────
  late final AuthDao authDao = AuthDao(this);
  late final ProductDao productDao = ProductDao(this);
  late final CategoryDao categoryDao = CategoryDao(this);
  late final SalesDao salesDao = SalesDao(this);
  late final SyncDao syncDao = SyncDao(this);

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'stora.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
