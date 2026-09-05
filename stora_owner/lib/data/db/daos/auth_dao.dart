import 'package:drift/drift.dart';

import '../stora_database.dart';

/// Data Access Object for authentication session operations.
class AuthDao {
  AuthDao(this._db);
  final AppDatabase _db;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String email,
    required String businessName,
  }) {
    return _db.into(_db.authSessions).insertOnConflictUpdate(
      AuthSessionsCompanion(
        id: const Value(1),
        accessToken: Value(accessToken),
        refreshToken: Value(refreshToken),
        email: Value(email),
        businessName: Value(businessName),
      ),
    );
  }

  Future<AuthSession?> readSession() {
    return (_db.select(_db.authSessions)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
  }

  Future<String?> readAccessToken() async {
    final session = await readSession();
    return session?.accessToken;
  }

  Future<void> clearSession() async {
    await _db.delete(_db.authSessions).go();
    await _db.delete(_db.syncQueueEntries).go();
    await _db.delete(_db.saleItems).go();
    await _db.delete(_db.sales).go();
    await _db.delete(_db.products).go();
    await _db.delete(_db.categories).go();
  }
}
