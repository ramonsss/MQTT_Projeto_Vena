from application.configs.broker_configs import mqtt_broker_configs

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f'CLiente Conectado com sucesso! {client}')
        client.subscribe(mqtt_broker_configs["TOPIC"])
    else:
        print(f'Erro ao me conectar! codigo={rc}')

def on_subscribe(client, userdata, mid, grated_qos):
    print(f'Client Subscribed at {mqtt_broker_configs["TOPIC"]}')
    print(f'QOS: {grated_qos}')

def on_message(client, userdata, message):
    print('Messagem recebida!')
    print(client)
    print(message.payload)