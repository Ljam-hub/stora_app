import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// Test-only constructor that accepts an in-memory or custom executor.
  @visibleForTesting
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _safeAddColumn('auth_sessions', 'is_email_verified', 'INTEGER NOT NULL DEFAULT 0');
      }
      if (from < 3) {
        await _safeAddColumn('sales', 'cash_tendered', 'REAL');
        await _safeAddColumn('sales', 'change_amount', 'REAL');
        await _safeAddColumn('sales', 'customer_name', 'TEXT');
        await _safeAddColumn('sales', 'receipt_number', 'TEXT');
        await _safeAddColumn('sales', 'order_id', 'INTEGER');
        await _safeAddColumn('sales', 'channel', 'TEXT');
        await _safeAddColumn('products', 'bio', "TEXT NOT NULL DEFAULT ''");
      }
      if (from < 4) {
        // Databases created at schema v2/v3 had a Drift table definition
        // that was missing is_email_verified, so onCreate never created
        // the column even though raw SQL in AuthDao referenced it.
        await _safeAddColumn('auth_sessions', 'is_email_verified', 'INTEGER NOT NULL DEFAULT 0');
      }
    },
    beforeOpen: (details) async {
      // Defensive safety net: ensure every column exists regardless of the
      // migration path a device went through. This prevents crashes on
      // devices whose database was created at any prior schema version
      // where the Drift table definition was incomplete.
      await _safeAddColumn('auth_sessions', 'is_email_verified', 'INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn('sales', 'cash_tendered', 'REAL');
      await _safeAddColumn('sales', 'change_amount', 'REAL');
      await _safeAddColumn('sales', 'customer_name', 'TEXT');
      await _safeAddColumn('sales', 'receipt_number', 'TEXT');
      await _safeAddColumn('sales', 'order_id', 'INTEGER');
      await _safeAddColumn('sales', 'channel', 'TEXT');
      await _safeAddColumn('products', 'bio', "TEXT NOT NULL DEFAULT ''");
    },
  );

  /// Adds [columnName] to [tableName] only if the column does not already
  /// exist, preventing duplicate-column errors on re-runs.
  Future<void> _safeAddColumn(
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final result = await customSelect(
      'PRAGMA table_info($tableName)',
    ).get();
    final exists = result.any((row) => row.data['name'] == columnName);
    if (!exists) {
      await customStatement(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
      );
    }
  }

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
