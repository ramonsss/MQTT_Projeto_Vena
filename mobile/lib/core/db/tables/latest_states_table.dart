import 'package:drift/drift.dart';

// 1 row per device; overwritten on each new reading
class LatestStates extends Table {
  TextColumn get deviceId => text()();
  IntColumn get ts => integer()();
  RealColumn get ambientT => real().nullable()();
  RealColumn get ambientH => real().nullable()();
  RealColumn get dissT => real().nullable()();
  RealColumn get dissH => real().nullable()();
  RealColumn get setpoint => real().nullable()();
  RealColumn get pidOut => real().nullable()();
  TextColumn get source => text().withDefault(const Constant('mqtt'))();
  BoolColumn get online =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {deviceId};
}
