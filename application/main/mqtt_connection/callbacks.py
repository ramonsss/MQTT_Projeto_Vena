from application.configs.broker_configs import mqtt_broker_configs

# Registrado por main.py após instanciar TelemetryService — mantém callbacks como funções soltas.
_telemetry_service = None


def register_telemetry_service(service):
    global _telemetry_service
    _telemetry_service = service


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f'CLiente Conectado com sucesso! {client}')
        client.subscribe(mqtt_broker_configs["TOPIC"])
        client.subscribe(mqtt_broker_configs["TOPIC_TELEMETRY"])
    else:
        print(f'Erro ao me conectar! codigo={rc}')


def on_subscribe(client, userdata, mid, grated_qos):
    print(f'Client subscribed (mid={mid})')
    print(f'QOS: {grated_qos}')


def on_message(client, userdata, message):
    if message.topic == mqtt_broker_configs["TOPIC_TELEMETRY"] and _telemetry_service is not None:
        _telemetry_service.handle_message(client, userdata, message)
        return

    print('Messagem recebida!')
    print(client)
    print(message.payload)
