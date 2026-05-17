import json

from application.configs.broker_configs import mqtt_broker_configs


def publish_setpoint(client, value: float):
    payload = json.dumps({"setpoint": float(value)})
    return client.publish(mqtt_broker_configs["TOPIC_CMD"], payload)
