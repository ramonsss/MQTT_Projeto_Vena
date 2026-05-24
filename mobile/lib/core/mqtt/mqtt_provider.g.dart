// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mqtt_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mqttServiceHash() => r'11771c5777649ae598348d8faeb393fd7f96fb55';

/// Singleton [MqttService] — kept alive for the duration of the app session.
///
/// Initialise the full MQTT pipeline after login:
/// ```dart
/// ref.read(mqttMessageHandlerProvider); // wires message → DB
/// ref.read(mqttLifecycleProvider);      // registers app-lifecycle observer
/// await ref.read(mqttServiceProvider).connect();
/// ```
///
/// Copied from [mqttService].
@ProviderFor(mqttService)
final mqttServiceProvider = Provider<MqttService>.internal(
  mqttService,
  name: r'mqttServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mqttServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MqttServiceRef = ProviderRef<MqttService>;
String _$mqttStatusHash() => r'e9b640a7befac83ed23b9cd0c3a328025716e52a';

/// Stream of MQTT connection status — auto-disposes when not watched.
///
/// Copied from [mqttStatus].
@ProviderFor(mqttStatus)
final mqttStatusProvider = AutoDisposeStreamProvider<VenaMqttStatus>.internal(
  mqttStatus,
  name: r'mqttStatusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$mqttStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MqttStatusRef = AutoDisposeStreamProviderRef<VenaMqttStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
