import 'package:drift/drift.dart';

@DataClassName('SaleRow')
class Sales extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  RealColumn get total => real()();

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
