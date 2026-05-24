import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../auth/secure_token_storage.dart';
import '../network/mqtt_api.dart';
import '../network/models/mqtt_credentials.dart';
import 'models/mqtt_topic_message.dart';

/// App-level MQTT connection state (distinct from mqtt_client's internal enum).
enum VenaMqttStatus { connected, disconnected, reconnecting }

/// Manages the MQTT connection lifecycle:
/// - Fetches short-lived JWT credentials via [MqttApi].
/// - Connects with `username = mqtt_jwt`, `password = "vena"`.
/// - Subscribes to `vena/{deviceId}/telemetry` and `vena/{deviceId}/status`.
/// - Exposes a broadcast [onMessage] stream consumed by [MqttMessageHandler].
/// - Reconnects with exponential backoff on unexpected disconnection.
/// - Refreshes the JWT 5 minutes before expiry and reconnects.
class MqttService {
  MqttService({
    required MqttApi mqttApi,
    required SecureTokenStorage storage,
  })  : _mqttApi = mqttApi,
        _storage = storage;

  final MqttApi _mqttApi;
  final SecureTokenStorage _storage;

  MqttServerClient? _client;
  StreamSubscription? _updatesSubscription;

  List<String> _deviceIds = const [];
  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;

  Timer? _refreshTimer;
  Timer? _reconnectTimer;
  Timer? _disconnectTimer;

  final _messageController = StreamController<MqttTopicMessage>.broadcast();
  final _stateController = StreamController<VenaMqttStatus>.broadcast();

  /// Broadcast stream of incoming MQTT messages.
  Stream<MqttTopicMessage> get onMessage => _messageController.stream;

  /// Broadcast stream of connection status changes.
  Stream<VenaMqttStatus> get connectionState => _stateController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches fresh MQTT credentials and connects to the broker.
  Future<void> connect() async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();

    try {
      final creds = await _mqttApi.getMqttCredentials();
      await _storage.saveMqttToken(creds.token);
      await _connectWithCredentials(creds);
    } catch (e) {
      debugPrint('[MQTT] connect error: $e');
      _emitState(VenaMqttStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Gracefully disconnects and cancels all timers.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _cancelAllTimers();
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _client?.disconnect();
    _client = null;
    _emitState(VenaMqttStatus.disconnected);
  }

  /// Starts a 30-second countdown before disconnecting.
  /// Called when the app enters background.
  void scheduleBackgroundDisconnect() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(const Duration(seconds: 30), disconnect);
  }

  /// Cancels a pending background disconnect.
  /// Called when the app returns to foreground.
  void cancelBackgroundDisconnect() {
    _disconnectTimer?.cancel();
  }

  /// Subscribes to telemetry and status topics for the given device IDs.
  /// Safe to call before or after connection — devices are re-subscribed
  /// automatically on reconnect.
  void subscribe(List<String> deviceIds) {
    _deviceIds = List.unmodifiable(deviceIds);
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      _doSubscribe(_client!, deviceIds);
    }
  }

  /// Releases all resources. Called by the Riverpod provider on dispose.
  void dispose() {
    _intentionalDisconnect = true;
    _cancelAllTimers();
    _updatesSubscription?.cancel();
    _client?.disconnect();
    _messageController.close();
    _stateController.close();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _connectWithCredentials(MqttCredentials creds) async {
    final clientId = 'vena_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(creds.host, clientId, creds.port);

    client.logging(on: kDebugMode);
    client.keepAlivePeriod = 60;
    client.autoReconnect = false;
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client = client;
    _emitState(VenaMqttStatus.reconnecting);

    // username = MQTT JWT, password = fixed "vena" (mosquitto-go-auth constraint)
    await client.connect(creds.token, 'vena');
  }

  void _onConnected() {
    _reconnectAttempts = 0;
    _emitState(VenaMqttStatus.connected);
    debugPrint('[MQTT] CONNACK OK');

    _doSubscribe(_client!, _deviceIds);

    _updatesSubscription?.cancel();
    _updatesSubscription = _client!.updates!.listen((events) {
      for (final event in events) {
        final raw = (event.payload as MqttPublishMessage).payload.message;
        final payload = MqttPublishPayload.bytesToStringAsString(raw);
        if (!_messageController.isClosed) {
          _messageController
              .add(MqttTopicMessage(topic: event.topic, payload: payload));
        }
      }
    });

    // Schedule JWT refresh 5 min before expiry.
    unawaited(_scheduleTokenRefresh());
  }

  void _onDisconnected() {
    debugPrint('[MQTT] disconnected (intentional: $_intentionalDisconnect)');
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _emitState(VenaMqttStatus.disconnected);
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _doSubscribe(MqttServerClient client, List<String> deviceIds) {
    for (final id in deviceIds) {
      client.subscribe('vena/$id/telemetry', MqttQos.atMostOnce);
      client.subscribe('vena/$id/status', MqttQos.atMostOnce);
    }
  }

  void _scheduleReconnect() {
    _emitState(VenaMqttStatus.reconnecting);
    const delays = [2, 4, 8, 16, 30]; // seconds, capped at 30
    final delay = delays[min(_reconnectAttempts, delays.length - 1)];
    _reconnectAttempts++;
    debugPrint('[MQTT] reconnect attempt $_reconnectAttempts in ${delay}s');
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  Future<void> _scheduleTokenRefresh() async {
    _refreshTimer?.cancel();
    final token = await _storage.getMqttToken();
    if (token == null) return;

    try {
      final exp = _parseJwtExp(token);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final delay = exp - 300 - now; // 5 min before expiry
      if (delay <= 0) {
        await _doTokenRefresh();
      } else {
        _refreshTimer =
            Timer(Duration(seconds: delay), () => unawaited(_doTokenRefresh()));
      }
    } catch (e) {
      debugPrint('[MQTT] could not parse JWT exp: $e');
    }
  }

  Future<void> _doTokenRefresh() async {
    debugPrint('[MQTT] refreshing MQTT JWT');
    try {
      final creds = await _mqttApi.getMqttCredentials();
      await _storage.saveMqttToken(creds.token);
      _client?.disconnect();
      await _connectWithCredentials(creds);
    } catch (e) {
      debugPrint('[MQTT] token refresh error: $e');
    }
  }

  static int _parseJwtExp(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) throw FormatException('Invalid JWT');
    var payload = parts[1];
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final decoded =
        jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
    return decoded['exp'] as int;
  }

  void _cancelAllTimers() {
    _refreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _disconnectTimer?.cancel();
  }

  void _emitState(VenaMqttStatus status) {
    if (!_stateController.isClosed) _stateController.add(status);
  }
}
