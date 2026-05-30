// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$historyHash() => r'a35b7a9697d804de751f7ffbac809fe169dcea0f';

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

/// Fetches telemetry history for [deviceId] over [range].
///
/// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
/// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
///
/// Copied from [history].
@ProviderFor(history)
const historyProvider = HistoryFamily();

/// Fetches telemetry history for [deviceId] over [range].
///
/// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
/// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
///
/// Copied from [history].
class HistoryFamily extends Family<AsyncValue<List<TelemetryPoint>>> {
  /// Fetches telemetry history for [deviceId] over [range].
  ///
  /// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
  /// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
  ///
  /// Copied from [history].
  const HistoryFamily();

  /// Fetches telemetry history for [deviceId] over [range].
  ///
  /// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
  /// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
  ///
  /// Copied from [history].
  HistoryProvider call(
    String deviceId,
    HistoryRange range,
  ) {
    return HistoryProvider(
      deviceId,
      range,
    );
  }

  @override
  HistoryProvider getProviderOverride(
    covariant HistoryProvider provider,
  ) {
    return call(
      provider.deviceId,
      provider.range,
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
  String? get name => r'historyProvider';
}

/// Fetches telemetry history for [deviceId] over [range].
///
/// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
/// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
///
/// Copied from [history].
class HistoryProvider extends AutoDisposeFutureProvider<List<TelemetryPoint>> {
  /// Fetches telemetry history for [deviceId] over [range].
  ///
  /// Results are cached for 5 minutes via [keepAlive] link. Callers invalidate
  /// by calling `ref.invalidate(historyProvider(deviceId, range))` if needed.
  ///
  /// Copied from [history].
  HistoryProvider(
    String deviceId,
    HistoryRange range,
  ) : this._internal(
          (ref) => history(
            ref as HistoryRef,
            deviceId,
            range,
          ),
          from: historyProvider,
          name: r'historyProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$historyHash,
          dependencies: HistoryFamily._dependencies,
          allTransitiveDependencies: HistoryFamily._allTransitiveDependencies,
          deviceId: deviceId,
          range: range,
        );

  HistoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.deviceId,
    required this.range,
  }) : super.internal();

  final String deviceId;
  final HistoryRange range;

  @override
  Override overrideWith(
    FutureOr<List<TelemetryPoint>> Function(HistoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HistoryProvider._internal(
        (ref) => create(ref as HistoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        deviceId: deviceId,
        range: range,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TelemetryPoint>> createElement() {
    return _HistoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HistoryProvider &&
        other.deviceId == deviceId &&
        other.range == range;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, deviceId.hashCode);
    hash = _SystemHash.combine(hash, range.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin HistoryRef on AutoDisposeFutureProviderRef<List<TelemetryPoint>> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;

  /// The parameter `range` of this provider.
  HistoryRange get range;
}

class _HistoryProviderElement
    extends AutoDisposeFutureProviderElement<List<TelemetryPoint>>
    with HistoryRef {
  _HistoryProviderElement(super.provider);

  @override
  String get deviceId => (origin as HistoryProvider).deviceId;
  @override
  HistoryRange get range => (origin as HistoryProvider).range;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
