class MqttCredentials {
  const MqttCredentials({
    required this.token,
    required this.host,
    required this.port,
    required this.expiresIn,
  });

  final String token;
  final String host;
  final int port;
  final int expiresIn; // seconds

  factory MqttCredentials.fromJson(Map<String, dynamic> json) =>
      MqttCredentials(
        token: json['mqtt_token'] as String,
        host: json['broker_host'] as String,
        port: json['broker_port'] as int,
        expiresIn: json['expires_in'] as int,
      );
}
