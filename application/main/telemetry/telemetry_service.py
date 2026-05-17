import json
import logging
from typing import Callable, Optional

from application.configs.broker_configs import mqtt_broker_configs

logger = logging.getLogger(__name__)

EXPECTED_FIELDS = {
    "ambient_t", "ambient_h", "diss_t", "diss_h",
    "setpoint", "pid_out", "uptime_ms"
}


class TelemetryService:
    def __init__(self, client, on_sample: Optional[Callable[[dict], None]] = None):
        self._client = client
        self._on_sample = on_sample

    def subscribe(self):
        topic = mqtt_broker_configs["TOPIC_TELEMETRY"]
        self._client.subscribe(topic)
        logger.info("TelemetryService inscrito em %s", topic)

    def handle_message(self, client, userdata, message):
        try:
            payload = json.loads(message.payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            logger.warning("payload invalido em %s: %s", message.topic, exc)
            return

        if not isinstance(payload, dict):
            logger.warning("payload nao-objeto em %s: %r", message.topic, payload)
            return

        missing = EXPECTED_FIELDS - payload.keys()
        if missing:
            logger.warning("payload sem campos %s em %s", missing, message.topic)

        logger.info(
            "telemetria amb=%.1fC/%.0f%% diss=%.1fC sp=%.1f pid_out=%.1f uptime=%sms",
            payload.get("ambient_t", float("nan")),
            payload.get("ambient_h", float("nan")),
            payload.get("diss_t", float("nan")),
            payload.get("setpoint", float("nan")),
            payload.get("pid_out", float("nan")),
            payload.get("uptime_ms", "?"),
        )

        if self._on_sample is not None:
            try:
                self._on_sample(payload)
            except Exception:
                logger.exception("on_sample falhou")
