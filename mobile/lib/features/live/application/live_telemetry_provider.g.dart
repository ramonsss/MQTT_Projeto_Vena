// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_telemetry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recentCacheHash() => r'5e59e8adcc1a6da686c1a73913eb3e33bf24b265';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Last [limit] telemetry samples for [deviceId], newest-first.
///
/// Automatically refreshes whenever [latestStateProvider] emits a new value,
/// which happens on each incoming MQTT telemetry message.
///
/// Copied from [recentCache].
@ProviderFor(recentCache)
const recentCacheProvider = RecentCacheFamily();

/// Last [limit] telemetry samples for [deviceId], newest-first.
///
/// Automatically refreshes whenever [latestStateProvider] emits a new value,
/// which happens on each incoming MQTT telemetry message.
///
/// Copied from [recentCache].
class RecentCacheFamily extends Family<AsyncValue<List<TelemetryCacheData>>> {
  /// Last [limit] telemetry samples for [deviceId], newest-first.
  ///
  /// Automatically refreshes whenever [latestStateProvider] emits a new value,
  /// which happens on each incoming MQTT telemetry message.
  ///
  /// Copied from [recentCache].
  const RecentCacheFamily();

  /// Last [limit] telemetry samples for [deviceId], newest-first.
  ///
  /// Automatically refreshes whenever [latestStateProvider] emits a new value,
  /// which happens on each incoming MQTT telemetry message.
  ///
  /// Copied from [recentCache].
  RecentCacheProvider call(
    String deviceId, {
    int limit = 60,
  }) {
    return RecentCacheProvider(
      deviceId,
      limit: limit,
    );
  }

  @override
  RecentCacheProvider getProviderOverride(
    covariant RecentCacheProvider provider,
  ) {
    return call(
      provider.deviceId,
      limit: provider.limit,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'recentCacheProvider';
}

/// Last [limit] telemetry samples for [deviceId], newest-first.
///
/// Automatically refreshes whenever [latestStateProvider] emits a new value,
/// which happens on each incoming MQTT telemetry message.
///
/// Copied from [recentCache].
class RecentCacheProvider
    extends AutoDisposeFutureProvider<List<TelemetryCacheData>> {
  /// Last [limit] telemetry samples for [deviceId], newest-first.
  ///
  /// Automatically refreshes whenever [latestStateProvider] emits a new value,
  /// which happens on each incoming MQTT telemetry message.
  ///
  /// Copied from [recentCache].
  RecentCacheProvider(
    String deviceId, {
    int limit = 60,
  }) : this._internal(
          (ref) => recentCache(
            ref as RecentCacheRef,
            deviceId,
            limit: limit,
          ),
          from: recentCacheProvider,
          name: r'recentCacheProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$recentCacheHash,
          dependencies: RecentCacheFamily._dependencies,
          allTransitiveDependencies:
              RecentCacheFamily._allTransitiveDependencies,
          deviceId: deviceId,
          limit: limit,
        );

  RecentCacheProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.deviceId,
    required this.limit,
  }) : super.internal();

  final String deviceId;
  final int limit;

  @override
  Override overrideWith(
    FutureOr<List<TelemetryCacheData>> Function(RecentCacheRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecentCacheProvider._internal(
        (ref) => create(ref as RecentCacheRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        deviceId: deviceId,
        limit: limit,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TelemetryCacheData>> createElement() {
    return _RecentCacheProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecentCacheProvider &&
        other.deviceId == deviceId &&
        other.limit == limit;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, deviceId.hashCode);
    hash = _SystemHash.combine(hash, limit.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RecentCacheRef on AutoDisposeFutureProviderRef<List<TelemetryCacheData>> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;

  /// The parameter `limit` of this provider.
  int get limit;
}

class _RecentCacheProviderElement
    extends AutoDisposeFutureProviderElement<List<TelemetryCacheData>>
    with RecentCacheRef {
  _RecentCacheProviderElement(super.provider);

  @override
  String get deviceId => (origin as RecentCacheProvider).deviceId;
  @override
  int get limit => (origin as RecentCacheProvider).limit;
}

String _$connectionSourceHash() => r'822bc081595e35f2526f7bbea7a7874e40e351b9';

/// Indicates the active data source: 'ble', 'mqtt', or 'none'.
///
/// Copied from [connectionSource].
@ProviderFor(connectionSource)
const connectionSourceProvider = ConnectionSourceFamily();

/// Indicates the active data source: 'ble', 'mqtt', or 'none'.
///
/// Copied from [connectionSource].
class ConnectionSourceFamily extends Family<String> {
  /// Indicates the active data source: 'ble', 'mqtt', or 'none'.
  ///
  /// Copied from [connectionSource].
  const ConnectionSourceFamily();

  /// Indicates the active data source: 'ble', 'mqtt', or 'none'.
  ///
  /// Copied from [connectionSource].
  ConnectionSourceProvider call(
    String deviceId,
  ) {
    return ConnectionSourceProvider(
      deviceId,
    );
  }

  @override
  ConnectionSourceProvider getProviderOverride(
    covariant ConnectionSourceProvider provider,
  ) {
    return call(
      provider.deviceId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'connectionSourceProvider';
}

/// Indicates the active data source: 'ble', 'mqtt', or 'none'.
///
/// Copied from [connectionSource].
class ConnectionSourceProvider extends AutoDisposeProvider<String> {
  /// Indicates the active data source: 'ble', 'mqtt', or 'none'.
  ///
  /// Copied from [connectionSource].
  ConnectionSourceProvider(
    String deviceId,
  ) : this._internal(
          (ref) => connectionSource(
            ref as ConnectionSourceRef,
            deviceId,
          ),
          from: connectionSourceProvider,
          name: r'connectionSourceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$connectionSourceHash,
          dependencies: ConnectionSourceFamily._dependencies,
          allTransitiveDependencies:
              ConnectionSourceFamily._allTransitiveDependencies,
          deviceId: deviceId,
        );

  ConnectionSourceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.deviceId,
  }) : super.internal();

  final String deviceId;

  @override
  Override overrideWith(
    String Function(ConnectionSourceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConnectionSourceProvider._internal(
        (ref) => create(ref as ConnectionSourceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        deviceId: deviceId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<String> createElement() {
    return _ConnectionSourceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionSourceProvider && other.deviceId == deviceId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, deviceId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConnectionSourceRef on AutoDisposeProviderRef<String> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;
}

class _ConnectionSourceProviderElement
    extends AutoDisposeProviderElement<String> with ConnectionSourceRef {
  _ConnectionSourceProviderElement(super.provider);

  @override
  String get deviceId => (origin as ConnectionSourceProvider).deviceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
