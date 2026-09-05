import 'package:drift/drift.dart';

@DataClassName('SyncQueueEntry')
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get action => text()();
  TextColumn get entityId => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
