// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mqtt_message_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mqttMessageHandlerHash() =>
    r'de5fe04d53006c90817c86380729b3213671aff9';

/// Singleton handler — wires itself to [mqttServiceProvider].onMessage.
/// Keep alive so the subscription persists for the whole session.
///
/// Copied from [mqttMessageHandler].
@ProviderFor(mqttMessageHandler)
final mqttMessageHandlerProvider = Provider<MqttMessageHandler>.internal(
  mqttMessageHandler,
  name: r'mqttMessageHandlerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mqttMessageHandlerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MqttMessageHandlerRef = ProviderRef<MqttMessageHandler>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
