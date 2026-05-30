from __future__ import annotations

import asyncio

import paho.mqtt.client as paho

from app.auth.jwt import create_backend_token
from app.config import settings
from app.shared.logging import get_logger

log = get_logger(__name__)


class MqttWorker:
    """Paho MQTT client running in a background thread, pushing messages to an asyncio.Queue."""

    TOPICS = [
        ("vena/+/telemetry", 1),
        ("vena/+/status", 1),
        ("vena/+/meta", 1),
    ]

    def __init__(self, queue: asyncio.Queue[tuple[str, bytes]], loop: asyncio.AbstractEventLoop) -> None:
        self._queue = queue
        self._loop = loop
        self._client = paho.Client(
            client_id="vena-backend",
            protocol=paho.MQTTv5,
            callback_api_version=paho.CallbackAPIVersion.VERSION2,
        )
        self._client.on_connect = self._on_connect
        self._client.on_disconnect = self._on_disconnect
        self._client.on_message = self._on_message
        self._backoff = 1.0

    def _refresh_jwt(self) -> None:
        """Generate a fresh backend JWT and set it as the MQTT username.

        mosquitto-go-auth rejects connections with an empty password before
        it ever calls the HTTP backend, so we pass a fixed placeholder.
        The /mqtt/auth endpoint only reads the JWT from `username`.
        """
        token = create_backend_token()
        self._client.username_pw_set(token, "vena")

    def start(self) -> None:
        log.info("MQTT worker connecting to {}:{}", settings.mqtt_host, settings.mqtt_port)
        self._refresh_jwt()
        self._client.connect_async(settings.mqtt_host, settings.mqtt_port)
        self._client.loop_start()

    def stop(self) -> None:
        log.info("MQTT worker stopping")
        self._client.loop_stop()
        self._client.disconnect()

    def _on_connect(
        self,
        client: paho.Client,
        userdata: object,
        flags: paho.ConnectFlags,
        reason_code: paho.ReasonCode,
        properties: paho.Properties | None,
    ) -> None:
        if reason_code == 0:
            log.info("MQTT connected, subscribing to topics")
            for topic, qos in self.TOPICS:
                client.subscribe(topic, qos)
            self._backoff = 1.0
        else:
            log.warning("MQTT connect failed: {}", reason_code)

    def _on_disconnect(
        self,
        client: paho.Client,
        userdata: object,
        flags: paho.DisconnectFlags,
        reason_code: paho.ReasonCode,
        properties: paho.Properties | None,
    ) -> None:
        log.warning("MQTT disconnected (rc={}), will reconnect with backoff {:.1f}s", reason_code, self._backoff)
        self._backoff = min(self._backoff * 2, 30.0)
        # Refresh JWT so the next auto-reconnect attempt uses a non-expired token.
        self._refresh_jwt()

    def _on_message(
        self,
        client: paho.Client,
        userdata: object,
        msg: paho.MQTTMessage,
    ) -> None:
        try:
            self._loop.call_soon_threadsafe(self._queue.put_nowait, (msg.topic, bytes(msg.payload)))
        except asyncio.QueueFull:
            log.warning("Queue full, dropping message from {}", msg.topic)
