import 'package:drift/drift.dart';

class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get alias => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('offline'))();
  IntColumn get lastSeenAt => integer().nullable()();
  TextColumn get fwVersion => text().nullable()();
  // v2: what the user stores inside this Vena unit (local-only, no backend sync).
  TextColumn get storedContent => text().nullable()();

  @override
  Set<Column> get primaryKey => {deviceId};
}
