// T7 — OutboxWorker: pending entries → API called → marked synced.
//       On 409 conflict, entry is still marked synced (server wins).

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/db/app_database.dart';
import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/core/sync/outbox_worker.dart';

class _MockDeviceApi extends Mock implements DeviceApi {}

void main() {
  late AppDatabase db;
  late _MockDeviceApi mockApi;
  late OutboxWorker worker;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    mockApi = _MockDeviceApi();
    worker = OutboxWorker(db: db, deviceApi: mockApi);
  });

  tearDown(() async {
    worker.stop();
    await db.close();
  });

  Future<void> insertPending({
    required String action,
    required String payload,
  }) =>
      db.outboxDao.insertAction(OutboxCompanion.insert(
        action: action,
        payload: payload,
        createdAt: DateTime.now(),
      ));

  Future<void> pump() => Future.delayed(const Duration(milliseconds: 80));

  group('T7 – OutboxWorker', () {
    test('rename entry calls updateAlias and is marked synced', () async {
      when(() => mockApi.updateAlias('dev1', 'New Name'))
          .thenAnswer((_) async {});

      await insertPending(
        action: 'rename',
        payload: '{"device_id":"dev1","alias":"New Name"}',
      );

      worker.start();
      await pump();

      verify(() => mockApi.updateAlias('dev1', 'New Name')).called(1);
      final pending = await db.outboxDao.watchPending().first;
      expect(pending, isEmpty);
    });

    test('claim entry calls claimDevice and is marked synced', () async {
      when(() => mockApi.claimDevice('dev2', 'PAIR123'))
          .thenAnswer((_) async {});

      await insertPending(
        action: 'claim',
        payload: '{"device_id":"dev2","pairing_code":"PAIR123"}',
      );

      worker.start();
      await pump();

      verify(() => mockApi.claimDevice('dev2', 'PAIR123')).called(1);
      final pending = await db.outboxDao.watchPending().first;
      expect(pending, isEmpty);
    });

    test('409 conflict marks entry synced without additional retry', () async {
      when(() => mockApi.updateAlias('dev1', 'Conflicted'))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 409,
        ),
        type: DioExceptionType.badResponse,
      ));

      await insertPending(
        action: 'rename',
        payload: '{"device_id":"dev1","alias":"Conflicted"}',
      );

      worker.start();
      await pump();

      // server wins: entry is gone from the pending queue
      final pending = await db.outboxDao.watchPending().first;
      expect(pending, isEmpty);
    });

    test('multiple pending entries are all processed and marked synced',
        () async {
      when(() => mockApi.updateAlias('dev1', 'First'))
          .thenAnswer((_) async {});
      when(() => mockApi.updateAlias('dev1', 'Second'))
          .thenAnswer((_) async {});

      await insertPending(
        action: 'rename',
        payload: '{"device_id":"dev1","alias":"First"}',
      );
      await insertPending(
        action: 'rename',
        payload: '{"device_id":"dev1","alias":"Second"}',
      );

      worker.start();
      await pump();

      // Both aliases must have been sent to the API at least once
      verify(() => mockApi.updateAlias('dev1', 'First'))
          .called(greaterThanOrEqualTo(1));
      verify(() => mockApi.updateAlias('dev1', 'Second'))
          .called(greaterThanOrEqualTo(1));

      // DB must be empty (all entries marked synced)
      final pending = await db.outboxDao.watchPending().first;
      expect(pending, isEmpty);
    });
  });
}
