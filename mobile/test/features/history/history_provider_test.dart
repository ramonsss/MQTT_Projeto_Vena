// T8 — historyProvider: calls API with correct range; returns list.
//       Verifies time window calculation for each HistoryRange value.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/core/network/models/telemetry_point.dart';
import 'package:vena_app/features/history/application/history_provider.dart';

class _MockDeviceApi extends Mock implements DeviceApi {}

void main() {
  late _MockDeviceApi mockApi;

  setUp(() => mockApi = _MockDeviceApi());

  ProviderContainer buildContainer() => ProviderContainer(
        overrides: [deviceApiProvider.overrideWithValue(mockApi)],
      );

  group('T8 – historyProvider', () {
    test('returns points from the API for h24 range', () async {
      final fakePoints = [
        const TelemetryPoint(ts: 1000, ambientT: 20.0),
        const TelemetryPoint(ts: 1060, ambientT: 20.5),
      ];

      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => fakePoints);

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(historyProvider('dev1', HistoryRange.h24).future);

      expect(result.length, 2);
      expect(result.first.ambientT, 20.0);
    });

    test('passes correct 24-hour window to the API', () async {
      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(historyProvider('dev1', HistoryRange.h24).future);

      final captured = verify(() => mockApi.getHistory(
            'dev1',
            start: captureAny(named: 'start'),
            end: captureAny(named: 'end'),
            limit: any(named: 'limit'),
          )).captured;

      final start = captured[0] as int;
      final end = captured[1] as int;
      final diff = end - start;

      expect(end, greaterThanOrEqualTo(before));
      // 24h = 86400s, allow 5s tolerance for test execution time
      expect(diff, closeTo(24 * 3600, 5));
    });

    test('passes correct 7-day window to the API', () async {
      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      final container = buildContainer();
      addTearDown(container.dispose);

      await container.read(historyProvider('dev1', HistoryRange.d7).future);

      final captured = verify(() => mockApi.getHistory(
            'dev1',
            start: captureAny(named: 'start'),
            end: captureAny(named: 'end'),
            limit: any(named: 'limit'),
          )).captured;

      final diff = (captured[1] as int) - (captured[0] as int);
      expect(diff, closeTo(7 * 24 * 3600, 5));
    });

    test('passes correct 30-day window to the API', () async {
      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      final container = buildContainer();
      addTearDown(container.dispose);

      await container
          .read(historyProvider('dev1', HistoryRange.d30).future);

      final captured = verify(() => mockApi.getHistory(
            'dev1',
            start: captureAny(named: 'start'),
            end: captureAny(named: 'end'),
            limit: any(named: 'limit'),
          )).captured;

      final diff = (captured[1] as int) - (captured[0] as int);
      expect(diff, closeTo(30 * 24 * 3600, 5));
    });

    test('returns empty list when API returns no data', () async {
      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(historyProvider('dev1', HistoryRange.h24).future);

      expect(result, isEmpty);
    });

    test('h24 and d7 for same device are independent providers', () async {
      when(() => mockApi.getHistory(
            any(),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      final container = buildContainer();
      addTearDown(container.dispose);

      await Future.wait([
        container.read(historyProvider('dev1', HistoryRange.h24).future),
        container.read(historyProvider('dev1', HistoryRange.d7).future),
      ]);

      // Two separate API calls: one for h24, one for d7
      verify(() => mockApi.getHistory(
            'dev1',
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).called(2);
    });
  });
}
