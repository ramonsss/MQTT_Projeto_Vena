// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$devicesHash() => r'32e1c79676a76999634810e1ea3a80c5970a0ffe';

/// Stream of all devices stored in Drift, re-emits on every table change.
///
/// Devices are inserted / updated by [DeviceSyncService] (REST) and by
/// [MqttMessageHandler] (status messages). Pull-to-refresh in
/// [DevicesScreen] triggers a manual sync.
///
/// Copied from [devices].
@ProviderFor(devices)
final devicesProvider = AutoDisposeStreamProvider<List<Device>>.internal(
  devices,
  name: r'devicesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$devicesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DevicesRef = AutoDisposeStreamProviderRef<List<Device>>;
String _$latestStateHash() => r'c1c4b03dafa6c0cfa541c30d3783e1cc392b2ad8';

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

/// Stream of the latest telemetry state for [deviceId].
///
/// Returns `null` when no MQTT message has been received yet for this device.
/// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
/// Phase 11 ([live_telemetry_provider]) will import it from here.
///
/// Copied from [latestState].
@ProviderFor(latestState)
const latestStateProvider = LatestStateFamily();

/// Stream of the latest telemetry state for [deviceId].
///
/// Returns `null` when no MQTT message has been received yet for this device.
/// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
/// Phase 11 ([live_telemetry_provider]) will import it from here.
///
/// Copied from [latestState].
class LatestStateFamily extends Family<AsyncValue<LatestState?>> {
  /// Stream of the latest telemetry state for [deviceId].
  ///
  /// Returns `null` when no MQTT message has been received yet for this device.
  /// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
  /// Phase 11 ([live_telemetry_provider]) will import it from here.
  ///
  /// Copied from [latestState].
  const LatestStateFamily();

  /// Stream of the latest telemetry state for [deviceId].
  ///
  /// Returns `null` when no MQTT message has been received yet for this device.
  /// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
  /// Phase 11 ([live_telemetry_provider]) will import it from here.
  ///
  /// Copied from [latestState].
  LatestStateProvider call(
    String deviceId,
  ) {
    return LatestStateProvider(
      deviceId,
    );
  }

  @override
  LatestStateProvider getProviderOverride(
    covariant LatestStateProvider provider,
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
  String? get name => r'latestStateProvider';
}

/// Stream of the latest telemetry state for [deviceId].
///
/// Returns `null` when no MQTT message has been received yet for this device.
/// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
/// Phase 11 ([live_telemetry_provider]) will import it from here.
///
/// Copied from [latestState].
class LatestStateProvider extends AutoDisposeStreamProvider<LatestState?> {
  /// Stream of the latest telemetry state for [deviceId].
  ///
  /// Returns `null` when no MQTT message has been received yet for this device.
  /// Defined here (Phase 10) so [DeviceCard] can consume it immediately;
  /// Phase 11 ([live_telemetry_provider]) will import it from here.
  ///
  /// Copied from [latestState].
  LatestStateProvider(
    String deviceId,
  ) : this._internal(
          (ref) => latestState(
            ref as LatestStateRef,
            deviceId,
          ),
          from: latestStateProvider,
          name: r'latestStateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$latestStateHash,
          dependencies: LatestStateFamily._dependencies,
          allTransitiveDependencies:
              LatestStateFamily._allTransitiveDependencies,
          deviceId: deviceId,
        );

  LatestStateProvider._internal(
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
    Stream<LatestState?> Function(LatestStateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LatestStateProvider._internal(
        (ref) => create(ref as LatestStateRef),
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
  AutoDisposeStreamProviderElement<LatestState?> createElement() {
    return _LatestStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LatestStateProvider && other.deviceId == deviceId;
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
mixin LatestStateRef on AutoDisposeStreamProviderRef<LatestState?> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;
}

class _LatestStateProviderElement
    extends AutoDisposeStreamProviderElement<LatestState?> with LatestStateRef {
  _LatestStateProviderElement(super.provider);

  @override
  String get deviceId => (origin as LatestStateProvider).deviceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
