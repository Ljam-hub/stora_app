import 'package:drift/drift.dart';

class AuthSessions extends Table {
  IntColumn get id => integer()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  TextColumn get email => text()();
  TextColumn get businessName => text()();
  BoolColumn get isEmailVerified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
