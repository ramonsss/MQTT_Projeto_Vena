// T8 — historyProvider: calls API with correct range/bucket params,
//       returns samples from HistoryResponse envelope.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:vena_app/core/network/device_api.dart';
import 'package:vena_app/core/network/models/telemetry_point.dart';
import 'package:vena_app/features/history/application/history_provider.dart';

class _MockDeviceApi extends Mock implements DeviceApi {}

HistoryResponse _envelope(List<TelemetryPoint> samples, {String range = '24h'}) =>
    HistoryResponse(
      deviceId: 'dev1',
      count: samples.length,
      samples: samples,
      bucket: range == '1h' ? '5s' : '1m',
    );

void main() {
  late _MockDeviceApi mockApi;

  setUp(() => mockApi = _MockDeviceApi());

  ProviderContainer buildContainer() => ProviderContainer(
        overrides: [
          deviceApiProvider.overrideWithValue(mockApi),
          // No Drift DB in unit tests — provider gracefully skips cache layer.
          historyCacheDaoProvider.overrideWithValue(null),
        ],
      );

  group('T8 – historyProvider (Phase 5)', () {
    test('returns samples from the API for h24 range', () async {
      final fakePoints = [
        const TelemetryPoint(ts: 1000, ambientT: 20.0),
        const TelemetryPoint(ts: 1060, ambientT: 20.5),
      ];

      when(() => mockApi.fetchHistoryResponse(
            any(),
            range: any(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => _envelope(fakePoints));

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(historyProvider('dev1', HistoryRange.h24).future);

      expect(result.length, 2);
      expect(result.first.ambientT, 20.0);
    });

    test('passes correct range param for each HistoryRange', () async {
      when(() => mockApi.fetchHistoryResponse(
            any(),
            range: any(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => _envelope(const []));

      final container = buildContainer();
      addTearDown(container.dispose);

      for (final r in HistoryRange.values) {
        await container.read(historyProvider('dev1', r).future);
      }

      final captured = verify(() => mockApi.fetchHistoryResponse(
            'dev1',
            range: captureAny(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).captured;

      expect(captured, ['1h', '24h', '7d', '30d']);
    });

    test('returns empty list when API returns no samples', () async {
      when(() => mockApi.fetchHistoryResponse(
            any(),
            range: any(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => _envelope(const []));

      final container = buildContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(historyProvider('dev1', HistoryRange.h24).future);

      expect(result, isEmpty);
    });

    test('h1 and h24 for same device are independent providers', () async {
      when(() => mockApi.fetchHistoryResponse(
            any(),
            range: any(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => _envelope(const []));

      final container = buildContainer();
      addTearDown(container.dispose);

      await Future.wait([
        container.read(historyProvider('dev1', HistoryRange.h1).future),
        container.read(historyProvider('dev1', HistoryRange.h24).future),
      ]);

      verify(() => mockApi.fetchHistoryResponse(
            'dev1',
            range: any(named: 'range'),
            bucket: any(named: 'bucket'),
            metric: any(named: 'metric'),
            start: any(named: 'start'),
            end: any(named: 'end'),
            limit: any(named: 'limit'),
          )).called(2);
    });
  });
}
