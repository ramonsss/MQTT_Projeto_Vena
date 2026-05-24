import 'package:drift/drift.dart';

// Non-sensitive session metadata (email, userId).
// Tokens go in flutter_secure_storage, NOT here.
class UserSession extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
