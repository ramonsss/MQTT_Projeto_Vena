// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$deviceMetaHash() => r'd9c86b822f62a31d50ba2d30f1001a387c8f03e3';

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

/// See also [deviceMeta].
@ProviderFor(deviceMeta)
const deviceMetaProvider = DeviceMetaFamily();

/// See also [deviceMeta].
class DeviceMetaFamily extends Family<AsyncValue<DeviceMeta?>> {
  /// See also [deviceMeta].
  const DeviceMetaFamily();

  /// See also [deviceMeta].
  DeviceMetaProvider call(
    String deviceId,
  ) {
    return DeviceMetaProvider(
      deviceId,
    );
  }

  @override
  DeviceMetaProvider getProviderOverride(
    covariant DeviceMetaProvider provider,
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
  String? get name => r'deviceMetaProvider';
}

/// See also [deviceMeta].
class DeviceMetaProvider extends AutoDisposeFutureProvider<DeviceMeta?> {
  /// See also [deviceMeta].
  DeviceMetaProvider(
    String deviceId,
  ) : this._internal(
          (ref) => deviceMeta(
            ref as DeviceMetaRef,
            deviceId,
          ),
          from: deviceMetaProvider,
          name: r'deviceMetaProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$deviceMetaHash,
          dependencies: DeviceMetaFamily._dependencies,
          allTransitiveDependencies:
              DeviceMetaFamily._allTransitiveDependencies,
          deviceId: deviceId,
        );

  DeviceMetaProvider._internal(
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
    FutureOr<DeviceMeta?> Function(DeviceMetaRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DeviceMetaProvider._internal(
        (ref) => create(ref as DeviceMetaRef),
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
  AutoDisposeFutureProviderElement<DeviceMeta?> createElement() {
    return _DeviceMetaProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceMetaProvider && other.deviceId == deviceId;
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
mixin DeviceMetaRef on AutoDisposeFutureProviderRef<DeviceMeta?> {
  /// The parameter `deviceId` of this provider.
  String get deviceId;
}

class _DeviceMetaProviderElement
    extends AutoDisposeFutureProviderElement<DeviceMeta?> with DeviceMetaRef {
  _DeviceMetaProviderElement(super.provider);

  @override
  String get deviceId => (origin as DeviceMetaProvider).deviceId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
