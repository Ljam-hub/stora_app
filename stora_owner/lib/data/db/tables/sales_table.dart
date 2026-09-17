import 'package:drift/drift.dart';

@DataClassName('SaleRow')
class Sales extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get total => real()();
  RealColumn get cashTendered => real().nullable()();
  RealColumn get changeAmount => real().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get receiptNumber => text().nullable()();
  IntColumn get orderId => integer().nullable()();
  TextColumn get channel => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SaleItemRow')
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productName => text()();
  RealColumn get productPrice => real()();
  IntColumn get quantity => integer()();
}
