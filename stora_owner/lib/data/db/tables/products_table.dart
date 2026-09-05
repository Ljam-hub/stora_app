import 'package:drift/drift.dart';

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  RealColumn get price => real()();
  IntColumn get stock => integer()();
  TextColumn get barcode => text().nullable()();
  BlobColumn get imageBytes => blob().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
