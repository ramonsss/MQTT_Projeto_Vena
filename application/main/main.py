import logging
import time

from application.configs.broker_configs import mqtt_broker_configs
from .mqtt_connection.mqtt_client_connection import MqttClientConnection
from .mqtt_connection.callbacks import register_telemetry_service
from .telemetry.telemetry_service import TelemetryService


def start():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

    mqtt_client_connection = MqttClientConnection(
        mqtt_broker_configs["HOST"],
        mqtt_broker_configs["PORT"],
        mqtt_broker_configs["CLIENT_NAME"],
        mqtt_broker_configs["KEPPALIVE"]
    )
    mqtt_client_connection.start_connection()

    telemetry_service = TelemetryService(mqtt_client_connection.client)
    register_telemetry_service(telemetry_service)
    telemetry_service.subscribe()

    while True: time.sleep(0.001)
