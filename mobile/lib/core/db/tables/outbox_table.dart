import 'package:drift/drift.dart';

// Pending writes to the backend (rename, claim, etc.)
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()(); // "claim" | "rename"
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced =>
      boolean().withDefault(const Constant(false))();
}
