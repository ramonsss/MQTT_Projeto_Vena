// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_worker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$outboxWorkerHash() => r'04a6141945ec62985a1789f205769ae1f519c557';

/// Singleton worker — starts immediately and stays alive for the session.
///
/// Copied from [outboxWorker].
@ProviderFor(outboxWorker)
final outboxWorkerProvider = Provider<OutboxWorker>.internal(
  outboxWorker,
  name: r'outboxWorkerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$outboxWorkerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef OutboxWorkerRef = ProviderRef<OutboxWorker>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
