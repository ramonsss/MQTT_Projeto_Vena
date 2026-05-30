class MqttTopicMessage {
  const MqttTopicMessage({required this.topic, required this.payload});

  final String topic;
  final String payload; // raw JSON string
}
