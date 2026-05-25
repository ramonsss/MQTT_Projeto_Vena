// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_live_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bleLiveTelemetryHash() => r'aa343463f95d43d6ffd367f830390b9192cb25de';

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

/// Watches BLE telemetry for a specific device and emits the latest reading.
///
/// Copied from [bleLiveTelemetry].
@ProviderFor(bleLiveTelemetry)
const bleLiveTelemetryProvider = BleLiveTelemetryFamily();

/// Watches BLE telemetry for a specific device and emits the latest reading.
///
/// Copied from [bleLiveTelemetry].
class BleLiveTelemetryFamily extends Family<AsyncValue<BleTelemetry?>> {
  /// Watches BLE telemetry for a specific device and emits the latest reading.
  ///
  /// Copied from [bleLiveTelemetry].
  const BleLiveTelemetryFamily();

  /// Watches BLE telemetry for a specific device and emits the latest reading.
  ///
  /// Copied from [bleLiveTelemetry].
  BleLiveTelemetryProvider call(
    String deviceId,
  ) {
    return BleLiveTelemetryProvider(
      deviceId,
    );
  }

  @override
  BleLiveTelemetryProvider getProviderOverride(
    covariant BleLiveTelemetryProvider provider,
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
  String? get name => r'bleLiveTelemetryProvider';
}

/// Watches BLE telemetry for a specific device and emits the latest reading.
///
/// Copied from [bleLiveTelemetry].
class BleLiveTelemetryProvider
    extends AutoDisposeStreamProvider<BleTelemetry?> {
  /// Watches BLE telemetry for a specific device and emits the latest reading.
  ///
  /// Copied from [bleLiveTelemetry].
  BleLiveTelemetryProvider(
    String deviceId,
  ) : this._internal(
          (ref) => bleLiveTelemetry(
            ref as BleLiveTelemetryRef,
            deviceId,
          ),
          from: bleLiveTelemetryProvider,
          name: r'bleLiveTelemetryProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$bleLiveTelemetryHash,
          dependencies: BleLiveTelemetryFamily._dependencies,
          allTransitiveDependencies:
              BleLiveTelemetryFamily._allTransitiveDependencies,
          deviceId: deviceId,
        );

  BleLiveTelemetryProvider._internal(
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
    Stream<BleTelemetry?> Function(BleLiveTelemetryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BleLiveTelemetryProvider._internal(
        (ref) => create(ref as BleLiveTelemetryRef),
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
  AutoDisposeStreamProviderElement<BleTelemetry?> createElement() {
    return _BleLiveTelemetryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BleLiveTelemetryProvider && other.deviceId == deviceId;
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
mixin BleLiveTelemetryRef on AutoDisposeStreamProviderRef<BleTelemetry?> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;
}

class _BleLiveTelemetryProviderElement
    extends AutoDisposeStreamProviderElement<BleTelemetry?>
    with BleLiveTelemetryRef {
  _BleLiveTelemetryProviderElement(super.provider);

  @override
  String get deviceId => (origin as BleLiveTelemetryProvider).deviceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
