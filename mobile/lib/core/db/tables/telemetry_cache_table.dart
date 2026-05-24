import 'package:drift/drift.dart';

// Ring buffer — max ~1000 entries per device (pruned externally)
class TelemetryCache extends Table {
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real().nullable()();
  RealColumn get ambientH => real().nullable()();
  RealColumn get dissT => real().nullable()();
  RealColumn get dissH => real().nullable()();

  @override
  Set<Column> get primaryKey => {deviceId, ts};
}
