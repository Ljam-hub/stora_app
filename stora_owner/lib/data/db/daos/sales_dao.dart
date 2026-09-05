import 'package:drift/drift.dart';

import '../stora_database.dart';
import '../../../home/models/cart_item.dart';
import '../../../home/models/product.dart';
import '../../../home/models/sale.dart';

/// Data Access Object for sales and sale-item operations.
class SalesDao {
  SalesDao(this._db);
  final AppDatabase _db;

  Future<List<Sale>> loadSales() async {
    final saleRows = await (_db.select(_db.sales)
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();
    final itemRows = await _db.select(_db.saleItems).get();
    final bySale = <String, List<SaleItemRow>>{};
    for (final row in itemRows) {
      bySale.putIfAbsent(row.saleId, () => []).add(row);
    }
    return saleRows.map((sale) {
      final lines = bySale[sale.id] ?? const <SaleItemRow>[];
      return Sale(
        id: sale.id,
        date: sale.date,
        total: sale.total,
        items: lines
            .map(
              (line) => CartItem(
                product: Product(
                  id: '',
                  name: line.productName,
                  category: '',
                  price: line.productPrice,
                  stock: 0,
                ),
                quantity: line.quantity,
              ),
            )
            .toList(),
      );
    }).toList();
  }

  Future<void> replaceSales(List<Sale> items) async {
    await _db.transaction(() async {
      await _db.delete(_db.saleItems).go();
      await _db.delete(_db.sales).go();
      for (final sale in items) {
        await _insertSale(sale);
      }
    });
  }

  Future<void> upsertSale(Sale sale) async {
    await _db.transaction(() async {
      await (_db.delete(_db.saleItems)
            ..where((t) => t.saleId.equals(sale.id)))
          .go();
      await (_db.delete(_db.sales)..where((t) => t.id.equals(sale.id))).go();
      await _insertSale(sale);
    });
  }

  Future<void> deleteSale(String id) async {
    await (_db.delete(_db.saleItems)..where((t) => t.saleId.equals(id))).go();
    await (_db.delete(_db.sales)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearSales() async {
    await _db.delete(_db.saleItems).go();
    await _db.delete(_db.sales).go();
  }

  Future<void> _insertSale(Sale sale) async {
    await _db.into(_db.sales).insert(
      SalesCompanion(
        id: Value(sale.id),
        date: Value(sale.date),
        total: Value(sale.total),
      ),
    );
    for (final item in sale.items) {
      await _db.into(_db.saleItems).insert(
        SaleItemsCompanion.insert(
          saleId: sale.id,
          productName: item.product.name,
          productPrice: item.product.price,
          quantity: item.quantity,
        ),
      );
    }
  }
}
