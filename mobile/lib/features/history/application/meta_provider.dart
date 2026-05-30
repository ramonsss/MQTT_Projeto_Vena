// L1 — DeviceMeta provider (Phase 5).
//
// Fetches `GET /devices/{id}/meta` (latest `meta` payload published by the
// ESP32 on boot). Riverpod auto-disposes after 10 minutes since meta is
// near-static between reboots — no need for tight polling.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/device_api.dart';
import '../../../core/network/models/device_meta.dart';

part 'meta_provider.g.dart';

@riverpod
Future<DeviceMeta?> deviceMeta(DeviceMetaRef ref, String deviceId) async {
  final link = ref.keepAlive();
  Future<void>.delayed(const Duration(minutes: 10), link.close);
  return ref.read(deviceApiProvider).getMeta(deviceId);
}
