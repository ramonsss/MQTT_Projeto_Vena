import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/outbox_table.dart';

part 'outbox_dao.g.dart';

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  // Append a new pending action.
  Future<int> insertAction(OutboxCompanion entry) =>
      into(outbox).insert(entry);

  // Stream of all un-synced rows, ordered by creation time.
  Stream<List<OutboxData>> watchPending() =>
      (select(outbox)
            ..where((t) => t.synced.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  // Mark a row as successfully synced.
  Future<void> markSynced(int id) =>
      (update(outbox)..where((t) => t.id.equals(id))).write(
        const OutboxCompanion(synced: Value(true)),
      );
}
