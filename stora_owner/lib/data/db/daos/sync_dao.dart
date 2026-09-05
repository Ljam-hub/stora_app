import 'package:drift/drift.dart';

import '../stora_database.dart';
import '../../../home/models/product.dart';

/// Data Access Object for the offline sync queue.
class SyncDao {
  SyncDao(this._db);
  final AppDatabase _db;

  Future<void> enqueueSync({
    required String entityType,
    required String action,
    required String entityId,
    String? payload,
  }) async {
    await _db.transaction(() async {
      if (entityType == 'product') {
        if (action == 'delete') {
          if (entityId.startsWith('local-')) {
            await (_db.delete(_db.syncQueueEntries)
                  ..where((t) =>
                      t.entityType.equals('product') &
                      t.entityId.equals(entityId)))
                .go();
            return;
          } else {
            await (_db.delete(_db.syncQueueEntries)
                  ..where((t) =>
                      t.entityType.equals('product') &
                      t.entityId.equals(entityId)))
                .go();
          }
        } else if (action == 'update') {
          final existing = await (_db.select(_db.syncQueueEntries)
                ..where((t) =>
                    t.entityType.equals('product') &
                    t.entityId.equals(entityId)))
              .getSingleOrNull();
          if (existing != null) {
            await (_db.update(_db.syncQueueEntries)
                  ..where((t) => t.id.equals(existing.id)))
                .write(
              SyncQueueEntriesCompanion(
                payload: Value(payload),
              ),
            );
            return;
          }
        }
      }

      await _db.into(_db.syncQueueEntries).insert(
        SyncQueueEntriesCompanion(
          entityType: Value(entityType),
          action: Value(action),
          entityId: Value(entityId),
          payload: Value(payload),
          createdAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<List<SyncQueueEntry>> getPendingSyncEntries() {
    return (_db.select(_db.syncQueueEntries)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Future<void> removeSyncEntry(int id) {
    return (_db.delete(_db.syncQueueEntries)..where((t) => t.id.equals(id)))
        .go();
  }

  Future<void> reconcileProductId(
      String oldLocalId, Product serverProduct) async {
    await _db.transaction(() async {
      await (_db.delete(_db.products)..where((t) => t.id.equals(oldLocalId)))
          .go();
      await _db.productDao.upsertProduct(serverProduct);

      await (_db.update(_db.syncQueueEntries)
            ..where((t) =>
                t.entityType.equals('product') &
                t.entityId.equals(oldLocalId)))
          .write(SyncQueueEntriesCompanion(
              entityId: Value(serverProduct.id)));

      final saleEntries = await (_db.select(_db.syncQueueEntries)
            ..where((t) => t.entityType.equals('sale')))
          .get();
      for (final entry in saleEntries) {
        if (entry.payload != null &&
            entry.payload!.contains(oldLocalId)) {
          final updatedPayload =
              entry.payload!.replaceAll(oldLocalId, serverProduct.id);
          await (_db.update(_db.syncQueueEntries)
                ..where((t) => t.id.equals(entry.id)))
              .write(
            SyncQueueEntriesCompanion(payload: Value(updatedPayload)),
          );
        }
      }
    });
  }
}
