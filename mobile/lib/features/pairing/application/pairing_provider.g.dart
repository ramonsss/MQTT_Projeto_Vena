// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pairing_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pairingNotifierHash() => r'e8489d16302b0923592a1e581848b2a6acff9cc8';

/// QR payload format (either is accepted):
///   • `vena://<deviceId>?code=<pairingCode>` (URI)
///   • `{"device_id":"...","pairing_code":"..."}` (JSON)
///
/// Copied from [PairingNotifier].
@ProviderFor(PairingNotifier)
final pairingNotifierProvider =
    AutoDisposeNotifierProvider<PairingNotifier, PairingState>.internal(
  PairingNotifier.new,
  name: r'pairingNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pairingNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PairingNotifier = AutoDisposeNotifier<PairingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
