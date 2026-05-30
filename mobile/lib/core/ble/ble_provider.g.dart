// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$bleServiceHash() => r'a45cc3a107771a38d7ab0f8433bd2cbd5faf7dbb';

/// Singleton [BleService] — kept alive for the app session.
///
/// Copied from [bleService].
@ProviderFor(bleService)
final bleServiceProvider = Provider<BleService>.internal(
  bleService,
  name: r'bleServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bleServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BleServiceRef = ProviderRef<BleService>;
String _$bleStatusHash() => r'98d1726444a9d2d6062b9ef8f69cb7eca98892e7';

/// Stream of BLE connection status.
///
/// Copied from [bleStatus].
@ProviderFor(bleStatus)
final bleStatusProvider =
    AutoDisposeStreamProvider<BleConnectionStatus>.internal(
  bleStatus,
  name: r'bleStatusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bleStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BleStatusRef = AutoDisposeStreamProviderRef<BleConnectionStatus>;
String _$bleTelemetryHash() => r'3fbae3264de5a97a7677d10db0bebdf88f13a0e4';

/// Stream of BLE telemetry.
///
/// Copied from [bleTelemetry].
@ProviderFor(bleTelemetry)
final bleTelemetryProvider = AutoDisposeStreamProvider<BleTelemetry>.internal(
  bleTelemetry,
  name: r'bleTelemetryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$bleTelemetryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BleTelemetryRef = AutoDisposeStreamProviderRef<BleTelemetry>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
